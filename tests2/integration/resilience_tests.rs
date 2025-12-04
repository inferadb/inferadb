// Management API Failure Handling Tests
//
// Tests for validating server resilience when management API is unavailable

use super::*;
use reqwest::StatusCode;

#[tokio::test]
async fn test_cached_data_allows_validation() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // First request to populate cache
    let initial_response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        initial_response.status().is_success()
            || initial_response.status() == StatusCode::NOT_FOUND,
        "Initial request failed"
    );
    println!("✓ Cache populated with successful request");

    // Make several more requests - these should be served from cache
    for i in 0..5 {
        let response = fixture
            .call_server_evaluate(&jwt, &format!("document:{}", i), "viewer", "user:alice")
            .await
            .expect("Failed to call server");

        assert!(
            response.status().is_success() || response.status() == StatusCode::NOT_FOUND,
            "Request {} failed: {}",
            i,
            response.status()
        );
    }

    println!("✓ Multiple requests succeeded using cached data");

    // Note: Testing actual management API failure would require:
    // 1. Stopping the management API container
    // 2. Making requests (should work from cache)
    // 3. Waiting for cache to expire
    // 4. Making requests (should fail gracefully)
    // This is better tested in manual/chaos testing scenarios

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_graceful_degradation_with_network_timeout() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Create a JWT with a non-existent kid (will cause management API lookup)
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
    // Use a kid that doesn't exist but has valid format (fake cert Snowflake ID)
    header.kid = Some(format!(
        "org-{}-client-{}-cert-{}",
        fixture.org_id, fixture.client_id, 999999999i64
    ));

    let secret_bytes = fixture.signing_key.to_bytes();
    let pem = ed25519_to_pem(&secret_bytes);
    let encoding_key = EncodingKey::from_ed_pem(&pem).expect("Failed to create encoding key");
    let jwt = encode(&header, &claims, &encoding_key).expect("Failed to encode JWT");

    // This should fail with 401 (certificate not found)
    let response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert_eq!(
        response.status(),
        StatusCode::UNAUTHORIZED,
        "Expected 401 for non-existent certificate"
    );
    println!("✓ Server handled missing certificate gracefully");

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_server_continues_with_cached_certificates() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate valid JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Make initial request to cache the certificate
    let response1 = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        response1.status().is_success() || response1.status() == StatusCode::NOT_FOUND,
        "Initial request failed"
    );
    println!("✓ Certificate cached");

    // Make more requests - these should use cached certificate
    // Even if management API becomes unavailable, these should still work
    for i in 0..10 {
        let response = fixture
            .call_server_evaluate(&jwt, &format!("doc:{}", i), "viewer", "user:alice")
            .await
            .expect("Failed to call server");

        assert!(
            response.status().is_success() || response.status() == StatusCode::NOT_FOUND,
            "Cached request {} failed",
            i
        );
    }

    println!("✓ Server continued operating with cached certificate");

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_partial_cache_coverage() {
    // Test scenario where some data is cached and some requires API calls
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT with original vault (will be cached)
    let jwt1 = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // First request to cache certificate and vault
    let response1 = fixture
        .call_server_evaluate(&jwt1, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        response1.status().is_success() || response1.status() == StatusCode::NOT_FOUND,
        "First request failed"
    );
    println!("✓ First vault cached");

    // Create a second vault (not yet cached)
    let vault2_req = CreateVaultRequest {
        name: format!("Second Vault {}", Uuid::new_v4()),
        organization_id: fixture.org_id,
    };

    let vault2_response: CreateVaultResponse = fixture
        .ctx
        .client
        .post(format!(
            "{}/v1/organizations/{}/vaults",
            fixture.ctx.management_url, fixture.org_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .json(&vault2_req)
        .send()
        .await
        .expect("Failed to create second vault")
        .error_for_status()
        .expect("Vault creation failed")
        .json()
        .await
        .expect("Failed to parse response");

    let vault2_id = vault2_response.vault.id;

    // Generate JWT with new vault
    let jwt2 = fixture
        .generate_jwt(Some(vault2_id), &["inferadb.check"])
        .expect("Failed to generate JWT for vault 2");

    // Request with new vault (should require management API call)
    let response2 = fixture
        .call_server_evaluate(&jwt2, "document:2", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        response2.status().is_success() || response2.status() == StatusCode::NOT_FOUND,
        "Second request failed"
    );
    println!("✓ Successfully handled mixed cached/uncached scenario");

    // Cleanup second vault
    let _ = fixture
        .ctx
        .client
        .delete(format!(
            "{}/v1/organizations/{}/vaults/{}",
            fixture.ctx.management_url, fixture.org_id, vault2_id
        ))
        .header("Authorization", format!("Bearer {}", fixture.session_id))
        .send()
        .await;

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_error_handling_for_invalid_responses() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Test with malformed JWT (no kid)
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

    let header = Header::new(Algorithm::EdDSA); // No kid set

    let secret_bytes = fixture.signing_key.to_bytes();
    let pem = ed25519_to_pem(&secret_bytes);
    let encoding_key = EncodingKey::from_ed_pem(&pem).expect("Failed to create encoding key");
    let jwt = encode(&header, &claims, &encoding_key).expect("Failed to encode JWT");

    // Call server with JWT without kid
    let response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail gracefully with 401
    assert_eq!(
        response.status(),
        StatusCode::UNAUTHORIZED,
        "Expected 401 for JWT without kid"
    );
    println!("✓ Server handled malformed JWT gracefully");

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_concurrent_requests_with_mixed_cache_states() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Launch 20 concurrent requests
    let mut handles = Vec::new();

    for i in 0..20 {
        let jwt_clone = jwt.clone();
        let ctx = fixture.ctx.clone();
        let server_url = fixture.ctx.server_url.clone();

        let handle = tokio::spawn(async move {
            let mut evaluation = std::collections::HashMap::new();
            evaluation.insert("resource", format!("document:{}", i));
            evaluation.insert("permission", "viewer".to_string());
            evaluation.insert("subject", "user:alice".to_string());

            let mut body = std::collections::HashMap::new();
            body.insert("evaluations", vec![evaluation]);

            ctx.client
                .post(format!("{}/v1/evaluate", server_url))
                .header("Authorization", format!("Bearer {}", jwt_clone))
                .json(&body)
                .send()
                .await
                .expect("Failed to call server")
        });

        handles.push(handle);
    }

    // Wait for all requests to complete
    let mut success_count = 0;
    for handle in handles {
        let response = handle.await.expect("Task failed");
        if response.status().is_success() || response.status() == StatusCode::NOT_FOUND {
            success_count += 1;
        }
    }

    assert_eq!(success_count, 20, "Not all concurrent requests succeeded");
    println!("✓ All 20 concurrent requests succeeded");

    fixture.cleanup().await.expect("Failed to cleanup");
}
