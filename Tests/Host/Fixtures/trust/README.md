# Trust Center test fixtures

* `Release`, `Packages`: the live HCG Repo Candidate index (25 Nov 2026, unsigned).
* `founder-test.asc` (+ `.fpr`): a TEST-ONLY key made like HCG Repo's founder key (RSA 4096 certify-only primary,
  RSA 4096 signing subkey). `Release.gpg` (armored detached, SHA-512) and `InRelease` (clearsigned, SHA-512) are made
  exactly as `hcgrepo sign` makes them; `gpgv` reports both good and both tampered copies BAD.
* `Release.sha256.sig` (binary, SHA-256), `Release.sha1.asc` (SHA-1: must be refused), `Release.other.asc` (another
  key), `Release.expired.asc` (a key that expired in 2021), `Release.ed25519.asc` (EdDSA: not supported here).
* `passport-*.json`, `compat.json`, `monitor.json`: real output of `bin/hcgrepo passport`, `compat --public` and
  `monitor --target production --json` at HCG-repo `3bf53c7`.
No private key exists anywhere in this repository.
