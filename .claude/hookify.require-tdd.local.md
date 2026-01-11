---
name: require-tdd
enabled: true
event: stop
pattern: .*
action: block
---

🧪 **TDD Verification Required**

Before stopping, verify Test-Driven Development principles were followed:

## TDD Process Check

### 1. Tests Written First (Red)
- [ ] Tests were written BEFORE the implementation
- [ ] Tests initially failed (proving they test something real)
- [ ] Test cases cover the expected behavior

### 2. Implementation Made Tests Pass (Green)
- [ ] Minimal code was written to make tests pass
- [ ] All tests are now passing

### 3. Refactored (Refactor)
- [ ] Code was cleaned up while keeping tests green
- [ ] No duplication, clear naming, proper structure

## Coverage Target: 90%+

- [ ] New code has corresponding test coverage
- [ ] Edge cases and error paths are tested
- [ ] Run coverage report to verify:
  - **Go**: `go test -cover ./...` or `go test -coverprofile=coverage.out ./...`
  - **Jest/Vitest**: `npm test -- --coverage` or `vitest --coverage`
  - **Cargo**: `cargo tarpaulin` or `cargo llvm-cov`

## Test Quality Checklist

- [ ] Tests are meaningful (not just "it exists")
- [ ] Tests verify behavior, not implementation details
- [ ] Tests are isolated and don't depend on each other
- [ ] Test names clearly describe what they test
- [ ] Both happy path and error cases are covered

---

If TDD was followed and coverage target is met, you may proceed. Otherwise, write the missing tests first.
