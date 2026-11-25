# Package Trust Center

A read-only verification module in HCG Nexus. Open it from the panel: **Ecosystem › Security › Package Trust Center**.

It shows whether what HCG Repo publishes is authentic, and what is known about each package on real devices. It never
installs, removes or changes a package, an APT source, Sileo or Zebra. It stores two things only:
* the key fingerprints **you** pin (Nexus preferences, `trustedRepositories`);
* its own verified downloads (`Library/Caches/HCGNexus/VerifiedDownloads`, owner-only, files read-only).

## What it checks

```
pinned key ──signs──▶ Release / InRelease ──SHA-256──▶ Packages ──SHA-256 + size──▶ .deb bytes
```

| Check | Code | Evidence |
|---|---|---|
| Key inspection: fingerprint, user IDs, primary and subkeys, expiry, revocation, binding and back-signatures | `HCGOpenPGP` (`HCGPGPCertificate`) | host tests with a TEST-ONLY key made like HCG Repo's founder key (RSA 4096 certify-only primary, RSA 4096 signing subkey) |
| Repository signature: `Release.gpg` (detached) and `InRelease` (cleartext); SHA-256/512 only; SHA-1 refused; nothing accepted outside the signed message | `HCGOpenPGP` | GnuPG 2.4 signatures; `gpgv` agrees on every fixture (good, tampered, other key, expired, SHA-1, Ed25519) |
| Index consistency: `Packages` against `Release`'s SHA-256 and size; `InRelease` must carry exactly `Release`; `Valid-Until` | `HCGRepoTrust` | the live Candidate index (25 Nov 2026) |
| Downloaded `.deb`: SHA-256 and size against the index; kept named by its SHA-256, read-only; re-hashed before any hand-off | `HCGVerifiedArtifact`, `HCGTrustFetcher` | host tests, including a file changed after verification |
| Package metadata: every field of the index entry | `HCGRepoTrust +stanzasFromText:` | live index |
| Release Passport (`hcg.release-passport` v1) | `HCGReleasePassport` | real `bin/hcgrepo passport` output |
| Device evidence (`hcg.repo.compatibility` v1) and the package's `firmware` requirement against this iOS | `HCGCompatibilityRegistry`, `+firmwareProblemInDepends:` | real `bin/hcgrepo compat --public` output |
| Declared entitlements (passport) and actual entitlements (installed HCG apps' Mach-O code signatures) | `HCGEntitlements` | synthetic thin and universal Mach-O files |
| Installed packages: dpkg status; each HCG package matched to an exact index entry | `HCGEcosystemScanner +trustEnvironment` | — (device) |
| Security warnings: unsigned or untrusted repositories, key changes, expiry, mismatches, `trusted=yes` APT sources, unknown-origin installs, Known-incompatible installs, high-risk entitlements, Zebra not checking signatures | `HCGTrustCenterViewController` | — |
| HCG Sentinel: Nexus runs the public checks of `hcg.repo.monitor` v1 itself (availability, index, signature) and can read Sentinel's reports in that format | `HCGMonitorReport` | real `bin/hcgrepo monitor --json` output |

## Two answers per package, never "safe"

**Authenticity** asks who published these bytes. It is one of:
* **Verified:** a good signature by the key you pinned, an unexpired Release, a consistent index, and (for a download)
  a matching SHA-256 and size;
* **Unsigned:** the repository publishes no signature;
* **Untrusted:** signed, but not by a key you pinned, or with a weak or unsupported signature;
* **Expired:** the key, the signature or the Release validity has run out;
* **Invalid:** a BAD signature, `InRelease` that differs from `Release`, or a checksum mismatch.

**Device evidence** asks whether this version worked on a real iPhone. It is one of: launch passed, install passed,
untested, incompatible (a recorded failure, or this iOS is outside its `firmware` range), withdrawn, or no data.

A matching checksum on an unsigned repository proves only that the file is the one the index names, not who
published it. Verified proves origin and integrity; it is not a safety review. The interface says both, in those words.

## Trust is yours

* No key is trusted by default. *Trust This Key…* shows the full fingerprint and asks you to compare it with the
  fingerprint HCG publishes before it pins it. Removing trust is one tap with a confirmation.
* Pinning is by **primary** fingerprint. When HCG Repo rotates its signing subkey under the same primary key, nothing
  changes for you. A different primary key is reported as *Untrusted* with a warning until you pin it.
* If HCG Repo Keyring (`<jbroot>/etc/apt/trusted.gpg.d/hcg-repo.gpg`) is installed, its key is shown and can be
  pinned the same way.

## Reading, and future installation

* Fetching uses HTTPS only, an ephemeral session (no cookies, credentials or cache), no redirects, and size limits
  (8 MB metadata, 64 MB packages). A 404 means "not published", which is not an error.
* Installation is **not** implemented. A future installer integration must:
  1. take an `HCGVerifiedArtifact`;
  2. call `-stillMatches:` immediately before handing over its path, which is the read-only file named by its SHA-256;
  3. ask you explicitly;
  4. never re-download.

  The bytes verified are then the bytes installed.

## HCG Repo today (25 Nov 2026)

Unsigned. No production key exists (HCG-repo `docs/SIGNING.md`), and `InRelease`, `Release.gpg`,
`hcg-repo-archive-key.asc`, `compatibility.json` and passports are all 404. So the Trust Center shows:
* **Unsigned** for both channels, with a consistent index;
* *No device data* for every package;
* *Release Passport not published*.

When the founder key and the public compatibility API go live, the same code verifies them with no Nexus update.
The verifier is proven against the founder-key format with test keys.

## Coordination (what each product would add; nothing here changes them)

| Product | Ask | Why |
|---|---|---|
| **HCG Repo** | Publish passports at `<channel>/passports/<package>_<version>.json`, the location Nexus already tries. Keep `compatibility.json` at the site root. Announce the fingerprint in `docs/SIGNING.md` and on the website. | Passports are derived and not published today; Nexus shows "not published". |
| **HCG Sentinel** | Publish its `hcg.repo.monitor` v1 results where Nexus can read them (for example `<site>/monitor/latest.json`, or a Sentinel app export). Same format; read-only. | Nexus runs the public checks itself until then. |
| **HCG Terminal Unleashed** | Accept an `HCGVerifiedArtifact` path for a future approved install, re-check its SHA-256 before `dpkg -i`, and run nothing without the user's approval in Terminal. | One installer path, same bytes, user-approved. |
| **HCG Executable Maker** | Fill the build half of the passport (`submission.json`: toolchain, `built_at`, entitlements per binary). | Declared entitlements can then be compared with the installed app's actual ones. |

## Not verified yet

* Phone testing is pending (`DEVICE-CHECKLIST.md` rows 32–37).
* RSA verification is portable C. It is host-tested against GnuPG, and it is the same code that runs on the iPhone.
  It has not been cross-checked against Apple's Security framework on a device.
