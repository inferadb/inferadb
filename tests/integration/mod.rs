// Integration tests for InferaDB server-management authentication
//
// These tests validate end-to-end authentication flows between the server
// and management API, including JWT authentication, vault isolation, and
// cross-service integration.

use anyhow::{Context, Result};
use base64::Engine;
use chrono::{Duration, Utc};
use ed25519_dalek::{SigningKey, VerifyingKey};
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use rand::RngCore;
use reqwest::Client;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Re-export test modules
mod auth_jwt_tests;
mod cache_tests;
mod e2e_workflows_tests;
mod management_integration_tests;
mod resilience_tests;
mod vault_isolation_tests;
mod concurrency_tests;

/// Generate a random Ed25519 signing key
pub fn generate_signing_key() -> SigningKey {
    let mut rng = rand::thread_rng();
    let mut bytes = [0u8; 32];
    rng.fill_bytes(&mut bytes);
    SigningKey::from_bytes(&bytes)
}

/// Convert raw Ed25519 private key bytes (32 bytes) to PKCS#8 PEM format
/// This matches what the Management API does for JWT signing
fn ed25519_to_pem(private_key: &[u8; 32]) -> Vec<u8> {
    // PKCS#8 v1 structure for Ed25519:
    // SEQUENCE {
    //   INTEGER 0 (version)
    //   SEQUENCE {
    //     OBJECT IDENTIFIER 1.3.101.112 (Ed25519)
    //   }
    //   OCTET STRING {
    //     OCTET STRING <32 bytes private key>
    //   }
    // }

    // Ed25519 OID: 1.3.101.112
    let mut pkcs8_der = vec![
        0x30, 0x2e, // SEQUENCE (46 bytes)
        0x02, 0x01, 0x00, // INTEGER 0 (version)
        0x30, 0x05, // SEQUENCE (algorithm)
        0x06, 0x03, 0x2b, 0x65, 0x70, // OID 1.3.101.112
        0x04, 0x22, // OCTET STRING (34 bytes)
        0x04, 0x20, // OCTET STRING (32 bytes)
    ];
    pkcs8_der.extend_from_slice(private_key);

    // Convert to PEM
    let pem = format!(
        "-----BEGIN PRIVATE KEY-----\n{}\n-----END PRIVATE KEY-----\n",
        base64::engine::general_purpose::STANDARD.encode(&pkcs8_der)
    );

    pem.into_bytes()
}

/// Base URLs for services (from environment or defaults)
pub fn management_api_url() -> String {
    std::env::var("MANAGEMENT_API_URL").unwrap_or_else(|_| "http://management-api:8081".to_string())
}

pub fn server_url() -> String {
    std::env::var("SERVER_URL").unwrap_or_else(|_| "http://server:8080".to_string())
}

pub fn server_grpc_url() -> String {
    std::env::var("SERVER_GRPC_URL").unwrap_or_else(|_| "http://server:50051".to_string())
}

/// Test context containing all necessary state for integration tests
#[derive(Clone)]
pub struct TestContext {
    pub client: Client,
    pub management_url: String,
    pub server_url: String,
}

impl TestContext {
    pub fn new() -> Self {
        Self {
            client: Client::builder()
                .cookie_store(true)
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .expect("Failed to create HTTP client"),
            management_url: management_api_url(),
            server_url: server_url(),
        }
    }
}

/// User registration request
#[derive(Debug, Serialize)]
pub struct RegisterRequest {
    pub name: String,
    pub email: String,
    pub password: String,
    pub accept_tos: bool,
}

/// User registration response
#[derive(Debug, Deserialize)]
pub struct RegisterResponse {
    pub user_id: i64,
    pub name: String,
    pub email: String,
    pub session_id: i64,
}

/// Login request
#[derive(Debug, Serialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

/// Login response with session
#[derive(Debug, Deserialize)]
pub struct LoginResponse {
    pub user_id: i64,
    pub name: String,
    pub session_id: i64,
}

/// Organization creation request
#[derive(Debug, Serialize)]
pub struct CreateOrganizationRequest {
    pub name: String,
}

/// Organization response
#[derive(Debug, Deserialize)]
pub struct OrganizationResponse {
    pub id: i64,
    pub name: String,
    pub tier: String,
    pub created_at: String,
    pub role: String,
}

/// List organizations response (paginated)
#[derive(Debug, Deserialize)]
pub struct ListOrganizationsResponse {
    pub organizations: Vec<OrganizationResponse>,
    pub pagination: Option<serde_json::Value>, // We don't need to parse pagination metadata for tests
}

/// Vault creation request
#[derive(Debug, Serialize)]
pub struct CreateVaultRequest {
    pub name: String,
    pub organization_id: i64,
}

/// Vault info (inner structure)
#[derive(Debug, Deserialize)]
pub struct VaultInfo {
    pub id: i64,
    pub name: String,
    pub description: String,
    pub organization_id: i64,
    pub sync_status: String,
    pub created_at: String,
}

/// Vault creation response (wraps vault info)
#[derive(Debug, Deserialize)]
pub struct CreateVaultResponse {
    pub vault: VaultInfo,
}

/// Vault response (for GET operations)
#[derive(Debug, Deserialize)]
pub struct VaultResponse {
    pub id: i64,
    pub name: String,
    pub organization_id: i64,
    pub sync_status: String,
    pub sync_error: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub deleted_at: Option<String>,
}

/// Client creation request
#[derive(Debug, Serialize)]
pub struct CreateClientRequest {
    pub name: String,
}

/// Client info (inner structure)
#[derive(Debug, Deserialize)]
pub struct ClientInfo {
    pub id: i64,
    pub name: String,
    pub description: String,
    pub is_active: bool,
    pub organization_id: i64,
    pub created_at: String,
}

/// Client creation response (wraps client info)
#[derive(Debug, Deserialize)]
pub struct CreateClientResponse {
    pub client: ClientInfo,
}

/// Client response (for GET operations)
#[derive(Debug, Deserialize)]
pub struct ClientResponse {
    pub id: i64,
    pub name: String,
    pub is_active: bool,
    pub organization_id: i64,
    pub created_at: String,
}

/// Certificate creation request
#[derive(Debug, Serialize)]
pub struct CreateCertificateRequest {
    pub name: String,
}

/// Certificate response
#[derive(Debug, Deserialize)]
pub struct CertificateResponse {
    pub certificate: CertificateInfo,
    pub private_key: String,
}

#[derive(Debug, Deserialize)]
pub struct CertificateInfo {
    pub id: i64,
    pub kid: String,
    pub name: String,
    pub public_key: String,
    pub is_active: bool,
    pub created_at: String,
}

/// JWT claims for client authentication
/// Matches the Management API specification (see management/docs/Authentication.md)
#[derive(Debug, Serialize, Deserialize)]
pub struct ClientClaims {
    pub iss: String,
    pub sub: String,
    pub aud: String,
    pub exp: i64,
    pub iat: i64,
    pub jti: String,
    pub vault_id: String,
    pub org_id: String,
    pub scope: String,
    pub vault_role: String,
}

/// Test fixture for creating a complete test environment
pub struct TestFixture {
    pub ctx: TestContext,
    pub user_id: i64,
    pub session_id: i64,
    pub org_id: i64,
    pub vault_id: i64,
    pub client_id: i64,
    pub cert_id: i64,
    pub cert_kid: String,
    pub signing_key: SigningKey,
    pub verifying_key: VerifyingKey,
}

impl TestFixture {
    /// Create a complete test fixture with user, org, vault, and client
    pub async fn create() -> Result<Self> {
        let ctx = TestContext::new();

        // Register user
        let email = format!("test-{}@example.com", Uuid::new_v4());
        let register_req = RegisterRequest {
            name: "Test User".to_string(),
            email: email.clone(),
            password: "SecurePassword123!".to_string(),
            accept_tos: true,
        };

        let response = ctx
            .client
            .post(format!("{}/v1/auth/register", ctx.management_url))
            .json(&register_req)
            .send()
            .await
            .context("Failed to register user")?;

        let status = response.status();
        if !status.is_success() {
            let error_body = response.text().await.unwrap_or_else(|_| "Unable to read error body".to_string());
            anyhow::bail!("Registration failed with status {}: {}", status, error_body);
        }

        let register_resp: RegisterResponse = response
            .json()
            .await
            .context("Failed to parse registration response")?;

        let user_id = register_resp.user_id;

        // Login to get session
        let login_req = LoginRequest {
            email,
            password: "SecurePassword123!".to_string(),
        };

        let login_response = ctx
            .client
            .post(format!("{}/v1/auth/login/password", ctx.management_url))
            .json(&login_req)
            .send()
            .await
            .context("Failed to login")?;

        let login_status = login_response.status();
        if !login_status.is_success() {
            let error_body = login_response.text().await.unwrap_or_else(|_| "Unable to read error body".to_string());
            anyhow::bail!("Login failed with status {}: {}", login_status, error_body);
        }

        let login_resp: LoginResponse = login_response
            .json()
            .await
            .context("Failed to parse login response")?;

        let session_id = login_resp.session_id;

        // Get default organization (created during registration)
        let orgs_response: ListOrganizationsResponse = ctx
            .client
            .get(format!("{}/v1/organizations", ctx.management_url))
            .header("Authorization", format!("Bearer {}", session_id))
            .send()
            .await
            .context("Failed to list organizations")?
            .error_for_status()
            .context("List organizations failed")?
            .json()
            .await
            .context("Failed to parse organizations response")?;

        let org_id = orgs_response.organizations.first()
            .context("No default organization found")?
            .id;

        // Create vault
        let vault_req = CreateVaultRequest {
            name: format!("Test Vault {}", Uuid::new_v4()),
            organization_id: org_id,
        };

        let create_vault_resp: CreateVaultResponse = ctx
            .client
            .post(format!("{}/v1/organizations/{}/vaults", ctx.management_url, org_id))
            .header("Authorization", format!("Bearer {}", session_id))
            .json(&vault_req)
            .send()
            .await
            .context("Failed to create vault")?
            .error_for_status()
            .context("Vault creation failed")?
            .json()
            .await
            .context("Failed to parse vault response")?;

        let vault_id = create_vault_resp.vault.id;

        // Create client
        let client_req = CreateClientRequest {
            name: format!("Test Client {}", Uuid::new_v4()),
        };

        let create_client_resp: CreateClientResponse = ctx
            .client
            .post(format!(
                "{}/v1/organizations/{}/clients",
                ctx.management_url, org_id
            ))
            .header("Authorization", format!("Bearer {}", session_id))
            .json(&client_req)
            .send()
            .await
            .context("Failed to create client")?
            .error_for_status()
            .context("Client creation failed")?
            .json()
            .await
            .context("Failed to parse client response")?;

        let client_id = create_client_resp.client.id;

        // Create certificate (server generates the keypair)
        let cert_req = CreateCertificateRequest {
            name: format!("Test Certificate {}", Uuid::new_v4()),
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
            .context("Failed to create certificate")?
            .error_for_status()
            .context("Certificate creation failed")?
            .json()
            .await
            .context("Failed to parse certificate response")?;

        let cert_id = cert_resp.certificate.id;
        let cert_kid = cert_resp.certificate.kid;

        // Parse the server-generated private key (base64 encoded)
        let private_key_bytes = base64::engine::general_purpose::STANDARD
            .decode(&cert_resp.private_key)
            .context("Failed to decode private key")?;
        let signing_key = SigningKey::from_bytes(
            &private_key_bytes
                .try_into()
                .map_err(|_| anyhow::anyhow!("Invalid private key length"))?,
        );
        let verifying_key = signing_key.verifying_key();

        Ok(Self {
            ctx,
            user_id,
            session_id,
            org_id,
            vault_id,
            client_id,
            cert_id,
            cert_kid,
            signing_key,
            verifying_key,
        })
    }

    /// Generate a JWT token for the client with specified vault and scopes
    pub fn generate_jwt(&self, vault_id: Option<i64>, scopes: &[&str]) -> Result<String> {
        let now = Utc::now();

        // Determine vault_role based on scopes (following management API convention)
        let vault_role = if scopes.contains(&"inferadb.admin") {
            "admin"
        } else if scopes.contains(&"inferadb.vault.manage") {
            "manage"
        } else if scopes.contains(&"inferadb.write") {
            "write"
        } else {
            "read"
        };

        // Use scope format: space-separated inferadb.* scopes
        let scope_str = if scopes.is_empty() {
            // Default to read scope
            "inferadb.check inferadb.read inferadb.expand inferadb.list inferadb.list-relationships inferadb.list-subjects inferadb.list-resources".to_string()
        } else {
            scopes.join(" ")
        };

        let claims = ClientClaims {
            iss: self.ctx.management_url.clone(),
            sub: format!("client:{}", self.client_id),
            aud: self.ctx.server_url.clone(),
            exp: (now + Duration::minutes(5)).timestamp(),
            iat: now.timestamp(),
            jti: Uuid::new_v4().to_string(),
            vault_id: vault_id.unwrap_or(self.vault_id).to_string(),
            org_id: self.org_id.to_string(),
            scope: scope_str,
            vault_role: vault_role.to_string(),
        };

        let mut header = Header::new(Algorithm::EdDSA);
        header.kid = Some(self.cert_kid.clone());

        // Convert Ed25519 private key to PEM format for jsonwebtoken
        let secret_bytes = self.signing_key.to_bytes();
        let pem = ed25519_to_pem(&secret_bytes);
        let encoding_key = EncodingKey::from_ed_pem(&pem)
            .context("Failed to create encoding key")?;

        encode(&header, &claims, &encoding_key)
            .context("Failed to encode JWT")
    }

    /// Generate a JWT with a different signing key (for testing invalid signatures)
    pub fn generate_invalid_jwt(&self) -> Result<String> {
        let wrong_key = generate_signing_key();
        let now = Utc::now();

        let claims = ClientClaims {
            iss: self.ctx.management_url.clone(),
            sub: format!("client:{}", self.client_id),
            aud: self.ctx.server_url.clone(),
            exp: (now + Duration::minutes(5)).timestamp(),
            iat: now.timestamp(),
            jti: Uuid::new_v4().to_string(),
            vault_id: self.vault_id.to_string(),
            org_id: self.org_id.to_string(),
            scope: "inferadb.check inferadb.read inferadb.write inferadb.expand inferadb.list inferadb.list-relationships inferadb.list-subjects inferadb.list-resources".to_string(),
            vault_role: "write".to_string(),
        };

        let mut header = Header::new(Algorithm::EdDSA);
        header.kid = Some(self.cert_kid.clone());

        let secret_bytes = wrong_key.to_bytes();
        let pem = ed25519_to_pem(&secret_bytes);
        let encoding_key = EncodingKey::from_ed_pem(&pem)
            .context("Failed to create encoding key for invalid JWT")?;

        encode(&header, &claims, &encoding_key)
            .context("Failed to encode invalid JWT")
    }

    /// Call server evaluate endpoint with JWT
    pub async fn call_server_evaluate(
        &self,
        jwt: &str,
        resource: &str,
        permission: &str,
        subject: &str,
    ) -> Result<reqwest::Response> {
        // Build evaluation request matching the server's expected format
        let evaluation = serde_json::json!({
            "subject": subject,
            "resource": resource,
            "permission": permission,
            "trace": false
        });

        let body = serde_json::json!({
            "evaluations": [evaluation]
        });

        self.ctx
            .client
            .post(format!("{}/v1/evaluate", self.ctx.server_url))
            .header("Authorization", format!("Bearer {}", jwt))
            .json(&body)
            .send()
            .await
            .context("Failed to call server evaluate endpoint")
    }

    /// Cleanup test resources
    pub async fn cleanup(&self) -> Result<()> {
        // Delete vault
        let _ = self
            .ctx
            .client
            .delete(format!(
                "{}/v1/organizations/{}/vaults/{}",
                self.ctx.management_url, self.org_id, self.vault_id
            ))
            .header("Authorization", format!("Bearer {}", self.session_id))
            .send()
            .await;

        // Delete client
        let _ = self
            .ctx
            .client
            .delete(format!(
                "{}/v1/organizations/{}/clients/{}",
                self.ctx.management_url, self.org_id, self.client_id
            ))
            .header("Authorization", format!("Bearer {}", self.session_id))
            .send()
            .await;

        // Delete organization
        let _ = self
            .ctx
            .client
            .delete(format!(
                "{}/v1/organizations/{}",
                self.ctx.management_url, self.org_id
            ))
            .header("Authorization", format!("Bearer {}", self.session_id))
            .send()
            .await;

        // Delete user
        let _ = self
            .ctx
            .client
            .delete(format!(
                "{}/v1/users/{}",
                self.ctx.management_url, self.user_id
            ))
            .header("Authorization", format!("Bearer {}", self.session_id))
            .send()
            .await;

        Ok(())
    }
}

impl Drop for TestFixture {
    fn drop(&mut self) {
        // Best-effort cleanup on drop
        let ctx = self.ctx.clone();
        let session_id = self.session_id;
        let vault_id = self.vault_id;
        let org_id = self.org_id;
        let client_id = self.client_id;
        let user_id = self.user_id;
        let management_url = self.ctx.management_url.clone();

        tokio::spawn(async move {
            let _ = ctx
                .client
                .delete(format!("{}/v1/organizations/{}/vaults/{}", management_url, org_id, vault_id))
                .header("Authorization", format!("Bearer {}", session_id))
                .send()
                .await;

            let _ = ctx
                .client
                .delete(format!(
                    "{}/v1/organizations/{}/clients/{}",
                    management_url, org_id, client_id
                ))
                .header("Authorization", format!("Bearer {}", session_id))
                .send()
                .await;

            let _ = ctx
                .client
                .delete(format!("{}/v1/organizations/{}", management_url, org_id))
                .header("Authorization", format!("Bearer {}", session_id))
                .send()
                .await;

            let _ = ctx
                .client
                .delete(format!("{}/v1/users/{}", management_url, user_id))
                .header("Authorization", format!("Bearer {}", session_id))
                .send()
                .await;
        });
    }
}
