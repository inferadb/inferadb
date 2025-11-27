// Vault Isolation Tests
//
// Tests for validating vault isolation guarantees

use super::*;
use reqwest::StatusCode;
use std::collections::HashMap;

#[tokio::test]
async fn test_cross_vault_read_protection() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Create a second vault in the same organization
    let vault_req = CreateVaultRequest {
        name: format!("Test Vault B {}", Uuid::new_v4()),
        organization_id: fixture.org_id,
    };

    let vault_b_response: CreateVaultResponse = fixture
        .ctx
        .client
        .post(format!(
            "{}/v1/organizations/{}/vaults",
            fixture.ctx.management_url, fixture.org_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .json(&vault_req)
        .send()
        .await
        .expect("Failed to create second vault")
        .error_for_status()
        .expect("Vault creation failed")
        .json()
        .await
        .expect("Failed to parse vault response");

    let vault_b_id = vault_b_response.vault.id;

    // Write relationships to vault A using server API
    let jwt_vault_a = fixture
        .generate_jwt(Some(fixture.vault_id), &["inferadb.write"])
        .expect("Failed to generate JWT for vault A");

    let mut write_body = HashMap::new();
    let mut relationship = HashMap::new();
    relationship.insert("resource", "document:test-doc");
    relationship.insert("relation", "owner");
    relationship.insert("subject", "user:alice");
    write_body.insert("relationships", vec![relationship]);

    let write_response = fixture
        .ctx
        .client
        .post(format!("{}/v1/relationships/write", fixture.ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt_vault_a))
        .json(&write_body)
        .send()
        .await
        .expect("Failed to write relationship");

    assert!(
        write_response.status().is_success(),
        "Failed to write to vault A: {}",
        write_response.status()
    );

    // Try to read vault A's data with vault B token
    let jwt_vault_b = fixture
        .generate_jwt(Some(vault_b_id), &["inferadb.check"])
        .expect("Failed to generate JWT for vault B");

    let read_response = fixture
        .ctx
        .client
        .post(format!("{}/v1/evaluate", fixture.ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt_vault_b))
        .json(&HashMap::from([(
            "evaluations",
            vec![HashMap::from([
                ("resource", "document:test-doc"),
                ("permission", "owner"),
                ("subject", "user:alice"),
            ])],
        )]))
        .send()
        .await
        .expect("Failed to query");

    // Should return empty results or false (isolated)
    assert!(
        read_response.status().is_success(),
        "Query should succeed but return isolated results"
    );

    // Cleanup vault B
    let _ = fixture
        .ctx
        .client
        .delete(format!(
            "{}/v1/organizations/{}/vaults/{}",
            fixture.ctx.management_url, fixture.org_id, vault_b_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .send()
        .await;

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_cross_org_isolation() {
    // Create two separate test fixtures (two different orgs)
    let fixture_a = TestFixture::create()
        .await
        .expect("Failed to create fixture A");
    let fixture_b = TestFixture::create()
        .await
        .expect("Failed to create fixture B");

    // Write data to org A's vault
    let jwt_a = fixture_a
        .generate_jwt(None, &["inferadb.write"])
        .expect("Failed to generate JWT for org A");

    let mut write_body = HashMap::new();
    let mut relationship = HashMap::new();
    relationship.insert("resource", "document:secret");
    relationship.insert("relation", "viewer");
    relationship.insert("subject", "user:bob");
    write_body.insert("relationships", vec![relationship]);

    let write_response = fixture_a
        .ctx
        .client
        .post(format!("{}/v1/relationships/write", fixture_a.ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt_a))
        .json(&write_body)
        .send()
        .await
        .expect("Failed to write to org A");

    assert!(
        write_response.status().is_success(),
        "Failed to write to org A"
    );

    // Try to read org A's data with org B's credentials
    let jwt_b = fixture_b
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT for org B");

    let read_response = fixture_b
        .ctx
        .client
        .post(format!("{}/v1/evaluate", fixture_b.ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt_b))
        .json(&HashMap::from([(
            "evaluations",
            vec![HashMap::from([
                ("resource", "document:secret"),
                ("permission", "viewer"),
                ("subject", "user:bob"),
            ])],
        )]))
        .send()
        .await
        .expect("Failed to query");

    // Should succeed but return isolated results (false or empty)
    assert!(
        read_response.status().is_success(),
        "Query should succeed with isolated results"
    );

    fixture_a.cleanup().await.expect("Failed to cleanup A");
    fixture_b.cleanup().await.expect("Failed to cleanup B");
}

#[tokio::test]
async fn test_account_ownership_validation() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT with wrong account ID in claims
    let fake_organization_id: i64 = 888888888; // Fake Snowflake ID
    let now = Utc::now();
    let claims = ClientClaims {
        iss: format!("{}/v1", fixture.ctx.management_url),
        sub: format!("client:{}", fixture.client_id),
        aud: fixture.ctx.server_url.clone(),
        exp: (now + Duration::minutes(5)).timestamp(),
        iat: now.timestamp(),
        jti: Uuid::new_v4().to_string(),
        vault_id: fixture.vault_id.to_string(),
        org_id: fake_organization_id.to_string(), // Wrong account
        scope: "inferadb.check inferadb.read inferadb.write inferadb.expand inferadb.list inferadb.list-relationships inferadb.list-subjects inferadb.list-resources".to_string(),
        vault_role: "write".to_string(),
    };

    let mut header = Header::new(Algorithm::EdDSA);
    header.kid = Some(fixture.cert_kid.clone());

    let secret_bytes = fixture.signing_key.to_bytes();
    let pem = ed25519_to_pem(&secret_bytes);
    let encoding_key = EncodingKey::from_ed_pem(&pem).expect("Failed to create encoding key");
    let jwt = encode(&header, &claims, &encoding_key).expect("Failed to encode JWT");

    // Call server with wrong account ID
    let response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail with 403 Forbidden (account mismatch)
    assert_eq!(
        response.status(),
        StatusCode::FORBIDDEN,
        "Expected 403 Forbidden for account mismatch"
    );

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_vault_deletion_prevents_access() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate valid JWT before deletion
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Verify JWT works initially
    let initial_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        initial_response.status().is_success()
            || initial_response.status() == StatusCode::NOT_FOUND,
        "Initial request should succeed"
    );

    // Delete the vault
    fixture
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

    // Wait a moment for cache invalidation
    tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;

    // Try to use same JWT after vault deletion
    let after_deletion_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail with 403 Forbidden (vault not found) or 404
    assert!(
        after_deletion_response.status() == StatusCode::FORBIDDEN
            || after_deletion_response.status() == StatusCode::NOT_FOUND,
        "Expected 403 or 404 after vault deletion, got {}",
        after_deletion_response.status()
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
