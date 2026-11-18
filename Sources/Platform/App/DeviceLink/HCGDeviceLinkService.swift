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

    private static let shared = HCGLinkService(bundle: .main)

    static func sharedLinkService() -> HCGLinkServicing { shared }

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
        case connected
        case offline(reason: String, retryIn: TimeInterval)
        case paused(String)
        case ended(String)
        case removed(String)
    }

    private enum Part: Hashable { case devices, inbox, approvals }

    private(set) var snapshot = HCGLinkSnapshot()
    var changeHandler: (() -> Void)?

    private let secrets: LinkSecretStore
    private let recordFile: PairingRecordFile
    private let auth: HCGConnectAuth
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
        let connectAuth = HCGConnectAuth(configuration: configuration, expectedContract: HCGLinkService.contract)
        auth = connectAuth
        session = HCGConnectSession(auth: connectAuth, store: SecretTokenStore(store: store))
        if let problem = configuration.problem(expectedContract: HCGLinkService.contract) {
            account = .notConfigured(problem)
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
        case .approved?: return .connected
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
        case .ended, .removed, .paused: return true
        default: return false
        }
    }

    private func makeClient(base: URL, fingerprint: String, identity id: InstallationIdentity) -> DeviceLinkClient {
        DeviceLinkClient(configuration: DeviceLinkConfiguration(baseURL: base, serverFingerprint: fingerprint, installationId: id.installationId),
                         signer: id.signer, transport: PinnedSessionTransport(fingerprint: fingerprint), tokens: session)
    }

    private func rebuildClient() {
        guard let r = record, pairingActive, let base = r.baseURL, let id = identity else {
            client = nil
            return
        }
        client = makeClient(base: base, fingerprint: r.serverFingerprint, identity: id)
    }

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
        }
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

    private func clearRemoteData() {
        devices = nil
        inbox = []
        approvals = nil
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
            problems[part] = e.description
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
            if self.pairingActive { self.link = .paused("Signed out of HCG Connect. Sign in to sync again.") }
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
            if invitation.baseURL == nil {
                preview.problem = "The invitation has no usable server address."
            } else if identity == nil {
                preview.problem = identityProblem ?? "This device has no key."
            } else if case .notConfigured(let why) = account {
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
        if case .notConfigured(let why) = account {
            completion(why)
            return
        }
        guard let id = identity else {
            completion(identityProblem ?? "This device has no key.")
            return
        }
        let invitation: Invitation
        do { invitation = try Invitation.parse(code) } catch {
            completion(HCGLinkService.describe(error))
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
        let c = makeClient(base: base, fingerprint: invitation.fingerprint, identity: id)
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
                completion(nil, HCGLinkService.describe(error))
            }
        }
    }

    private func replaceInboxItem(_ updated: LinkMessageHeader) {
        guard let i = inbox.firstIndex(where: { $0.messageId == updated.messageId }) else { return }
        inbox[i] = updated
        publish()
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
