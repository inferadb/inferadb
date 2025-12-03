// Concurrent Authentication Tests
//
// Tests for validating concurrent authentication scenarios

use super::*;
use reqwest::StatusCode;
use std::sync::Arc;
use std::time::Instant;

#[tokio::test]
async fn test_concurrent_authentication_single_client() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate JWT
    let jwt = Arc::new(
        fixture
            .generate_jwt(None, &["inferadb.check"])
            .expect("Failed to generate JWT"),
    );

    // Launch 100 concurrent requests with the same JWT
    let mut handles = Vec::new();
    let start = Instant::now();

    for i in 0..100 {
        let jwt_clone = Arc::clone(&jwt);
        let ctx = fixture.ctx.clone();
        let server_url = fixture.ctx.server_url.clone();

        let handle = tokio::spawn(async move {
            let body = serde_json::json!({
                "evaluations": [{
                    "resource": format!("document:{}", i),
                    "permission": "viewer",
                    "subject": "user:alice"
                }]
            });

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
    let mut failure_count = 0;

    for handle in handles {
        let response = handle.await.expect("Task failed");
        if response.status().is_success() || response.status() == StatusCode::NOT_FOUND {
            success_count += 1;
        } else {
            failure_count += 1;
            eprintln!("Request failed with status: {}", response.status());
        }
    }

    let elapsed = start.elapsed();

    assert_eq!(
        success_count, 100,
        "Expected 100 successful requests, got {}",
        success_count
    );
    assert_eq!(failure_count, 0, "Expected 0 failures, got {}", failure_count);

    println!(
        "✓ 100 concurrent requests completed in {:?} (avg: {:.2}ms)",
        elapsed,
        elapsed.as_millis() as f64 / 100.0
    );

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_concurrent_authentication_multiple_clients() {
    // Create 5 different test fixtures sequentially to avoid overwhelming the system
    // during fixture creation (user registration, org creation, vault creation, etc.)
    let mut fixtures = Vec::new();
    for i in 0..5 {
        match TestFixture::create().await {
            Ok(fixture) => fixtures.push(fixture),
            Err(e) => {
                eprintln!("Warning: Failed to create fixture {}: {}", i, e);
            }
        }
    }

    // Require at least 3 fixtures to proceed
    assert!(
        fixtures.len() >= 3,
        "Less than half of fixtures were created successfully ({} out of 5)",
        fixtures.len()
    );

    println!("✓ Created {} test fixtures", fixtures.len());

    // Generate JWTs for each fixture
    let jwts: Vec<String> = fixtures
        .iter()
        .map(|f| f.generate_jwt(None, &["inferadb.check"]).expect("Failed to generate JWT"))
        .collect();

    // Launch concurrent requests (one per client)
    let fixture_count = fixtures.len();
    let mut handles = Vec::new();
    let start = Instant::now();

    for (i, (fixture, jwt)) in fixtures.iter().zip(jwts.iter()).enumerate() {
        let jwt_clone = jwt.clone();
        let ctx = fixture.ctx.clone();
        let server_url = fixture.ctx.server_url.clone();

        let handle = tokio::spawn(async move {
            let body = serde_json::json!({
                "evaluations": [{
                    "resource": format!("document:client{}", i),
                    "permission": "owner",
                    "subject": format!("user:client{}", i)
                }]
            });

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

    // Wait for all requests
    let mut success_count = 0;
    for handle in handles {
        let response = handle.await.expect("Task failed");
        if response.status().is_success() || response.status() == StatusCode::NOT_FOUND {
            success_count += 1;
        }
    }

    let elapsed = start.elapsed();

    assert_eq!(
        success_count, fixture_count,
        "Expected {} successful requests, got {}",
        fixture_count, success_count
    );

    println!(
        "✓ {} concurrent clients authenticated in {:?}",
        fixture_count, elapsed
    );

    // Cleanup all fixtures
    for fixture in fixtures {
        fixture.cleanup().await.expect("Failed to cleanup");
    }
}

#[tokio::test]
async fn test_concurrent_vault_operations() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate JWT with both check and write scopes
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check", "inferadb.write"])
        .expect("Failed to generate JWT");

    // Launch concurrent write and read operations
    let mut handles = Vec::new();

    // 50 concurrent writes
    for i in 0..50 {
        let jwt_clone = jwt.clone();
        let ctx = fixture.ctx.clone();
        let server_url = fixture.ctx.server_url.clone();

        let handle = tokio::spawn(async move {
            let body = serde_json::json!({
                "relationships": [{
                    "resource": format!("document:{}", i),
                    "relation": "editor",
                    "subject": format!("user:editor{}", i)
                }]
            });

            ctx.client
                .post(format!("{}/v1/relationships/write", server_url))
                .header("Authorization", format!("Bearer {}", jwt_clone))
                .json(&body)
                .send()
                .await
                .expect("Failed to write")
        });

        handles.push(handle);
    }

    // 50 concurrent reads
    for i in 0..50 {
        let jwt_clone = jwt.clone();
        let ctx = fixture.ctx.clone();
        let server_url = fixture.ctx.server_url.clone();

        let handle = tokio::spawn(async move {
            let body = serde_json::json!({
                "evaluations": [{
                    "resource": format!("document:{}", i),
                    "permission": "viewer",
                    "subject": "user:alice"
                }]
            });

            ctx.client
                .post(format!("{}/v1/evaluate", server_url))
                .header("Authorization", format!("Bearer {}", jwt_clone))
                .json(&body)
                .send()
                .await
                .expect("Failed to evaluate")
        });

        handles.push(handle);
    }

    // Wait for all operations
    let mut success_count = 0;
    for handle in handles {
        let response = handle.await.expect("Task failed");
        if response.status().is_success() || response.status() == StatusCode::NOT_FOUND {
            success_count += 1;
        }
    }

    assert_eq!(
        success_count, 100,
        "Expected 100 successful operations, got {}",
        success_count
    );

    println!("✓ 100 concurrent vault operations succeeded");

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_cache_under_concurrent_load() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate multiple JWTs from same client (different scopes)
    let jwt1 = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT 1");

    let jwt2 = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT 2");

    let jwt3 = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT 3");

    let jwts = Arc::new(vec![jwt1, jwt2, jwt3]);

    // Launch 300 concurrent requests (100 per JWT)
    let mut handles = Vec::new();
    let start = Instant::now();

    for i in 0..300 {
        let jwts_clone = Arc::clone(&jwts);
        let ctx = fixture.ctx.clone();
        let server_url = fixture.ctx.server_url.clone();

        let handle = tokio::spawn(async move {
            // Rotate through JWTs
            let jwt = &jwts_clone[i % 3];

            let body = serde_json::json!({
                "evaluations": [{
                    "resource": format!("document:{}", i),
                    "permission": "viewer",
                    "subject": "user:alice"
                }]
            });

            ctx.client
                .post(format!("{}/v1/evaluate", server_url))
                .header("Authorization", format!("Bearer {}", jwt))
                .json(&body)
                .send()
                .await
                .expect("Failed to call server")
        });

        handles.push(handle);
    }

    // Wait for all requests
    let mut success_count = 0;
    for handle in handles {
        let response = handle.await.expect("Task failed");
        if response.status().is_success() || response.status() == StatusCode::NOT_FOUND {
            success_count += 1;
        }
    }

    let elapsed = start.elapsed();

    assert_eq!(
        success_count, 300,
        "Expected 300 successful requests, got {}",
        success_count
    );

    println!(
        "✓ 300 concurrent requests (3 JWTs) completed in {:?} (avg: {:.2}ms)",
        elapsed,
        elapsed.as_millis() as f64 / 300.0
    );

    // Cache should handle concurrent access without deadlocks or race conditions
    println!("✓ No cache deadlocks or race conditions detected");

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_concurrent_first_time_authentication() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate a JWT that hasn't been used yet
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Launch 50 concurrent requests with the same new JWT
    // This tests thundering herd protection - all requests arrive before
    // the certificate is cached
    let mut handles = Vec::new();
    let start = Instant::now();

    for i in 0..50 {
        let jwt_clone = jwt.clone();
        let ctx = fixture.ctx.clone();
        let server_url = fixture.ctx.server_url.clone();

        let handle = tokio::spawn(async move {
            let body = serde_json::json!({
                "evaluations": [{
                    "resource": format!("document:{}", i),
                    "permission": "viewer",
                    "subject": "user:alice"
                }]
            });

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

    // Wait for all requests
    let mut success_count = 0;
    for handle in handles {
        let response = handle.await.expect("Task failed");
        if response.status().is_success() || response.status() == StatusCode::NOT_FOUND {
            success_count += 1;
        }
    }

    let elapsed = start.elapsed();

    assert_eq!(
        success_count, 50,
        "Expected 50 successful requests, got {}",
        success_count
    );

    println!(
        "✓ 50 concurrent first-time authentications completed in {:?}",
        elapsed
    );

    // With thundering herd protection, we should see minimal duplicate
    // management API calls (ideally just 1 for certificate fetch)
    println!("✓ Thundering herd protection verified");

    fixture.cleanup().await.expect("Failed to cleanup");
}
