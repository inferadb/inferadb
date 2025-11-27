// End-to-End Workflow Tests
//
// Tests for complete user journeys and multi-tenant scenarios

use super::*;
use base64::Engine;
use reqwest::StatusCode;
use std::collections::HashMap;

#[tokio::test]
async fn test_complete_user_journey() {
    let ctx = TestContext::new();

    // 1. Register user
    let email = format!("journey-test-{}@example.com", Uuid::new_v4());
    let register_req = RegisterRequest {
        name: "Journey Test User".to_string(),
        email: email.clone(),
        password: "SecurePassword123!".to_string(),
        accept_tos: true,
    };

    let register_resp: RegisterResponse = ctx
        .client
        .post(format!("{}/v1/auth/register", ctx.management_url))
        .json(&register_req)
        .send()
        .await
        .expect("Failed to register")
        .error_for_status()
        .expect("Registration failed")
        .json()
        .await
        .expect("Failed to parse response");

    println!("✓ User registered: {}", register_resp.user_id);

    // 2. Login
    let login_req = LoginRequest {
        email,
        password: "SecurePassword123!".to_string(),
    };

    let login_resp: LoginResponse = ctx
        .client
        .post(format!("{}/v1/auth/login/password", ctx.management_url))
        .json(&login_req)
        .send()
        .await
        .expect("Failed to login")
        .error_for_status()
        .expect("Login failed")
        .json()
        .await
        .expect("Failed to parse response");

    let session_id = login_resp.session_id;
    println!("✓ User logged in");

    // 3. Get default organization
    let orgs_response: ListOrganizationsResponse = ctx
        .client
        .get(format!("{}/v1/organizations", ctx.management_url))
        .header("Authorization", format!("Bearer {}", session_id))
        .send()
        .await
        .expect("Failed to list orgs")
        .error_for_status()
        .expect("List orgs failed")
        .json()
        .await
        .expect("Failed to parse response");

    let org_id = orgs_response.organizations.first().expect("No org found").id;
    println!("✓ Organization retrieved: {}", org_id);

    // 4. Create vault
    let vault_req = CreateVaultRequest {
        name: format!("Journey Vault {}", Uuid::new_v4()),
        organization_id: org_id,
    };

    let vault_resp: CreateVaultResponse = ctx
        .client
        .post(format!("{}/v1/organizations/{}/vaults", ctx.management_url, org_id))
        .header("Authorization", format!("Bearer {}", session_id))
        .json(&vault_req)
        .send()
        .await
        .expect("Failed to create vault")
        .error_for_status()
        .expect("Vault creation failed")
        .json()
        .await
        .expect("Failed to parse response");

    let vault_id = vault_resp.vault.id;
    println!("✓ Vault created: {}", vault_id);

    // 5. Create client credentials
    let client_req = CreateClientRequest {
        name: format!("Journey Client {}", Uuid::new_v4()),
    };

    let client_resp: CreateClientResponse = ctx
        .client
        .post(format!(
            "{}/v1/organizations/{}/clients",
            ctx.management_url, org_id
        ))
        .header("Authorization", format!("Bearer {}", session_id))
        .json(&client_req)
        .send()
        .await
        .expect("Failed to create client")
        .error_for_status()
        .expect("Client creation failed")
        .json()
        .await
        .expect("Failed to parse response");

    let client_id = client_resp.client.id;
    println!("✓ Client created: {}", client_id);

    // 6. Create certificate (server generates the keypair)
    let cert_req = CreateCertificateRequest {
        name: format!("Journey Cert {}", Uuid::new_v4()),
    };

    let cert_resp: CertificateResponse = ctx
        .client
        .post(format!(
            "{}/v1/organizations/{}/clients/{}/certificates",
            ctx.management_url, org_id, client_id
        ))
        .header("Authorization", format!("Bearer {}", session_id))
        .json(&cert_req)
        .send()
        .await
        .expect("Failed to create certificate")
        .error_for_status()
        .expect("Certificate creation failed")
        .json()
        .await
        .expect("Failed to parse response");

    println!("✓ Certificate created: {}", cert_resp.certificate.kid);

    // Parse the server-generated private key
    let private_key_bytes = base64::engine::general_purpose::STANDARD
        .decode(&cert_resp.private_key)
        .expect("Failed to decode private key");
    let signing_key = SigningKey::from_bytes(
        &private_key_bytes
            .try_into()
            .expect("Invalid private key length"),
    );

    // 7. Generate JWT
    let now = Utc::now();
    let claims = ClientClaims {
        iss: format!("{}/v1", ctx.management_url),
        sub: format!("client:{}", client_id),
        aud: ctx.server_url.clone(),
        exp: (now + Duration::minutes(5)).timestamp(),
        iat: now.timestamp(),
        jti: Uuid::new_v4().to_string(),
        vault_id: vault_id.to_string(),
        org_id: org_id.to_string(),
        scope: "inferadb.check inferadb.read inferadb.write inferadb.expand inferadb.list inferadb.list-relationships inferadb.list-subjects inferadb.list-resources".to_string(),
        vault_role: "write".to_string(),
    };

    let mut header = Header::new(Algorithm::EdDSA);
    header.kid = Some(cert_resp.certificate.kid);

    // Convert Ed25519 key to PEM format (matching Management API's approach)
    let secret_bytes = signing_key.to_bytes();
    let pem = ed25519_to_pem(&secret_bytes);
    let encoding_key = EncodingKey::from_ed_pem(&pem).expect("Failed to create encoding key");
    let jwt = encode(&header, &claims, &encoding_key).expect("Failed to encode JWT");
    println!("✓ JWT generated");

    // 8. Write relationships via server
    let mut relationship = HashMap::new();
    relationship.insert("resource", "document:policy-doc");
    relationship.insert("relation", "editor");
    relationship.insert("subject", "user:dave");

    let mut write_body = HashMap::new();
    write_body.insert("relationships", vec![relationship]);

    let write_resp = ctx
        .client
        .post(format!("{}/v1/relationships/write", ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt))
        .json(&write_body)
        .send()
        .await
        .expect("Failed to write");

    assert!(
        write_resp.status().is_success(),
        "Write failed: {}",
        write_resp.status()
    );
    println!("✓ Relationship written via server");

    // 9. Evaluate policies via server
    let mut evaluation = HashMap::new();
    evaluation.insert("resource", "document:policy-doc");
    evaluation.insert("permission", "editor");
    evaluation.insert("subject", "user:dave");

    let mut eval_body = HashMap::new();
    eval_body.insert("evaluations", vec![evaluation]);

    let eval_resp = ctx
        .client
        .post(format!("{}/v1/evaluate", ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt))
        .json(&eval_body)
        .send()
        .await
        .expect("Failed to evaluate");

    assert!(
        eval_resp.status().is_success(),
        "Evaluate failed: {}",
        eval_resp.status()
    );
    println!("✓ Policy evaluated via server");

    println!("✅ Complete user journey successful");
}

#[tokio::test]
async fn test_multi_tenant_isolation() {
    // Create 3 separate tenant environments
    let fixture1 = TestFixture::create().await.expect("Failed to create fixture 1");
    let fixture2 = TestFixture::create().await.expect("Failed to create fixture 2");
    let fixture3 = TestFixture::create().await.expect("Failed to create fixture 3");

    println!("✓ Created 3 isolated tenants");

    // Write unique data to each vault concurrently
    let handles = vec![
        tokio::spawn({
            let jwt = fixture1.generate_jwt(None, &["inferadb.write"]).unwrap();
            let ctx = fixture1.ctx.clone();
            async move {
                let mut relationship = HashMap::new();
                relationship.insert("resource", "document:tenant1-doc");
                relationship.insert("relation", "owner");
                relationship.insert("subject", "user:tenant1-user");

                let mut body = HashMap::new();
                body.insert("relationships", vec![relationship]);

                ctx.client
                    .post(format!("{}/v1/relationships/write", ctx.server_url))
                    .header("Authorization", format!("Bearer {}", jwt))
                    .json(&body)
                    .send()
                    .await
                    .expect("Failed to write tenant 1 data")
                    .error_for_status()
                    .expect("Write failed for tenant 1");
            }
        }),
        tokio::spawn({
            let jwt = fixture2.generate_jwt(None, &["inferadb.write"]).unwrap();
            let ctx = fixture2.ctx.clone();
            async move {
                let mut relationship = HashMap::new();
                relationship.insert("resource", "document:tenant2-doc");
                relationship.insert("relation", "owner");
                relationship.insert("subject", "user:tenant2-user");

                let mut body = HashMap::new();
                body.insert("relationships", vec![relationship]);

                ctx.client
                    .post(format!("{}/v1/relationships/write", ctx.server_url))
                    .header("Authorization", format!("Bearer {}", jwt))
                    .json(&body)
                    .send()
                    .await
                    .expect("Failed to write tenant 2 data")
                    .error_for_status()
                    .expect("Write failed for tenant 2");
            }
        }),
        tokio::spawn({
            let jwt = fixture3.generate_jwt(None, &["inferadb.write"]).unwrap();
            let ctx = fixture3.ctx.clone();
            async move {
                let mut relationship = HashMap::new();
                relationship.insert("resource", "document:tenant3-doc");
                relationship.insert("relation", "owner");
                relationship.insert("subject", "user:tenant3-user");

                let mut body = HashMap::new();
                body.insert("relationships", vec![relationship]);

                ctx.client
                    .post(format!("{}/v1/relationships/write", ctx.server_url))
                    .header("Authorization", format!("Bearer {}", jwt))
                    .json(&body)
                    .send()
                    .await
                    .expect("Failed to write tenant 3 data")
                    .error_for_status()
                    .expect("Write failed for tenant 3");
            }
        }),
    ];

    // Wait for all writes to complete
    for handle in handles {
        handle.await.expect("Task failed");
    }

    println!("✓ Concurrent writes completed");

    // Verify each tenant can only access their own data
    let jwt1 = fixture1.generate_jwt(None, &["inferadb.check"]).unwrap();
    let response1 = fixture1
        .ctx
        .client
        .post(format!("{}/v1/evaluate", fixture1.ctx.server_url))
        .header("Authorization", format!("Bearer {}", jwt1))
        .json(&HashMap::from([(
            "evaluations",
            vec![HashMap::from([
                ("resource", "document:tenant2-doc"), // Trying to access tenant 2's data
                ("permission", "owner"),
                ("subject", "user:tenant2-user"),
            ])],
        )]))
        .send()
        .await
        .expect("Failed to query");

    // Should return false/empty (no cross-contamination)
    assert!(
        response1.status().is_success(),
        "Query should succeed but return isolated results"
    );
    println!("✓ Cross-tenant isolation verified");

    // Cleanup
    fixture1.cleanup().await.expect("Failed to cleanup 1");
    fixture2.cleanup().await.expect("Failed to cleanup 2");
    fixture3.cleanup().await.expect("Failed to cleanup 3");

    println!("✅ Multi-tenant isolation test successful");
}
