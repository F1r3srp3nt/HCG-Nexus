# Connected Devices (HCG Device Link)

**Standalone app only.** The sandboxed HCG Nexus app (`HCGNexus.xcodeproj`) can pair with an HCG Server you own, show
your other paired HCG devices (HCG Sentinel, HCG Terminal Vanilla/Unleashed) and read the reports they share with it.
The jailbreak package, the Settings bundle and the preview harness contain none of this and never contact HCG Server.

The protocol is HCG Device Link (`hcg.devicelink/1`), specified in HCG-Server `docs/DEVICE-LINK.md`. The client is
`HCGDeviceLink/`, vendored unchanged from HCG-Server (`HCGDeviceLink/VENDORED.md`). CI checks it with
`cd HCGDeviceLink && shasum -a 256 -c VENDORED.sha256`. Never edit it here: change HCG-Server and run its
`scripts/vendor-devicelink.sh <path to HCGDeviceLink>` again.

## Who decides what

| Question | Decided by |
|---|---|
| Who you are | **HCG Connect**: your own sign-in, verified by HCG Server on every request |
| What your account may do | **ERP App Access**, which HCG Server checks through HCG's Ecosystem API |
| Whether this iPhone/iPad is trusted | **The server's owner**, who approves it after comparing its key fingerprint |
| Whether Nexus contacts a server at all | **You**. Nothing is contacted until you sign in or pair, and only while Connected Devices is open |

Nexus advertises two capabilities, `report.receive` and `report.view`, both `available`. They are information for
other devices. They never grant anything. Nexus does not send reports or request actions. It never runs anything
another device sends.

## Using it

1. Open the app's **Settings › Connected devices › Connected Devices**.
2. Under **HCG Connect account**, choose **Sign in with HCG Connect**. This needs an HCG Connect client issued for HCG
   Nexus; see "Not configured yet" below.
3. On the computer running HCG Server, create an invitation. Network exposure must allow the local network.
4. In Nexus, tap **Enter invitation code…** and paste the `hcg1-…` code. Nexus parses it on the device and shows the
   following before anything is sent:
   - the server's name and address;
   - the server's key fingerprint, which is pinned for TLS;
   - this device's key fingerprint.

   Then tap **Request pairing**.
5. While the request is waiting, Nexus shows **Awaiting approval** with this device's key. It also shows the key the
   server says it received. The owner compares the fingerprint on the server and approves the device, or rejects it
   when the fingerprints differ.
6. Once the device is approved, the screen shows:
   - **Paired devices**: each one is labelled **REMOTE**, or **LOCAL** for this device, with its app, variant,
     online/offline state or last seen time, and capabilities;
   - **Shared reports**: the inbox, with title, sending device and time received;
   - **Pending approvals**: always empty, with the server's note. Action execution is disabled.
7. Tap a shared report to open it. Its header reads *Report from <device> (remote) — data only, never executed*.
8. **Disconnect and remove this device** tells the server (the request is signed with the device key). Nexus then
   forgets the pairing and deletes the key. **Forget pairing on this device only** does the same without telling the
   server. If the owner revokes the device on the server, Nexus shows **Removed by the server** and creates a new key
   for the next pairing.

## Sync (foreground only)

Nexus syncs only while the Connected Devices screen is visible and the app is active. Leaving the screen, opening a
report or sending the app to the background stops it.

- While a pairing request is waiting, Nexus polls the request every 3 s.
- Once the device is approved, Nexus sends a heartbeat every 20 s, which also refreshes paired devices and approvals.
  It reads the inbox every 10 s. New messages are acknowledged as `received`, and as `opened` once you open them.
- When a request fails and can be retried, Nexus waits 1, 2, 4 … up to 60 s, with ±20 % jitter (`ReconnectPolicy`).
  It honours `retryAfterSeconds`.
- When the link ends, Nexus stops and shows why. It never retries automatically. The link ends on revoked, unknown
  installation, wrong account, app mismatch, untrusted client, key-pin mismatch, access revoked or HCG session ended.
- An error that concerns only one section is shown on that section, and the rest keeps working. ERP denying one
  operation is an example.

There is no background connection and no push channel.

## Security rules in the code

- **Identity.** `InstallationIdentity` provides a random installation ID and a P-256 key. The key is held in the
  Secure Enclave when the device has one, otherwise in the Keychain. Keychain items are stored this-device-only,
  available after first unlock, under service `com.hakmicapitalgroup.hcgnexus.app.devicelink`. The HCG Connect tokens
  are kept there too. The pairing record (server name, address and key fingerprint; no secret) is in Application
  Support, `DeviceLink/pairing.json`.
- **Transport.** TLS 1.3 through `URLSession` with `PinnedSessionTransport`. The server's key (the SHA-256 of its SPKI)
  comes from the invitation, and any other key is refused before a request is sent. Every request is signed with the
  installation key and carries the HCG Connect token. No cryptography is implemented by hand: the code uses CryptoKit,
  Security and URLSession.
- **Reports are data.** `ReportTextRenderer.sections` turns a report into labelled plain-text lines. The viewer shows
  them in `UILabel`s:
  - it shows no text view, no data detectors and no attributed links;
  - it does not interpret Markdown or HTML;
  - selection is disabled, and nothing is opened, copied into a command or executed.
- **No privileged anything.** Nothing in a response can change what Nexus advertises or enable a local feature.
- **Encryption export.** The app only uses Apple's standard TLS and CryptoKit (signing and hashing), which keeps
  `ITSAppUsesNonExemptEncryption = false` in `App/Info.plist` valid.
- **Local network.** `NSLocalNetworkUsageDescription` and `NSAllowsLocalNetworking` (ATS) are set because HCG Server
  is reached on the local network. This is the same as HCG Sentinel.

## Not configured yet (nothing invented)

- **HCG Connect client.** In `App/Info.plist`, `HCGConnectClientID` and `HCGConnectRedirectURI` are **empty**: HCG has
  not issued an HCG Connect client for HCG Nexus. Until it does, the account section shows **Not configured**, sign-in
  and pairing are refused locally, and nothing is contacted. Once HCG issues the client, fill both keys. The redirect
  URI's scheme is used as the `ASWebAuthenticationSession` callback scheme. No URL type needs registering.
- **ERP App Access.** The product and feature keys for the Device Link permissions are configured on HCG Server
  (`hcg-connect.json`). HCG Server must also list Nexus's client ID as a trusted client for `hcg.nexus`. None of this
  is assumed here.

## Where the code is

| Part | Path |
|---|---|
| Vendored client (Swift package, unmodified) | `HCGDeviceLink/` |
| Swift facade `HCGLinkService` (`@objc`, main actor) | `Sources/Platform/App/DeviceLink/HCGDeviceLinkService.swift` |
| Objective-C value types, the `HCGLinkServicing` protocol and `HCGSharedLinkService()` | `Sources/Platform/App/DeviceLink/HCGLinkTypes.{h,m}` |
| Swift bridging header | `Sources/Platform/App/DeviceLink/HCGNexus-Bridging-Header.h` |
| Connected Devices screen and report viewer | `Sources/Platform/App/DeviceLink/HCGConnectedDevicesViewController.{h,m}`, `HCGLinkReportViewController.{h,m}` |
| Entry point | Settings, *Connected devices* section (standalone mode only), through `HCGPanelContext.connectedDevicesScreen`, which `App/HCGAppRootViewController.m` sets |

The Objective-C screens reach the Swift class only through `HCGLinkTypes.h` and `NSClassFromString(@"HCGLinkService")`.
They therefore compile without the generated `HCGNexus-Swift.h`, and `scripts/compile-app-target.sh` (Objective-C only)
keeps working. The Swift class conforms to `HCGLinkServicing` through the bridging header, so Xcode checks every
signature.

`scripts/generate_xcodeproj.py` adds the following to the **app target only**:

- an `XCLocalSwiftPackageReference` to `HCGDeviceLink` and its product;
- the Swift sources from `Sources/Platform/App/DeviceLink`;
- `SWIFT_VERSION = 5.0`, the bridging header and `SWIFT_OBJC_INTERFACE_HEADER_NAME = HCGNexus-Swift.h`.

The project format is now `objectVersion 60` (Xcode 15 or later), which local package references need.

The following checks keep it that way:

- `scripts/check_app_target.py`: Swift appears only in that folder, and the package is linked into the app target only;
- `scripts/check.sh`:
  - the vendored copy is unmodified;
  - no Device Link names appear in Core, Panel, SpringBoard, Preview, Tweak, Prefs or the preview harness;
  - no Theos Makefile mentions Device Link or Swift;
- `scripts/inspect-app.py`: the built app contains the client and the Info.plist keys.

## What was verified, and how

| Kind | What | Result |
|---|---|---|
| Unit (Linux) | Vendored client: signing, canonical vectors, HCG Connect PKCE/state/nonce, redaction, plain-text renderer, retries | `swift test --package-path HCGDeviceLink`: 17 tests, 0 failures (Swift 6.0.3, Linux) |
| Type-check (Linux) | `HCGDeviceLinkService.swift` against the real client, with hand-written stand-ins for UIKit, AuthenticationServices and the imported Objective-C header | Compiles with no warnings, also with `-strict-concurrency=complete` |
| Syntax (Linux) | All app Objective-C sources, `-Wall -Werror`, ARC, against the iPhoneOS 16.5 SDK headers (clang 18 `-fsyntax-only`). The tweak's Core/Panel/SpringBoard sources were also checked with the tweak's flags | No diagnostics |
| Repository checks | `scripts/check.sh`, including the Core host tests (GNUstep) | All checks passed |
| Real server, mock identity | The same client against a real HCG Server over pinned TLS | HCG-Server CI (`swift-client-macos`), not repeated here |
| **Not verified** | Xcode build of the app with Swift and the local package, the XCTests (`Tests/App`), simulator launch, a real device | Needs the manual *Build package* workflow (`app` job) on macOS |
