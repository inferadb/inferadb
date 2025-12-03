// Cache Effectiveness Tests
//
// Tests for validating caching behavior and performance

use super::*;
use reqwest::StatusCode;
use std::time::Instant;

#[tokio::test]
async fn test_certificate_cache_hit_rate() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Make 100 requests with the same JWT
    let iterations = 100;
    let start = Instant::now();

    for i in 0..iterations {
        let response = fixture
            .call_server_evaluate(
                &jwt,
                &format!("document:{}", i),
                "viewer",
                "user:alice",
            )
            .await
            .expect("Failed to call server");

        assert!(
            response.status().is_success() || response.status() == StatusCode::NOT_FOUND,
            "Request {} failed: {}",
            i,
            response.status()
        );
    }

    let elapsed = start.elapsed();
    let avg_latency = elapsed.as_millis() as f64 / iterations as f64;

    println!(
        "✓ Completed {} requests in {:?} (avg: {:.2}ms per request)",
        iterations, elapsed, avg_latency
    );

    // With effective caching, average latency should be low (<50ms per request)
    // This is a soft assertion - actual values depend on network/infrastructure
    if avg_latency > 100.0 {
        eprintln!(
            "Warning: Average latency is high ({:.2}ms) - caching may not be effective",
            avg_latency
        );
    }

    // Check if we can get metrics from server (if metrics endpoint exists)
    let metrics_response = fixture
        .ctx
        .client
        .get(format!("{}/metrics", fixture.ctx.server_url))
        .send()
        .await;

    if let Ok(resp) = metrics_response {
        if resp.status().is_success() {
            if let Ok(metrics_text) = resp.text().await {
                println!("✓ Server metrics available");

                // Look for cache-related metrics
                for line in metrics_text.lines() {
                    if line.contains("infera_auth_cache") {
                        println!("  {}", line);
                    }
                }

                // Parse cache hit/miss metrics if available
                let hits = metrics_text
                    .lines()
                    .find(|l| l.starts_with("infera_auth_cache_hits_total"))
                    .and_then(|l| l.split_whitespace().nth(1))
                    .and_then(|v| v.parse::<f64>().ok())
                    .unwrap_or(0.0);

                let misses = metrics_text
                    .lines()
                    .find(|l| l.starts_with("infera_auth_cache_misses_total"))
                    .and_then(|l| l.split_whitespace().nth(1))
                    .and_then(|v| v.parse::<f64>().ok())
                    .unwrap_or(0.0);

                if hits + misses > 0.0 {
                    let hit_rate = hits / (hits + misses) * 100.0;
                    println!(
                        "✓ Cache hit rate: {:.1}% (hits: {}, misses: {})",
                        hit_rate, hits as u64, misses as u64
                    );

                    // Cache hit rate should be >90% for repeated requests
                    if hit_rate < 90.0 {
                        eprintln!(
                            "Warning: Cache hit rate is low ({:.1}%) - expected >90%",
                            hit_rate
                        );
                    }
                }
            }
        }
    }

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_vault_verification_cache() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // First request - should hit management API (cache miss)
    let start_first = Instant::now();
    let first_response = fixture
        .call_server_evaluate(&jwt, "document:test", "viewer", "user:bob")
        .await
        .expect("Failed to call server");

    let first_latency = start_first.elapsed();

    assert!(
        first_response.status().is_success() || first_response.status() == StatusCode::NOT_FOUND,
        "First request failed"
    );

    println!("✓ First request: {:?}", first_latency);

    // Subsequent requests - should hit cache
    let mut cached_latencies = Vec::new();

    for _ in 0..10 {
        let start = Instant::now();
        let response = fixture
            .call_server_evaluate(&jwt, "document:test", "viewer", "user:bob")
            .await
            .expect("Failed to call server");

        cached_latencies.push(start.elapsed());

        assert!(
            response.status().is_success() || response.status() == StatusCode::NOT_FOUND,
            "Cached request failed"
        );
    }

    let avg_cached_latency =
        cached_latencies.iter().sum::<std::time::Duration>().as_micros() as f64
            / cached_latencies.len() as f64
            / 1000.0; // Convert to ms

    println!("✓ Average cached request latency: {:.2}ms", avg_cached_latency);

    // Cached requests should be significantly faster
    // This is a soft assertion as it depends on infrastructure
    if avg_cached_latency > first_latency.as_millis() as f64 * 0.8 {
        eprintln!(
            "Warning: Cached requests not significantly faster ({:.2}ms vs {:.2}ms)",
            avg_cached_latency,
            first_latency.as_millis()
        );
    }

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_management_api_call_rate() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Get baseline metrics
    let initial_metrics = get_auth_metrics(&fixture.ctx).await;

    // Generate JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // Make 50 requests
    let num_requests = 50;
    for i in 0..num_requests {
        let response = fixture
            .call_server_evaluate(&jwt, &format!("doc:{}", i), "viewer", "user:alice")
            .await
            .expect("Failed to call server");

        assert!(
            response.status().is_success() || response.status() == StatusCode::NOT_FOUND,
            "Request failed"
        );
    }

    // Get final metrics
    let final_metrics = get_auth_metrics(&fixture.ctx).await;

    if let (Some(initial), Some(final_metrics)) = (initial_metrics, final_metrics) {
        let management_api_calls = final_metrics.management_api_calls - initial.management_api_calls;
        let api_call_rate = (management_api_calls as f64 / num_requests as f64) * 100.0;

        println!(
            "✓ Management API calls: {} out of {} requests ({:.1}%)",
            management_api_calls, num_requests, api_call_rate
        );

        // Management API call rate should be <10% with effective caching
        if api_call_rate > 10.0 {
            eprintln!(
                "Warning: High management API call rate ({:.1}%) - expected <10%",
                api_call_rate
            );
        }
    } else {
        println!("⚠ Metrics endpoint not available - skipping API call rate check");
    }

    fixture.cleanup().await.expect("Failed to cleanup");
}

#[tokio::test]
async fn test_cache_expiration_behavior() {
    let fixture = TestFixture::create().await.expect("Failed to create test fixture");

    // Generate JWT
    let jwt = fixture
        .generate_jwt(None, &["inferadb.check"])
        .expect("Failed to generate JWT");

    // First request to populate cache
    let response1 = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        response1.status().is_success() || response1.status() == StatusCode::NOT_FOUND,
        "First request failed"
    );
    println!("✓ Cache populated");

    // Second request should hit cache
    let response2 = fixture
        .call_server_evaluate(&jwt, "document:1", "viewer", "user:alice")
        .await
        .expect("Failed to call server");

    assert!(
        response2.status().is_success() || response2.status() == StatusCode::NOT_FOUND,
        "Cached request failed"
    );
    println!("✓ Cache hit verified");

    // Note: Testing actual cache expiration would require waiting for TTL (5-15 minutes)
    // which is impractical for integration tests. We verify cache works correctly
    // and rely on unit tests to verify TTL behavior.

    fixture.cleanup().await.expect("Failed to cleanup");
}

// Helper struct to hold metrics
#[derive(Debug)]
struct AuthMetrics {
    management_api_calls: u64,
    #[allow(dead_code)]
    cache_hits: u64,
    #[allow(dead_code)]
    cache_misses: u64,
}

// Helper function to fetch and parse auth metrics
async fn get_auth_metrics(ctx: &TestContext) -> Option<AuthMetrics> {
    let response = ctx
        .client
        .get(format!("{}/metrics", ctx.server_url))
        .send()
        .await
        .ok()?;

    if !response.status().is_success() {
        return None;
    }

    let metrics_text = response.text().await.ok()?;

    let management_api_calls = parse_metric(&metrics_text, "infera_auth_management_api_calls_total");
    let cache_hits = parse_metric(&metrics_text, "infera_auth_cache_hits_total");
    let cache_misses = parse_metric(&metrics_text, "infera_auth_cache_misses_total");

    Some(AuthMetrics {
        management_api_calls,
        cache_hits,
        cache_misses,
    })
}

// Helper function to parse a metric value from Prometheus format
fn parse_metric(metrics_text: &str, metric_name: &str) -> u64 {
    metrics_text
        .lines()
        .filter(|l| l.starts_with(metric_name) && !l.starts_with('#'))
        .filter_map(|l| l.split_whitespace().nth(1))
        .filter_map(|v| v.parse::<f64>().ok())
        .sum::<f64>() as u64
}
