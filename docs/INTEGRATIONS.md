# HCG integration adapters

Rules:
* Use only contracts that exist in the sibling repositories.
* Never invent URL schemes, endpoints, devices or metrics.
* Unconfigured integrations show **"Not connected"**.
* HCG Connect and ERP stay the authority for authenticated ecosystem access.
* Nexus stores no HCG credentials.

Sources inspected on 2026-11-12, at the default branches as shallow clones:
`F1r3srp3nt/HCG-Terminal`, `F1r3srp3nt/HCG-Server`, `F1r3srp3nt/HCG-News`,
`F1r3srp3nt/HCG-Executable-Maker`.

## What exists

| Integration | Platform | Contract usable from an iPhone | Nexus behaviour |
|---|---|---|---|
| **HCG Terminal** | SwiftUI iOS app | Bundle IDs `com.hakmicapitalgroup.hcgterminal` and `com.hakmicapitalgroup.hcgterminal.unleashed` (`HCGTerminal.xcodeproj/project.pbxproj`). No URL scheme, no `onOpenURL`, empty entitlements. | "Not connected" until you pick Standard or Unleashed in settings. Then it opens the app, or reports "App not installed". No deep links. |
| **HCG News** | SwiftUI iOS app | Bundle ID `com.hakmicapitalgroup.hcgnews`. Its only URL use is an OAuth callback through `ASWebAuthenticationSession`, which is not a public scheme. The content API is a proposal and not deployed (`docs/HCG-NEWS-CONTENT-API-PROPOSAL.md`). | "Not connected" until switched on in settings. Then it opens the app. No headlines are shown. |
| **HCG Server** | Go agent and macOS app | Admin API on `127.0.0.1:7600`, Mac loopback only. It requires a local admin token and rejects non-loopback `Host` headers. `GET /healthz` exists (`internal/agent/admin.go:493`). The peer API uses mutual TLS with pinned fingerprints. The HCG Connect module is a stub that reports `not-configured` (`internal/hcgconnect/hcgconnect.go:54`). | Not offered in the panel, presets or Settings (since 0.2.0): a phone cannot reach the loopback API, so the row could only say "Not connected". Nexus does not copy or store the admin token. |
| **Executable Maker** | .NET desktop app (Windows, macOS, Linux) | Build status lives only in its local SQLite database. It has no status endpoint and no URL scheme. Its website API (`/api/public/executable-maker/v1`) is documented in the repo but not deployed, and it needs HCG Connect bearer auth. | Not offered (since 0.2.0). Build status is not shown. |

## Code

* `Sources/Core/HCGIntegrations.{h,m}`: catalog and status logic. It is a pure
  function of settings plus an installation probe, and does no networking.
* `Sources/Panel/HCGActionRunner.m`: turns a status into a launch or an
  actionable error.
* Host tests: `testUnconfiguredIntegrationsAreNotConnected` and
  `testConfiguredIntegrations` in `Tests/Host/ModelTests.m`.

## What would unlock more

* **Terminal / News:** a registered URL scheme or universal link with documented
  routes. With that, Nexus could add deep-link actions.
* **Server:** an HCG Connect-authorised status interface a phone can reach,
  for example a relay that exposes the read-only `overview`. Nexus would then
  call it on demand from a background queue, never from SpringBoard lifecycle
  callbacks, using a session issued by HCG Connect.
* **Executable Maker:** a deployed, HCG Connect-authorised build-status endpoint.
