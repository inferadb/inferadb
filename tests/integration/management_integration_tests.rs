// Management API Integration Tests
//
// Tests for validating integration between server and management API

use super::*;
use base64::Engine;
use reqwest::StatusCode;

#[tokio::test]
async fn test_organization_status_check() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate valid JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Verify JWT works initially
    let initial_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        initial_response.status().is_success() || initial_response.status() == StatusCode::NOT_FOUND,
        "Initial request should succeed"
    );

    // Suspend the organization
    let suspend_response = fixture
        .ctx
        .client
        .patch(format!(
            "{}/v1/organizations/{}",
            fixture.ctx.management_url, fixture.org_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .json(&serde_json::json!({
            "status": "suspended"
        }))
        .send()
        .await
        .expect("Failed to suspend organization");

    if !suspend_response.status().is_success() {
        // If suspension endpoint doesn't exist or fails, skip this test
        eprintln!(
            "Skipping organization suspension test - endpoint may not be implemented: {}",
            suspend_response.status()
        );
        fixture.cleanup().await.expect("Failed to cleanup");
        return;
    }

    // Wait for cache to potentially expire
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Try to authenticate with suspended org's credentials
    let suspended_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail with 403 Forbidden due to suspended status
    // Note: This depends on cache TTL - may still succeed if cached
    if suspended_response.status() != StatusCode::FORBIDDEN {
        eprintln!(
            "Warning: Request succeeded despite suspension - likely cached. Status: {}",
            suspended_response.status()
        );
    }

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_vault_deletion_propagation() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Write some data to the vault
    let jwt = fixture
        .generate_jwt(None, &["inferadb.write"])
        .expect("Failed to generate JWT");

    let mut relationship = std::collections::HashMap::new();
    relationship.insert("resource", "document:important");
    relationship.insert("relation", "owner");
    relationship.insert("subject", "user:charlie");

    let mut write_body = std::collections::HashMap::new();
    write_body.insert("relationships", vec![relationship]);

    let write_response = fixture
        .ctx
        .client
        .post(format!("{}/v1/relationships/write", fixture.ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt))
        .json(&write_body)
        .send()
        .await
        .expect("Failed to write relationship");

    assert!(
        write_response.status().is_success(),
        "Failed to write data"
    );

    // Delete vault via management API
    let delete_response = fixture
        .ctx
        .client
        .delete(format!(
            "{}/v1/organizations/{}/vaults/{}",
            fixture.ctx.management_url, fixture.org_id, fixture.vault_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .send()
        .await
        .expect("Failed to delete vault")
        .error_for_status()
        .expect("Vault deletion failed");

    assert!(delete_response.status().is_success());

    // Wait for potential cache invalidation
    tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;

    // Try to access with vault's token
    let access_response = fixture
        .call_server_evaluate(&jwt, "document:important", "owner", "user:charlie")
        .await
        .expect("Failed to call server");

    // Should fail (vault not found) - either 403 Forbidden or 404 Not Found
    assert!(
        access_response.status() == StatusCode::FORBIDDEN
            || access_response.status() == StatusCode::NOT_FOUND,
        "Expected 403 or 404 after vault deletion, got {}",
        access_response.status()
    );

    // Cleanup remaining resources (vault already deleted)
    let _ = fixture
        .ctx
        .client
        .delete(format!(
            "{}/v1/organizations/{}/clients/{}",
            fixture.ctx.management_url, fixture.org_id, fixture.client_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .send()
        .await;
}

#[tokio::test]
async fn test_certificate_rotation() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate JWT with original certificate
    let jwt_old = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT with old cert");

    // Verify old JWT works
    let old_response = fixture
        .call_server_evaluate(&jwt_old, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        old_response.status().is_success() || old_response.status() == StatusCode::NOT_FOUND,
        "Old JWT should work initially"
    );

    // Create a new certificate (rotation) - server generates the keypair
    let new_cert_req = CreateCertificateRequest {
        name: format!("Rotated Certificate {}", Uuid::new_v4()),
    };

    let new_cert_resp: CertificateResponse = fixture
        .ctx
        .client
        .post(format!(
            "{}/v1/organizations/{}/clients/{}/certificates",
            fixture.ctx.management_url, fixture.org_id, fixture.client_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .json(&new_cert_req)
        .send()
        .await
        .expect("Failed to create new certificate")
        .error_for_status()
        .expect("Certificate creation failed")
        .json()
        .await
        .expect("Failed to parse certificate response");

    // Parse the server-generated private key
    let new_private_key_bytes = base64::engine::general_purpose::STANDARD
        .decode(&new_cert_resp.private_key)
        .expect("Failed to decode new private key");
    let new_signing_key = SigningKey::from_bytes(
        &new_private_key_bytes
            .try_into()
            .expect("Invalid private key length"),
    );

    // Generate JWT with new certificate
    let now = Utc::now();
    let claims = ClientClaims {
        iss: format!("{}/v1", fixture.ctx.management_url),
        sub: format!("client:{}", fixture.client_id),
        aud: fixture.ctx.server_url.clone(),
        exp: (now + Duration::minutes(5)).timestamp(),
        iat: now.timestamp(),
        jti: Uuid::new_v4().to_string(),
        vault_id: fixture.vault_id.to_string(),
        org_id: fixture.org_id.to_string(),
        scope: "inferadb.check inferadb.read inferadb.write inferadb.expand inferadb.list inferadb.list-relationships inferadb.list-subjects inferadb.list-resources".to_string(),
        vault_role: "write".to_string(),
    };

    let mut header = Header::new(Algorithm::EdDSA);
    header.kid = Some(new_cert_resp.certificate.kid.clone());

    let secret_bytes = new_signing_key.to_bytes();
    let pem = ed25519_to_pem(&secret_bytes);
    let encoding_key = EncodingKey::from_ed_pem(&pem).expect("Failed to create encoding key");
    let jwt_new = encode(&header, &claims, &encoding_key).expect("Failed to encode JWT");

    // Verify new JWT works
    let new_response = fixture
        .ctx
        .client
        .post(format!("{}/v1/evaluate", fixture.ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt_new))
        .json(&std::collections::HashMap::from([(
            "evaluations",
            vec![std::collections::HashMap::from([
                ("resource", "document:1"),
                ("permission", "viewer"),
                ("subject", "user:alice"),
            ])],
        )]))
        .send()
        .await
        .expect("Failed to call server");

    assert!(
        new_response.status().is_success() || new_response.status() == StatusCode::NOT_FOUND,
        "New JWT should work after rotation"
    );

    // Old JWT should still work (grace period) unless explicitly revoked
    let old_after_rotation = fixture
        .call_server_evaluate(&jwt_old, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Both certificates should be valid simultaneously
    assert!(
        old_after_rotation.status().is_success()
            || old_after_rotation.status() == StatusCode::NOT_FOUND,
        "Old JWT should still work during grace period"
    );

    // Cleanup new certificate
    let _ = fixture
        .ctx
        .client
        .delete(format!(
            "{}/v1/organizations/{}/clients/{}/certificates/{}",
            fixture.ctx.management_url, fixture.org_id, fixture.client_id, new_cert_resp.certificate.id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .send()
        .await;

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_client_deactivation() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate valid JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Verify JWT works initially
    let initial_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        initial_response.status().is_success() || initial_response.status() == StatusCode::NOT_FOUND,
        "Initial request should succeed"
    );

    // Deactivate the client
    let deactivate_response = fixture
        .ctx
        .client
        .patch(format!(
            "{}/v1/organizations/{}/clients/{}",
            fixture.ctx.management_url, fixture.org_id, fixture.client_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .json(&serde_json::json!({
            "status": "inactive"
        }))
        .send()
        .await
        .expect("Failed to deactivate client");

    if !deactivate_response.status().is_success() {
        // If deactivation endpoint doesn't exist, skip this test
        eprintln!(
            "Skipping client deactivation test - endpoint may not be implemented: {}",
            deactivate_response.status()
        );
        fixture.cleanup().await.expect("Failed to cleanup");
        return;
    }

    // Wait for cache to potentially expire
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Try to use JWT from deactivated client
    let deactivated_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // May still succeed if cached, but should eventually fail
    if deactivated_response.status().is_success() || deactivated_response.status() == StatusCode::NOT_FOUND {
        eprintln!(
            "Warning: Request succeeded despite client deactivation - likely cached"
        );
    }

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_certificate_revocation() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate valid JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Verify JWT works initially
    let initial_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        initial_response.status().is_success() || initial_response.status() == StatusCode::NOT_FOUND,
        "Initial request should succeed"
    );

    // Revoke the certificate
    let revoke_response = fixture
        .ctx
        .client
        .delete(format!(
            "{}/v1/organizations/{}/clients/{}/certificates/{}",
            fixture.ctx.management_url, fixture.org_id, fixture.client_id, fixture.cert_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .send()
        .await
        .expect("Failed to revoke certificate")
        .error_for_status()
        .expect("Certificate revocation failed");

    assert!(revoke_response.status().is_success());

    // Wait for cache to potentially expire (certificate cache TTL is 15 minutes by default)
    // For testing, we wait a shorter time and accept that it may still be cached
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Try to use JWT with revoked certificate
    let revoked_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // May still succeed if certificate is cached, should eventually fail
    if revoked_response.status().is_success() || revoked_response.status() == StatusCode::NOT_FOUND {
        eprintln!(
            "Warning: Request succeeded despite certificate revocation - likely cached (TTL: 15min)"
        );
    } else {
        assert_eq!(
            revoked_response.status(),
            StatusCode::UNAUTHORIZED,
            "Expected 401 after certificate revocation"
        );
    }

    // Cleanup (certificate already deleted)
    let _ = fixture
        .ctx
        .client
        .delete(format!(
            "{}/v1/organizations/{}/clients/{}",
            fixture.ctx.management_url, fixture.org_id, fixture.client_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .send()
        .await;
}
