import AuthenticationServices
import Foundation
import HCGDeviceLink
import UIKit

/// HCG Device Link (`hcg.devicelink/1`) for the standalone HCG Nexus app.
///
/// A thin facade over the vendored HCGDeviceLink client for the Objective-C
/// Connected Devices screen (protocol `HCGLinkServicing` in HCGLinkTypes.h).
/// Nexus signs in with HCG Connect, pairs this installation with an HCG Server
/// using an `hcg1-…` invitation, lists the other paired devices and reads the
/// reports they share. It advertises only `report.receive` and `report.view`.
/// When HCG Server hosts services (HCG Server as a development host), Nexus
/// shows the host, the services and their health, opens a published service
/// in the system browser with a single-use ticket, and shows the server's
/// read-only diagnostics.
///
/// Two authorities, never mixed:
/// - HCG Connect (production): every request carries the HCG Connect token.
/// - Local development (only when the invitation says `am=local-development`,
///   remembered in the pairing record): owner approval only, no HCG account,
///   no token is ever sent (`LocalDevelopmentTokens`), this one server only.
///   Shown everywhere as "LOCAL DEVELOPMENT — not an HCG account".
///
/// Rules (HCG-Server docs/DEVICE-LINK.md, docs/CONNECTED_DEVICES.md):
/// - Every request is signed with the installation key and carries the HCG
///   Connect token; HCG Server authorizes it with ERP App Access. Nothing here
///   decides access.
/// - Nothing is contacted until the person acts, and sync runs only while the
///   Connected Devices screen is visible (heartbeat 20 s, inbox 10 s, back-off
///   on failures, stop on anything that ends the link).
/// - Reports are data: they are returned as plain-text sections only.
/// - Action execution is disabled; Nexus never runs anything another device sends.
@MainActor
@objc(HCGLinkService)
final class HCGLinkService: NSObject, HCGLinkServicing {
    static let contract = "hcg.nexus.connect/1"
    static let appIdentifier = "hcg.nexus"
    static let keychainService = "com.hakmicapitalgroup.hcgnexus.app.devicelink"

    /// What Nexus tells HCG Server about itself. Information only, never authorization:
    /// Nexus receives and shows reports, and nothing else.
    static let capabilities: [LinkCapability] = [
        LinkCapability(id: LinkCapabilityID.reportReceive, state: .available),
        LinkCapability(id: LinkCapabilityID.reportView, state: .available),
    ]

    private static var instance: HCGLinkService?

    static func sharedLinkService() -> HCGLinkServicing {
        if let existing = instance { return existing }
        let created = HCGLinkService(bundle: .main)
        instance = created
        return created
    }

    /// The service only if something already created it: the Ecosystem dashboard reads the
    /// real connection state without creating a device key.
    static func existingLinkService() -> HCGLinkServicing? { instance }

    // MARK: state

    private enum Account {
        case notConfigured(String)
        case signedOut
        case signedIn(email: String?)
        case ended(String)
    }

    private enum Link {
        case notPaired
        case pairing
        /// Approved, but nothing answered since the app started: never shown as connected.
        case paired
        /// The last request succeeded.
        case connected
        case offline(reason: String, retryIn: TimeInterval)
        case paused(String)
        case ended(String)
        case removed(String)
        /// The server switched authority mode (`authority_changed`); the pairing was forgotten.
        case authorityChanged(String)
    }

    private enum Part: Hashable { case devices, inbox, approvals, services }

    private(set) var snapshot = HCGLinkSnapshot()
    var changeHandler: (() -> Void)?

    private let secrets: LinkSecretStore
    private let recordFile: PairingRecordFile
    private let auth: HCGConnectAuth
    private let connectTransport: HCGVerifiedConnectTransport
    private let session: HCGConnectSession
    private var account: Account
    private var link: Link = .notPaired
    private var record: PairingRecord?
    private var identity: InstallationIdentity?
    private var identityProblem: String?
    private var serverRecordedKey: String?
    private var devices: LinkDevices?
    private var inbox: [LinkMessageHeader] = []
    private var approvals: LinkApprovals?
    private var hostSummary: LinkHostSummary?
    private var hostedServices: [LinkHostedService] = []
    private var servicesLoaded = false
    private var problems: [Part: String] = [:]
    private var lastSync: Date?
    private var notice: String?
    private var busy = false
    private var client: DeviceLinkClient?
    private var syncTask: Task<Void, Never>?
    private var generation = 0
    private var visible = false
    private var webSession: ASWebAuthenticationSession?
    private var anchor: HCGLinkPresentationAnchor?

    private static let keyMismatch = "HCG Server recorded a different key for this device than the one shown here. Ask the server's owner to reject the request, then pair again with a new invitation."

    private init(bundle: Bundle) {
        let store = KeychainSecretStore(service: HCGLinkService.keychainService)
        secrets = store
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        recordFile = PairingRecordFile(url: support.appendingPathComponent("DeviceLink/pairing.json"))
        // HCG has not issued Nexus's HCG Connect client yet: both keys are empty in Info.plist,
        // so sign-in is "not configured" and nothing is contacted. No value is invented here.
        let configuration = HCGConnectConfiguration(contractVersion: HCGLinkService.contract,
                                                    clientId: HCGLinkService.infoString(bundle, "HCGConnectClientID"),
                                                    redirectUri: HCGLinkService.infoString(bundle, "HCGConnectRedirectURI"))
        // Every token response is verified (signature against HCG Connect's JWKS, issuer, audience,
        // client, expiry, nonce) before the vendored client reads it: HCGVerifiedConnectTransport.
        let transport = HCGVerifiedConnectTransport(configuration: configuration)
        connectTransport = transport
        let connectAuth = HCGConnectAuth(configuration: configuration, expectedContract: HCGLinkService.contract,
                                         send: { request in try await transport.send(request) })
        auth = connectAuth
        session = HCGConnectSession(auth: connectAuth, store: SecretTokenStore(store: store))
        // Shared guard (Sources/Core/HCGAccount): Nexus's own client only, never another
        // HCG product's (Store, Executable Maker, HCG AI, ...), with the app's own redirect scheme.
        let guardrail = HCGAccountConfiguration(clientID: HCGLinkService.infoString(bundle, "HCGConnectClientID"),
                                                redirectURI: HCGLinkService.infoString(bundle, "HCGConnectRedirectURI"))
        if let problem = configuration.problem(expectedContract: HCGLinkService.contract) {
            account = .notConfigured(problem)
        } else if let problem = guardrail.problem {
            account = .notConfigured(problem)
        } else if !transport.isVerifying {
            // No trust anchor (issuer/JWKS) for the issued client: never sign in on unverified tokens.
            account = .notConfigured("HCG Connect tokens cannot be verified with this configuration, so sign-in stays off.")
        } else {
            account = .signedOut
        }
        super.init()
        loadIdentity()
        record = recordFile.load()
        link = HCGLinkService.link(for: record)
        rebuildClient()
        publish()
        Task { [weak self] in await self?.refreshAccount() }
    }

    nonisolated private static func infoString(_ bundle: Bundle, _ key: String) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated private static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    private func loadIdentity() {
        do {
            identity = try InstallationIdentity.loadOrCreate(store: secrets)
            identityProblem = nil
        } catch {
            identity = nil
            identityProblem = "This device's key could not be created or read from the Keychain (\(error.localizedDescription))."
        }
    }

    nonisolated private static func link(for record: PairingRecord?) -> Link {
        switch record?.status {
        case .pending?: return .pairing
        case .approved?: return .paired
        case .rejected?: return .ended("The server owner rejected this pairing request. Ask for a new invitation to try again.")
        case .expired?: return .ended("The pairing request expired before it was approved. Use a new invitation.")
        case .removed?: return .removed("This device was removed from the server.")
        case nil: return .notPaired
        }
    }

    nonisolated private static func recordStatus(_ status: String) -> PairingRecord.Status {
        switch status {
        case "approved": return .approved
        case "pending": return .pending
        case "rejected": return .rejected
        default: return .expired
        }
    }

    private var pairingActive: Bool {
        record?.status == .pending || record?.status == .approved
    }

    private var linkStopped: Bool {
        switch link {
        case .ended, .removed, .paused, .authorityChanged: return true
        default: return false
        }
    }

    /// The token provider follows the invitation / pairing record, never a setting: local
    /// development pairing sends no HCG token at all; everything else uses HCG Connect.
    private func makeClient(base: URL, fingerprint: String, identity id: InstallationIdentity, localDevelopment: Bool) -> DeviceLinkClient {
        let tokens: AccessTokenProvider = localDevelopment ? LocalDevelopmentTokens() : session
        return DeviceLinkClient(configuration: DeviceLinkConfiguration(baseURL: base, serverFingerprint: fingerprint, installationId: id.installationId),
                                signer: id.signer, transport: PinnedSessionTransport(fingerprint: fingerprint), tokens: tokens)
    }

    private func rebuildClient() {
        guard let r = record, pairingActive, let base = r.baseURL, let id = identity else {
            client = nil
            return
        }
        client = makeClient(base: base, fingerprint: r.serverFingerprint, identity: id, localDevelopment: r.isLocalDevelopment)
    }

    private var isLocalDevelopment: Bool { record?.isLocalDevelopment ?? false }

    private func saveRecord(_ r: PairingRecord?) {
        record = r
        do { try recordFile.save(r) } catch {
            notice = "The pairing could not be saved on this device (\(error.localizedDescription))."
        }
        rebuildClient()
    }

    nonisolated private static func describe(_ error: Error) -> String {
        if let e = error as? DeviceLinkError { return e.description }
        if let e = error as? HCGConnectError { return e.description }
        if let e = error as? Invitation.Problem { return e.description }
        return error.localizedDescription
    }

    // MARK: snapshot

    nonisolated private static func capabilityInfo(_ c: LinkCapability) -> HCGLinkCapabilityInfo {
        let info = HCGLinkCapabilityInfo()
        info.identifier = c.id
        info.state = c.state.rawValue
        info.usable = c.state.isUsable
        info.reason = c.reason
        return info
    }

    nonisolated private static func deviceInfo(_ d: LinkInstallation, isSelf: Bool) -> HCGLinkDeviceInfo {
        let info = HCGLinkDeviceInfo()
        info.installationId = d.installationId
        info.name = d.name
        info.appName = HCGLinkAppDisplayName(d.app)
        info.appVersion = d.appVersion
        info.variant = d.variant.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        info.platform = d.platform
        switch d.state {
        case .online: info.presence = "Online"
        case .offline: info.presence = "Offline"
        case .neverSeen: info.presence = "Never seen"
        case .revoked: info.presence = "Revoked"
        }
        info.online = d.state == .online
        info.lastSeen = d.lastSeenAt
        info.isThisDevice = isSelf
        info.keyFingerprint = LinkCrypto.displayFingerprint(d.keyFingerprint)
        info.capabilities = d.capabilities.map(capabilityInfo)
        return info
    }

    nonisolated private static func inboxItem(_ h: LinkMessageHeader) -> HCGLinkInboxItem {
        let item = HCGLinkInboxItem()
        item.messageId = h.messageId
        item.title = h.title
        item.fromName = h.from.name
        item.fromApp = HCGLinkAppDisplayName(h.from.app)
        item.receivedAt = h.deliveredAt ?? h.queuedAt
        item.expiresAt = h.expiresAt
        item.status = h.status
        return item
    }

    nonisolated private static func hostInfo(_ h: LinkHostSummary) -> HCGLinkHostInfo {
        let info = HCGLinkHostInfo()
        info.name = h.name
        info.platform = h.platform
        info.osVersion = h.osVersion
        info.architecture = h.architecture
        info.cpuModel = h.cpuModel
        info.logicalCpus = h.logicalCpus
        info.memoryTotalBytes = h.memoryTotalBytes.map { NSNumber(value: $0) }
        info.memoryAvailableBytes = h.memoryAvailableBytes.map { NSNumber(value: $0) }
        info.loadAverage = (h.loadAverage ?? []).map { NSNumber(value: $0) }
        info.agentVersion = h.agentVersion
        info.agentStartedAt = h.agentStartedAt
        info.gatewayExposure = h.gatewayExposure
        info.sampledAt = h.sampledAt
        return info
    }

    nonisolated private static func serviceInfo(_ v: LinkHostedService) -> HCGLinkHostedServiceInfo {
        let info = HCGLinkHostedServiceInfo()
        info.identifier = v.id
        info.name = v.name.isEmpty ? v.id : v.name
        info.version = v.version
        info.runtime = v.runtime
        info.status = v.status
        info.health = v.health
        info.detail = v.detail
        info.uptimeSeconds = v.uptimeSeconds.map { NSNumber(value: $0) }
        info.restarts = v.restarts
        info.lastHealthAt = v.lastHealthAt
        info.capabilities = v.capabilities
        info.gatewayPublished = v.gatewayPublished
        info.openable = v.openable
        return info
    }

    /// SHA-256 in pairs, as iOS shows it in Certificate Trust Settings and HCG Server prints it.
    nonisolated static func pairedHex(_ hex: String) -> String {
        let up = Array(hex.uppercased())
        return stride(from: 0, to: up.count, by: 2).map { String(up[$0..<min($0 + 2, up.count)]) }.joined(separator: " ")
    }

    private func publish() {
        let s = HCGLinkSnapshot()
        switch account {
        case .notConfigured(let why):
            s.accountState = .notConfigured
            s.accountDetail = why
        case .signedOut:
            s.accountState = .signedOut
        case .signedIn(let email):
            s.accountState = .signedIn
            s.accountEmail = email
        case .ended(let why):
            s.accountState = .ended
            s.accountDetail = why
        }
        s.deviceName = UIDevice.current.name
        s.appVersion = HCGLinkService.appVersion
        s.identityProblem = identityProblem
        if let id = identity {
            s.installationShortId = String(id.installationId.prefix(8))
            s.keyFingerprint = LinkCrypto.displayFingerprint(id.fingerprint)
            s.keyStorage = id.keyKind == "secure-enclave" ? "Secure Enclave" : "Keychain (software key, this device only)"
        }
        s.advertisedCapabilities = HCGLinkService.capabilities.map(HCGLinkService.capabilityInfo)
        switch link {
        case .notPaired:
            s.connectionState = .notPaired
        case .pairing:
            s.connectionState = .awaitingApproval
        case .paired:
            s.connectionState = .paired
        case .connected:
            s.connectionState = .connected
        case .offline(let reason, let retryIn):
            s.connectionState = .offline
            s.connectionDetail = reason
            s.retryInSeconds = retryIn
        case .paused(let why):
            s.connectionState = .paused
            s.connectionDetail = why
        case .ended(let why):
            s.connectionState = .ended
            s.connectionDetail = why
        case .removed(let why):
            s.connectionState = .removed
            s.connectionDetail = why
        case .authorityChanged(let why):
            s.connectionState = .authorityChanged
            s.connectionDetail = why
        }
        s.localDevelopment = isLocalDevelopment
        s.pairingPending = record?.status == .pending
        s.pairingApproved = record?.status == .approved
        if let r = record {
            s.serverName = r.serverName.isEmpty ? "HCG Server" : r.serverName
            s.serverAddress = r.serverAddress
            s.serverFingerprint = LinkCrypto.displayFingerprint(r.serverFingerprint)
        }
        s.serverRecordedKeyFingerprint = serverRecordedKey.map { LinkCrypto.displayFingerprint($0) }
        s.lastSync = lastSync
        let selfId = devices?.selfInstallationId ?? identity?.installationId ?? ""
        s.devices = (devices?.installations ?? []).map { HCGLinkService.deviceInfo($0, isSelf: $0.installationId == selfId) }
        s.devicesProblem = problems[.devices]
        s.inbox = inbox.map(HCGLinkService.inboxItem)
        s.inboxProblem = problems[.inbox]
        s.approvalsCount = approvals?.approvals.count ?? 0
        s.executionEnabled = approvals?.executionEnabled ?? false
        if let note = approvals?.note, !note.isEmpty { s.approvalsNote = note }
        s.approvalsProblem = problems[.approvals]
        s.host = hostSummary.map(HCGLinkService.hostInfo)
        s.services = hostedServices.map(HCGLinkService.serviceInfo)
        s.servicesLoaded = servicesLoaded
        s.servicesProblem = problems[.services]
        s.busy = busy
        s.notice = notice
        snapshot = s
        changeHandler?()
    }

    // MARK: HCGLinkServicing — visibility and sync

    func screenDidAppear() {
        visible = true
        Task { [weak self] in await self?.refreshAccount() }
        startLoop()
    }

    func screenDidDisappear() {
        visible = false
        stopLoop()
    }

    func clearNotice() {
        guard notice != nil else { return }
        notice = nil
        publish()
    }

    private func refreshAccount() async {
        if case .notConfigured = account { return }
        let tokens = await session.current
        if let t = tokens {
            account = .signedIn(email: t.email)
        } else if case .signedIn = account {
            account = .signedOut
        }
        publish()
    }

    private func startLoop() {
        stopLoop()
        guard visible, client != nil, pairingActive, !linkStopped else { return }
        let current = generation
        syncTask = Task { [weak self] in await self?.runLoop(current) }
    }

    private func stopLoop() {
        syncTask?.cancel()
        syncTask = nil
        generation &+= 1
    }

    /// Foreground loop: pairing poll every 3 s while pending; when approved a heartbeat (with
    /// devices and approvals) every 20 s and the inbox every 10 s; back-off after failures.
    private func runLoop(_ current: Int) async {
        var nextHeartbeat = Date.distantPast
        var failures = 0
        let policy = ReconnectPolicy()
        while !Task.isCancelled, current == generation, let c = client, let r = record {
            let wait: TimeInterval
            do {
                switch r.status {
                case .pending:
                    try await pollPairing(c, requestId: r.requestId)
                    guard current == generation, !linkStopped else { return }
                    guard let status = record?.status else { return }
                    if status == .pending {
                        wait = 3
                    } else if status == .approved {
                        wait = 0
                        nextHeartbeat = .distantPast
                    } else {
                        return
                    }
                case .approved:
                    let now = Date()
                    let beat = now >= nextHeartbeat
                    try await syncRound(c, heartbeat: beat)
                    guard current == generation else { return }
                    if beat { nextHeartbeat = now.addingTimeInterval(DeviceLinkProtocol.heartbeatInterval) }
                    let nextInbox = now.addingTimeInterval(DeviceLinkProtocol.inboxInterval)
                    wait = max(0.5, min(nextHeartbeat, nextInbox).timeIntervalSince(Date()))
                default:
                    return
                }
                failures = 0
            } catch let e as DeviceLinkError {
                guard current == generation else { return }
                guard let retry = handleFailure(e, failures: &failures, policy: policy) else { return }
                wait = retry
                nextHeartbeat = .distantPast
            } catch {
                guard current == generation else { return }
                failures += 1
                wait = policy.delay(afterFailures: failures)
                link = .offline(reason: HCGLinkService.describe(error), retryIn: wait)
                publish()
            }
            do { try await Task.sleep(nanoseconds: UInt64(max(0, wait) * 1_000_000_000)) } catch { return }
        }
    }

    /// Returns the delay before the next attempt, or nil when syncing must stop.
    private func handleFailure(_ e: DeviceLinkError, failures: inout Int, policy: ReconnectPolicy) -> TimeInterval? {
        if e.endsLink {
            end(e)
            return nil
        }
        if e.code == "not_signed_in" {
            link = .paused("Sign in to HCG Connect to sync with \(record?.serverName ?? "HCG Server").")
            publish()
            return nil
        }
        failures += 1
        let wait = e.isRetryable ? policy.delay(afterFailures: failures, retryAfter: e.retryAfter) : max(60, e.retryAfter ?? 0)
        link = .offline(reason: e.description, retryIn: wait)
        publish()
        return wait
    }

    /// Stops on anything that ends the link; never retried automatically.
    private func end(_ e: DeviceLinkError) {
        switch e.code {
        case "device_revoked", "unknown_installation":
            markRemoved("HCG Server no longer accepts this device: it was removed or revoked (\(e.code)). Pairing again needs a new invitation and the owner's approval; this device now has a new key.")
        case "authority_changed":
            resetForAuthorityChange(e.description)
        case "hcg_session_ended":
            account = .ended(e.description)
            link = .paused("Your HCG Connect session has ended. Sign in again to resume.")
            Task { [session] in await session.signOut() }
        default:
            link = .ended(e.description)
        }
        publish()
    }

    private func markRemoved(_ why: String) {
        stopLoop()
        if var r = record {
            r.status = .removed
            r.updatedAt = Date()
            saveRecord(r)
        }
        // A revoked installation can never come back: forget its key so the next pairing uses a new one.
        InstallationIdentity.reset(store: secrets)
        loadIdentity()
        rebuildClient()
        clearRemoteData()
        link = .removed(why)
    }

    /// HCG Server switched between HCG Connect and local development pairing. The old pairing
    /// cannot work again and the server keeps this key's entry, so the pairing and the key are
    /// forgotten here; pairing again needs a new invitation (and an HCG sign-in if the server now
    /// uses HCG Connect).
    private func resetForAuthorityChange(_ serverMessage: String) {
        let server = record?.serverName ?? "HCG Server"
        let wasLocal = isLocalDevelopment
        stopLoop()
        saveRecord(nil)
        InstallationIdentity.reset(store: secrets)
        loadIdentity()
        rebuildClient()
        clearRemoteData()
        let how = wasLocal ? "This device was paired for local development (\(HCGLinkLocalDevelopmentLabel))." : "This device was paired with HCG Connect."
        link = .authorityChanged("\(server) changed how it authorizes apps: \(serverMessage). \(how) That pairing no longer works, so it was forgotten on this device and a new device key will be used. Ask the owner for a new invitation and pair again; they can remove the old entry on the server.")
    }

    private func clearRemoteData() {
        devices = nil
        inbox = []
        approvals = nil
        hostSummary = nil
        hostedServices = []
        servicesLoaded = false
        problems = [:]
        lastSync = nil
        serverRecordedKey = nil
    }

    private func pollPairing(_ c: DeviceLinkClient, requestId: String) async throws {
        let st = try await c.pairingStatus(requestId: requestId)
        guard var r = record, r.requestId == requestId else { return }
        serverRecordedKey = st.keyFingerprint
        if let id = identity, st.keyFingerprint.lowercased() != id.fingerprint {
            link = .ended(HCGLinkService.keyMismatch)
            publish()
            return
        }
        let status = HCGLinkService.recordStatus(st.status)
        if status != r.status {
            r.status = status
            r.updatedAt = Date()
            saveRecord(r)
        }
        switch status {
        case .pending:
            link = .pairing
        case .approved:
            link = .connected
            notice = "\(r.serverName) approved this device."
        default:
            link = HCGLinkService.link(for: r)
        }
        publish()
    }

    private func syncRound(_ c: DeviceLinkClient, heartbeat: Bool) async throws {
        if heartbeat {
            // The advertisement is fixed and local; nothing in a response can change it.
            _ = try await c.heartbeat(capabilities: HCGLinkService.capabilities)
            try await section(.devices) { self.devices = try await c.devices() }
            try await section(.approvals) { self.approvals = try await c.approvals() }
            try await section(.services) {
                let v = try await c.services()
                // A server without hosting answers with an empty host; show no host rather than a blank one.
                self.hostSummary = v.host.agentVersion.isEmpty && v.host.name.isEmpty ? nil : v.host
                self.hostedServices = v.services
                self.servicesLoaded = true
            }
        }
        try await section(.inbox) {
            var messages = try await c.inbox()
            for (i, m) in messages.enumerated() where m.status == "queued" {
                if let updated = try? await c.acknowledge(messageId: m.messageId, opened: false) { messages[i] = updated }
            }
            self.inbox = messages
        }
        lastSync = Date()
        link = .connected
        publish()
    }

    /// Runs one optional part of a round. Errors that end the link or are worth retrying are
    /// rethrown; anything else (for example ERP denying that one operation) is shown on its section.
    private func section(_ part: Part, _ body: () async throws -> Void) async throws {
        do {
            try await body()
            problems[part] = nil
        } catch let e as DeviceLinkError where !e.endsLink && !e.isRetryable && e.code != "not_signed_in" {
            problems[part] = HCGLinkService.sectionProblem(part, e)
        }
    }

    nonisolated private static func sectionProblem(_ part: Part, _ e: DeviceLinkError) -> String {
        if part == .services, ["not_found", "hosting_unavailable", "http_404"].contains(e.code) {
            return "This HCG Server does not host services (it may be an older version): \(e.description)."
        }
        return e.description
    }

    /// Text for a failed one-off request. Anything that ends the link stops it here too.
    private func failure(_ error: Error) -> (text: String, code: String?) {
        guard let e = error as? DeviceLinkError else { return (HCGLinkService.describe(error), nil) }
        if e.endsLink { end(e) }
        if e.code == "gateway_local_only" {
            return ("HCG Server's gateway accepts connections from its own Mac only. The owner must approve local-network access on the Mac first (hcg-agent hosting expose lan --i-approve-local-network-exposure), and this iPhone must trust the HCG Server Local CA (Settings › General › About › Certificate Trust Settings). Nexus never bypasses this check. Server: \(e.description).", e.code)
        }
        return (e.description, e.code)
    }

    /// A one-off request succeeded: the server answered.
    private func contactSucceeded() {
        switch link {
        case .paired, .offline:
            link = .connected
            publish()
        default:
            break
        }
    }

    // MARK: HCGLinkServicing — HCG Connect

    func signIn(presentingFrom window: UIWindow?) {
        switch account {
        case .notConfigured(let why):
            notice = why
            publish()
            return
        case .signedIn:
            return
        case .signedOut, .ended:
            break
        }
        let attempt: SignInAttempt
        do { attempt = try auth.begin() } catch {
            notice = HCGLinkService.describe(error)
            publish()
            return
        }
        let scheme = URL(string: attempt.redirectUri)?.scheme
        let web = ASWebAuthenticationSession(url: attempt.url, callbackURLScheme: scheme) { [weak self] url, error in
            Task { @MainActor in
                await self?.finishSignIn(attempt, callback: url, error: error)
            }
        }
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first { $0.isKeyWindow } }.first
        let presenter = HCGLinkPresentationAnchor(window: window ?? keyWindow ?? ASPresentationAnchor())
        web.presentationContextProvider = presenter
        web.prefersEphemeralWebBrowserSession = false
        anchor = presenter
        webSession = web
        if !web.start() {
            webSession = nil
            anchor = nil
            notice = "The HCG Connect sign-in window could not be opened."
            publish()
        }
    }

    private func finishSignIn(_ attempt: SignInAttempt, callback: URL?, error: Error?) async {
        webSession = nil
        anchor = nil
        guard let url = callback, error == nil else {
            let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
            notice = cancelled ? nil : "Sign-in did not complete."
            publish()
            return
        }
        do {
            connectTransport.expectSignIn(nonce: attempt.nonce)
            let tokens = try await auth.complete(attempt, callback: url)
            try await session.signedIn(tokens)
            account = .signedIn(email: tokens.email)
            notice = "Signed in to HCG Connect."
            switch link {
            case .paused, .ended:
                if pairingActive { link = HCGLinkService.link(for: record) }
            default:
                break
            }
            publish()
            startLoop()
        } catch {
            notice = HCGLinkService.describe(error)
            publish()
        }
    }

    /// Local sign-out (HCG Connect has no revocation endpoint). HCG Server stops accepting the
    /// session once HCG reports it ended.
    func signOut() {
        stopLoop()
        Task { [weak self] in
            guard let self = self else { return }
            await self.session.signOut()
            if case .notConfigured = self.account {} else { self.account = .signedOut }
            // A local development pairing never used the HCG Connect session.
            if self.pairingActive && !self.isLocalDevelopment { self.link = .paused("Signed out of HCG Connect. Sign in to sync again.") }
            self.publish()
        }
    }

    // MARK: HCGLinkServicing — pairing

    func previewInvitation(code: String) -> HCGLinkInvitationPreview {
        let preview = HCGLinkInvitationPreview()
        preview.thisDeviceFingerprint = identity.map { LinkCrypto.displayFingerprint($0.fingerprint) } ?? ""
        do {
            let invitation = try Invitation.parse(code)
            preview.serverName = invitation.hostName.isEmpty ? "HCG Server" : invitation.hostName
            preview.serverAddress = invitation.hostAddress
            preview.serverFingerprint = LinkCrypto.displayFingerprint(invitation.fingerprint)
            preview.expiresAt = invitation.expiresAt
            preview.localDevelopment = invitation.isLocalDevelopment
            if invitation.baseURL == nil {
                preview.problem = "The invitation has no usable server address."
            } else if identity == nil {
                preview.problem = identityProblem ?? "This device has no key."
            } else if !invitation.isLocalDevelopment, case .notConfigured(let why) = account {
                preview.problem = why
            } else if let r = record, pairingActive {
                preview.problem = "This device is already paired with \(r.serverName). Remove it first."
            }
        } catch {
            preview.problem = HCGLinkService.describe(error)
        }
        return preview
    }

    func pair(invitationCode code: String, completion: @escaping (String?) -> Void) {
        let invitation: Invitation
        do { invitation = try Invitation.parse(code) } catch {
            completion(HCGLinkService.describe(error))
            return
        }
        // HCG Connect pairing needs Nexus's issued HCG Connect client; local development pairing
        // (only when the invitation says so) needs no HCG account and sends no token.
        if !invitation.isLocalDevelopment, case .notConfigured(let why) = account {
            completion(why)
            return
        }
        guard let id = identity else {
            completion(identityProblem ?? "This device has no key.")
            return
        }
        guard let base = invitation.baseURL else {
            completion("The invitation has no usable server address.")
            return
        }
        if let r = record, pairingActive {
            completion("This device is already paired with \(r.serverName). Remove it first.")
            return
        }
        stopLoop()
        let c = makeClient(base: base, fingerprint: invitation.fingerprint, identity: id, localDevelopment: invitation.isLocalDevelopment)
        let device = UIDevice.current
        let info = LinkInstallationInfo(installationId: id.installationId,
                                        deviceId: device.identifierForVendor?.uuidString.lowercased(),
                                        name: device.name,
                                        platform: "\(device.systemName) \(device.systemVersion)",
                                        app: HCGLinkService.appIdentifier,
                                        appVersion: HCGLinkService.appVersion,
                                        variant: nil,
                                        publicKey: id.signer.publicKeyBase64,
                                        capabilities: HCGLinkService.capabilities)
        busy = true
        publish()
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let st = try await c.pair(invitation: invitation, info: info)
                self.busy = false
                let r = PairingRecord(invitation: invitation, requestId: st.requestId, status: HCGLinkService.recordStatus(st.status))
                self.saveRecord(r)
                self.clearRemoteData()
                self.serverRecordedKey = st.keyFingerprint
                if st.keyFingerprint.lowercased() != id.fingerprint {
                    self.link = .ended(HCGLinkService.keyMismatch)
                    self.publish()
                    completion(HCGLinkService.keyMismatch)
                    return
                }
                self.link = HCGLinkService.link(for: r)
                self.publish()
                completion(nil)
                self.startLoop()
            } catch {
                self.busy = false
                self.publish()
                completion(HCGLinkService.describe(error))
            }
        }
    }

    // MARK: HCGLinkServicing — reports (data only)

    func openReport(messageId: String, completion: @escaping (HCGLinkOpenedReport?, String?) -> Void) {
        guard let c = client, record?.status == .approved else {
            completion(nil, "This device is not connected to an HCG Server.")
            return
        }
        Task { [weak self] in
            do {
                let (header, report) = try await c.open(messageId: messageId)
                guard report.schema == DeviceLinkProtocol.reportSchema else {
                    completion(nil, "This report uses \(report.schema), which this version of HCG Nexus cannot show.")
                    return
                }
                let opened = HCGLinkOpenedReport()
                opened.messageId = header.messageId
                opened.title = header.title
                opened.fromName = header.from.name
                opened.fromApp = HCGLinkAppDisplayName(header.from.app)
                opened.receivedAt = header.deliveredAt ?? header.queuedAt
                // Plain-text sections only: never links, Markdown, HTML or commands.
                opened.sections = ReportTextRenderer.sections(report).map { section in
                    let s = HCGLinkReportSection()
                    s.title = section.title
                    s.lines = section.lines
                    return s
                }
                completion(opened, nil)
                if let updated = try? await c.acknowledge(messageId: messageId, opened: true) {
                    self?.replaceInboxItem(updated)
                }
            } catch {
                completion(nil, self?.failure(error).text ?? HCGLinkService.describe(error))
            }
        }
    }

    private func replaceInboxItem(_ updated: LinkMessageHeader) {
        guard let i = inbox.firstIndex(where: { $0.messageId == updated.messageId }) else { return }
        inbox[i] = updated
        publish()
    }

    // MARK: HCGLinkServicing — hosted services and diagnostics (read-only)

    func openService(identifier: String, completion: @escaping (HCGLinkOpenTicketInfo?, String?, String?) -> Void) {
        guard let c = client, record?.status == .approved else {
            completion(nil, "This device is not connected to an HCG Server.", nil)
            return
        }
        Task { [weak self] in
            do {
                let t = try await c.openService(identifier)
                self?.contactSucceeded()
                // Only an https link is ever handed to the system browser, which verifies the
                // gateway's certificate itself (HCG Server Local CA). Nothing here weakens that.
                guard let url = URL(string: t.url), url.scheme?.lowercased() == "https", url.host != nil else {
                    completion(nil, "HCG Server sent a link that is not an https address, so it was not opened.", "invalid_response")
                    return
                }
                let info = HCGLinkOpenTicketInfo()
                info.url = url
                info.expiresAt = t.expiresAt
                info.caFingerprint = HCGLinkService.pairedHex(t.caFingerprint)
                info.note = t.note
                completion(info, nil, nil)
            } catch {
                let f: (text: String, code: String?) = self?.failure(error) ?? (HCGLinkService.describe(error), nil)
                completion(nil, f.text, f.code)
            }
        }
    }

    func loadDiagnostics(completion: @escaping (HCGLinkDiagnosticsInfo?, String?) -> Void) {
        guard let c = client, let r = record, r.status == .approved else {
            completion(nil, "This device is not connected to an HCG Server.")
            return
        }
        let local = localConnectionLines()
        Task { [weak self] in
            do {
                let d = try await c.diagnostics()
                self?.contactSucceeded()
                let info = HCGLinkDiagnosticsInfo()
                info.generatedAt = d.generatedAt
                info.serverName = r.serverName.isEmpty ? "HCG Server" : r.serverName
                info.localDevelopment = r.isLocalDevelopment
                info.sections = HCGLinkService.diagnosticsSections(d, pinned: r.serverFingerprint, local: local)
                completion(info, nil)
            } catch {
                completion(nil, self?.failure(error).text ?? HCGLinkService.describe(error))
            }
        }
    }

    /// What this device knows about its own connection (no secrets: the pinned key is public).
    private func localConnectionLines() -> [String] {
        var lines: [String] = []
        if let r = record {
            lines.append("Server address: \(r.serverAddress)")
            lines.append("Pinned server key: \(LinkCrypto.displayFingerprint(r.serverFingerprint))")
            lines.append("Authorized by: " + (r.isLocalDevelopment ? HCGLinkLocalDevelopmentLabel : "HCG Connect sign-in and ERP App Access"))
        }
        let f = ISO8601DateFormatter()
        lines.append("Last successful sync: " + (lastSync.map { f.string(from: $0) } ?? "none since HCG Nexus was opened"))
        if case .offline(let reason, _) = link { lines.append("Last error: \(reason)") }
        lines.append("Device API: TLS with the server key pinned from the invitation; every request signed with this device's key")
        return lines
    }

    nonisolated private static func authorityText(_ a: String) -> String {
        switch a {
        case DeviceLinkProtocol.Authority.hcgConnect: return "HCG Connect"
        case DeviceLinkProtocol.Authority.localDevelopment: return HCGLinkLocalDevelopmentLabel
        case "not-configured": return "Not configured (no HCG Connect, local development off)"
        default: return a
        }
    }

    nonisolated private static func exposureText(_ e: String) -> String {
        switch e {
        case "lan": return "local network (approved by the owner on the Mac)"
        case "loopback": return "the Mac only"
        default: return e
        }
    }

    nonisolated private static func durationText(_ seconds: Int64) -> String {
        let s = max(0, seconds)
        if s < 60 { return "\(s) s" }
        if s < 3600 { return "\(s / 60) min" }
        if s < 86400 { return "\(s / 3600) h \((s % 3600) / 60) min" }
        return "\(s / 86400) d \((s % 86400) / 3600) h"
    }

    nonisolated static func serviceLine(_ v: LinkHostedService) -> String {
        var parts = ["\(v.name.isEmpty ? v.id : v.name) \(v.version)", v.status, "health \(v.health)"]
        if let up = v.uptimeSeconds { parts.append("up \(durationText(up))") }
        if v.restarts > 0 { parts.append("\(v.restarts) restart\(v.restarts == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    /// Plain-text sections only: the diagnostics are data, never links or commands.
    nonisolated private static func diagnosticsSections(_ d: LinkDiagnostics, pinned: String, local: [String]) -> [HCGLinkReportSection] {
        func section(_ title: String, _ lines: [String]) -> HCGLinkReportSection {
            let s = HCGLinkReportSection()
            s.title = title
            s.lines = lines
            return s
        }
        let f = ISO8601DateFormatter()
        var out: [HCGLinkReportSection] = []
        out.append(section("Server", [
            "Available: " + (d.server.available ? "yes" : "no"),
            "HCG Server agent \(d.server.agentVersion), up \(durationText(d.server.uptimeSeconds)) (since \(f.string(from: d.server.startedAt)))",
            "Authority: " + authorityText(d.server.authority),
        ]))
        var tls = ["Device API: \(d.tls.deviceApi)",
                   "Server key SHA-256: \(LinkCrypto.displayFingerprint(d.tls.serverKeySha256))"]
        if !d.tls.serverKeySha256.isEmpty {
            tls.append(d.tls.serverKeySha256.lowercased() == pinned.lowercased()
                       ? "Matches the key pinned from the invitation"
                       : "DOES NOT MATCH the key pinned from the invitation")
        }
        tls.append("Gateway: " + (d.tls.gatewayRunning ? "running" : "not running") + ", reachable from " + exposureText(d.tls.gatewayExposure))
        if !d.tls.gatewayCaSha256.isEmpty { tls.append("HCG Server Local CA SHA-256: \(pairedHex(d.tls.gatewayCaSha256))") }
        if let exp = d.tls.gatewayLeafExpires { tls.append("Gateway certificate expires: \(f.string(from: exp))") }
        out.append(section("TLS and gateway", tls))
        out.append(section("Hosted services", d.services.map { v in
            var line = serviceLine(v)
            if let detail = v.detail, !detail.isEmpty { line += " — " + detail }
            return line
        }))
        var security = ["Failed authentications (24 h): \(d.failedAuthentications24h)"]
        security += d.securityEvents.map { "\(f.string(from: $0.time)) · \($0.severity) · \($0.message)" }
        out.append(section("Security events (redacted by the server)", security))
        if !d.summary.isEmpty { out.append(section("Summary", d.summary)) }
        out.append(section("This device's connection", local))
        return out
    }

    // MARK: HCGLinkServicing — removal

    func removeThisDevice(completion: @escaping (String) -> Void) {
        let server = record?.serverName ?? "the server"
        guard let c = client else {
            forgetLocally()
            publish()
            completion("The pairing was forgotten on this device and a new key will be used next time.")
            return
        }
        stopLoop()
        busy = true
        publish()
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await c.unregister()
                self.forgetLocally()
                self.busy = false
                self.publish()
                completion("This device was removed from \(server). Its key was deleted; pairing again creates a new one.")
            } catch {
                self.busy = false
                self.publish()
                self.startLoop()
                completion("\(server) did not confirm the removal: \(HCGLinkService.describe(error)) You can still forget the pairing on this device only; the server's owner can then revoke the old entry.")
            }
        }
    }

    func forgetPairingOnThisDevice() {
        forgetLocally()
        notice = "The pairing was forgotten on this device and a new key will be used next time. Ask the server's owner to revoke the old entry."
        publish()
    }

    private func forgetLocally() {
        stopLoop()
        saveRecord(nil)
        InstallationIdentity.reset(store: secrets)
        loadIdentity()
        rebuildClient()
        clearRemoteData()
        link = .notPaired
    }
}

/// Window anchor for the HCG Connect sign-in sheet. The window is chosen on the main actor
/// when sign-in starts and released when it finishes.
final class HCGLinkPresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let window: ASPresentationAnchor

    init(window: ASPresentationAnchor) {
        self.window = window
        super.init()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        window
    }
}
