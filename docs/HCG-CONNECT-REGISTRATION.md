# HCG login (HCG Connect) — readiness and the registration HCG Nexus needs

Status on 18 Nov 2026: **ready to test once HCG issues a client. Not configured today; sign-in stays off.**

## What exists

| | |
|---|---|
| Identity provider | Central HCG identity (HCG Connect / main site), Supabase managed OAuth. Issuer `https://qggdyzoydveafkmjgkpq.supabase.co/auth/v1`, discovery at `{issuer}/.well-known/openid-configuration` |
| Account APIs | `GET https://beta.hakmicapitalgroup.com/api/public/ecosystem/v1/me` (user + organisations); `GET /features`, `POST /check` (per-feature permission: only HTTP 200 with `allowed: true` grants) |
| Native flow | Authorization code + **PKCE S256 only**, public client (no secret), fresh `state` and `nonce`, system browser (`ASWebAuthenticationSession`), exact-match redirect |
| Scopes | `openid email profile` only (no product scopes, no `offline_access`) |
| Tokens | Keychain only; never in URLs, preferences, logs or SpringBoard. Refresh tokens rotate (single refresh at a time). No global sign-out: signing out ends this app's session |
| Nexus client | **None issued.** The main-site records list HCG Nexus as blocked on owner decision D-S1; the registry has no `hcg.nexus` product yet |

Sources: the main-site repository's auth contract and native-login handoffs, HCG-Executable-Maker
`docs/hcg-connect/HANDOFF.md`, HCG-Server `internal/hcgconnect`, HCG Store integration notes (research of 18 Nov 2026).

## How Nexus uses it (implemented)

- **Only the standalone app signs in.** It reuses HCG Device Link's HCG Connect client code
  (`HCGDeviceLink/…/HCGConnect.swift`: PKCE S256, constant-time state check, nonce, `aud`/`iss` check,
  serialized refresh, Keychain `AfterFirstUnlockThisDeviceOnly`). One Nexus client serves the whole app.
- **Not configured until HCG issues the client.** `App/Info.plist` keeps `HCGConnectClientID` and
  `HCGConnectRedirectURI` empty. Account and Connected Devices therefore show *Not configured*, nothing
  is contacted, and the Device Link service is not even constructed for the Account screen.
- **No borrowed client.** `HCGAccountConfiguration` (Core, host-tested) refuses clients issued to other HCG
  products (Store dev/prod, Executable Maker, HCG AI iOS/web, LifeOS, CardX), a client ID that is not a UUID,
  and any redirect that is not the app's own scheme or that carries a query or fragment. The Swift Device Link
  service applies the same guard.
- **Three separate states** on the Account screen: owning Nexus (candidate demos need none), being signed in,
  and permission for connected services (checked per feature by HCG; errors and offline deny,
  `HCGAccountRules isPermissionGranted…`, host-tested).
- **The tweak never signs in.** The jailbreak package and Settings bundle say *Sign-in is in the standalone app*.
  The only account data allowed across the boundary is `HCGAccountSummary` (state, display name, organisation,
  timestamp), which rejects anything that looks like a credential (host-tested). No shared channel is enabled
  yet: it needs an app-group container that the tweak can read, which is not provisioned. No token is ever
  forwarded to a deep link.

## Token verification (implemented, 0.3.1~beta1)

The vendored HCG Device Link client binds a sign-in by *decoding* the ID token and reads the account from the
access token without checking signatures. Nexus does not rely on that: `HCGVerifiedConnectTransport` (app) wraps
the client's network transport and verifies every successful token-endpoint response before the client reads it,
with `HCGConnectVerify` (a Nexus-owned Swift package, compiled into the app). The rules are HCG-Server's
(`internal/hcgconnect/verifier.go`):

| Check | Rule |
|---|---|
| Algorithm | ES256 only (`none`, HS*, RS*, ES384 refused before any key lookup) |
| Signing keys | Only from `{issuer}/.well-known/jwks.json` on the issuer's host (https); EC P-256, `use` sig, `alg` ES256; off-curve points refused; cached 10 min; an unknown `kid` re-fetches once; unreachable keys fail closed |
| Issuer | exactly `https://qggdyzoydveafkmjgkpq.supabase.co/auth/v1` (the configured issuer) |
| Times | `exp` required; `exp`, `nbf`, `iat` with 60 s leeway |
| Subject | a UUID; the ID token and access token must name the same account |
| ID token | `aud` contains Nexus's client; `azp` = client when present or when there are several audiences; `nonce` = this sign-in's nonce (refresh: the original nonce when present) |
| Access token | `aud` contains `authenticated`, `role` = `authenticated`, `client_id` = Nexus's client |
| Sign-in response | must contain both tokens |

A failure becomes the client's "response did not match" error: nothing is stored. Without an issued client there
is no trust anchor and every token response is refused; the Account screen stays *Not configured*.
Tests: `HCGConnectVerify/Tests` (`swift test`, in CI on Linux with swift-crypto and on macOS with CryptoKit) cover
each rejection above with real signatures.

## Local development pairing is separate

HCG Server's local development pairing (owner approval only, no HCG account; `docs/CONNECTED_DEVICES.md`) does not
use or need this registration and changes nothing here: Nexus sends no HCG token on that path and labels it
**LOCAL DEVELOPMENT — not an HCG account**. The HCG Connect flow stays exactly as below until HCG issues the client.

## Not done yet (needs the client first)

1. A real device sign-in (status `configured_untested` → tested), as required by the main-site team.
2. Loading the organisation context from `/me` after sign-in. The Account screen says *Not loaded* until then;
   it never shows an invented organisation.
3. Checking token verification against real HCG Connect tokens. The code and its rejection tests exist
   (below); it has only been tested with locally generated ES256 keys, because no Nexus client exists yet.

## Registration request (send to the HCG main-site team)

Account › *Copy Registration Request* copies this exact text (`HCGAccountRules registrationRequestText`):

```
HCG Connect client request — HCG Nexus (iOS)
Product: HCG Nexus
Integration key: hcg.nexus
Platform: iOS (standalone iPhone/iPad app, bundle com.hakmicapitalgroup.hcgnexus.app)
Environment: production (a separate development client only if HCG requires one)
Consent name: HCG Nexus
Client type: public, token_endpoint_auth_method none (no secret)
Grants: authorization_code, refresh_token
PKCE: S256 only
Scopes: openid email profile
Access token audience: authenticated
Redirect URI (exact): com.hakmicapitalgroup.hcgnexus.app://auth/callback
Allowed origins: none
Logout URLs: none
Status: configured_untested until a device sign-in passes
Please send back the client ID only.
```

When the client ID arrives:
1. Put it in `App/Info.plist` (`HCGConnectClientID`) together with the exact redirect URI.
2. Register the `com.hakmicapitalgroup.hcgnexus.app` URL scheme in `App/Info.plist`.
3. Run a device sign-in.

The redirect URI is the candidate the main-site documents propose. It needs the founder's D-S1 decision.
