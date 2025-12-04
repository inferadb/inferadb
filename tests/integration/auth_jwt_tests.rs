// JWT Authentication Flow Tests
//
// Tests for validating JWT-based authentication between server and management API

use super::*;
use reqwest::StatusCode;

#[tokio::test]
async fn test_valid_jwt_from_management_client() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate valid JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Call server with valid JWT
    let response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should succeed with 200 or 404 (if no relationships exist)
    assert!(
        response.status() == StatusCode::OK || response.status() == StatusCode::NOT_FOUND,
        "Expected 200 or 404, got {}",
        response.status()
    );

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_jwt_with_invalid_signature() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT with wrong signing key
    let jwt = fixture
        .generate_invalid_jwt()
        .expect("Failed to generate invalid JWT");

    // Call server with invalid JWT
    let response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail with 401 Unauthorized
    assert_eq!(
        response.status(),
        StatusCode::UNAUTHORIZED,
        "Expected 401 Unauthorized for invalid signature"
    );

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_jwt_for_nonexistent_vault() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT with fake vault UUID
    let fake_vault_id: i64 = 999999999; // Fake Snowflake ID
    let jwt = fixture
        .generate_jwt(Some(fake_vault_id), &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Call server with JWT for non-existent vault
    let response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail with 404 Not Found (vault doesn't exist in management API)
    assert_eq!(
        response.status(),
        StatusCode::NOT_FOUND,
        "Expected 404 Not Found for non-existent vault"
    );

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_jwt_for_vault_in_different_org() {
    // Create two separate test fixtures (two different orgs)
    let fixture1 = TestFixture::create()
        .await
        .expect("Failed to create first fixture");
    let fixture2 = TestFixture::create()
        .await
        .expect("Failed to create second fixture");

    // Try to use client from org A (fixture1) with vault from org B (fixture2)
    let jwt_with_wrong_vault = fixture1
        .generate_jwt(Some(fixture2.vault_id), &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Call server - should fail because vault belongs to different org
    let response = fixture1
        .call_server_evaluate(&jwt_with_wrong_vault, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail with 403 Forbidden (ownership mismatch)
    assert_eq!(
        response.status(),
        StatusCode::FORBIDDEN,
        "Expected 403 Forbidden for cross-org vault access"
    );

    fixture1
        .cleanup()
        .await
        .expect("Failed to cleanup fixture1");
    fixture2
        .cleanup()
        .await
        .expect("Failed to cleanup fixture2");
}

#[tokio::test]
async fn test_jwt_with_missing_required_scope() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT without required scopes
    let jwt = fixture
        .generate_jwt(None, &[])
        .expect("Failed to generate JWT");

    // Call server with insufficient scopes
    let response = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Behavior depends on server's scope enforcement
    // Should either succeed (if scopes not enforced on this endpoint) or fail with 403
    assert!(
        response.status() == StatusCode::OK
            || response.status() == StatusCode::FORBIDDEN
            || response.status() == StatusCode::NOT_FOUND,
        "Unexpected status code: {}",
        response.status()
    );

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_jwt_with_expired_token() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT with past expiration (requires custom encoding)
    let now = Utc::now();
    let claims = ClientClaims {
        iss: fixture.ctx.management_url.clone(),
        sub: format!("client:{}", fixture.client_id),
        aud: fixture.ctx.server_url.clone(),
        exp: (now - Duration::minutes(10)).timestamp(), // Expired 10 minutes ago
        iat: (now - Duration::minutes(15)).timestamp(),
        jti: Uuid::new_v4().to_string(),
        vault_id: fixture.vault_id.to_string(),
        org_id: fixture.org_id.to_string(),
        scope: "inferadb.check inferadb.read inferadb.write inferadb.expand inferadb.list inferadb.list-relationships inferadb.list-subjects inferadb.list-resources".to_string(),
        vault_role: "write".to_string(),
    };

    let mut header = Header::new(Algorithm::EdDSA);
    header.kid = Some(fixture.cert_kid.clone());

    let secret_bytes = fixture.signing_key.to_bytes();
    let pem = ed25519_to_pem(&secret_bytes);
    let encoding_key = EncodingKey::from_ed_pem(&pem).expect("Failed to create encoding key");
    let expired_jwt = encode(&header, &claims, &encoding_key).expect("Failed to encode JWT");

    // Call server with expired JWT
    let response = fixture
        .call_server_evaluate(&expired_jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail with 401 Unauthorized
    assert_eq!(
        response.status(),
        StatusCode::UNAUTHORIZED,
        "Expected 401 Unauthorized for expired token"
    );

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_jwt_with_invalid_kid() {
    let fixture = TestFixture::create()
        .await
        .expect("Failed to create test fixture");

    // Generate JWT with fake kid
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
    // Use fake Snowflake IDs for invalid kid test
    header.kid = Some(format!(
        "org-{}-client-{}-cert-{}",
        999999999i64, 888888888i64, 777777777i64
    ));

    let secret_bytes = fixture.signing_key.to_bytes();
    let pem = ed25519_to_pem(&secret_bytes);
    let encoding_key = EncodingKey::from_ed_pem(&pem).expect("Failed to create encoding key");
    let invalid_kid_jwt = encode(&header, &claims, &encoding_key).expect("Failed to encode JWT");

    // Call server with invalid kid
    let response = fixture
        .call_server_evaluate(&invalid_kid_jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    // Should fail with 401 Unauthorized (cannot fetch certificate)
    assert_eq!(
        response.status(),
        StatusCode::UNAUTHORIZED,
        "Expected 401 Unauthorized for invalid kid"
    );

    fixture.cleanup().await.expect("Failed to cleanup");
}
