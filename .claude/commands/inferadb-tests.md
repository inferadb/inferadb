# Run Tests and Fix Issues

- Do all our @engine/ tests, formatters and linters pass successfully?
- Do all our @control/ tests, formatters and linters pass successfully?
- Do all our @tests/ end-to-end integration tests pass successfully? These must be run inside our Kubernetes cluster using the @tests/scripts/ files.

If there are any warnings or errors, address the issues directly, even if the issue is "pre-existing". I want all these tests fully functional and passing. These are new products so it's OK to introduce breaking changes — always implement any necessary code changes in the most straightforward way possible following best practices.
