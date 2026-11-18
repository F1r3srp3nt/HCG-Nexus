import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HCGDeviceLink

/// The network transport Nexus gives the vendored HCGConnectAuth.
///
/// The vendored client binds a sign-in to its attempt by DECODING the ID token
/// (nonce, audience, issuer) and reads the account from the access token without
/// checking either signature. Nexus never relies on that alone: every successful
/// response from the token endpoint passes through here first and is verified
/// cryptographically (HCGConnectTokenVerifier: ES256 against the issuer's JWKS,
/// issuer, audience, client, expiry, nonce, same account in both tokens). A
/// response that fails is turned into HCGConnectError.mismatch before the client
/// reads it, so nothing is stored and the sign-in or refresh fails closed.
///
/// Without a configured HCG Connect client there is no trust anchor, `isVerifying`
/// is false and every token response is refused.
final class HCGVerifiedConnectTransport: @unchecked Sendable {
    typealias Send = @Sendable (URLRequest) async throws -> (Data, Int)

    private let tokenEndpoint: String
    private let verifier: HCGConnectTokenVerifier?
    private let inner: Send
    private let lock = NSLock()
    private var pendingNonce: String?
    private var signInNonce: String?

    init(configuration: HCGConnectConfiguration, inner: Send? = nil) {
        let send = inner ?? HCGVerifiedConnectTransport.urlSessionSend
        self.inner = send
        tokenEndpoint = configuration.tokenEndpoint
        if let trust = HCGConnectTrust(issuer: configuration.issuer, clientId: configuration.clientId) {
            let keys = HCGConnectSigningKeys(url: trust.jwksURL) { url in
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                return try await send(request)
            }
            verifier = HCGConnectTokenVerifier(trust: trust, keys: keys)
        } else {
            verifier = nil
        }
    }

    /// YES when tokens can be verified (an HCG Connect client and a valid issuer are configured).
    var isVerifying: Bool { verifier != nil }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    /// Call right before HCGConnectAuth.complete(attempt, …) with that attempt's nonce.
    func expectSignIn(nonce: String) {
        locked { pendingNonce = nonce }
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, status) = try await inner(request)
        guard request.url?.absoluteString == tokenEndpoint, status == 200 else { return (data, status) }
        guard let verifier = verifier else {
            throw HCGConnectError.mismatch("token verification: " + HCGConnectTokenError.notConfigured.description)
        }
        let grant = HCGConnectTokenVerifier.grantType(ofFormBody: request.httpBody)
        let policy: HCGConnectNoncePolicy
        if grant == "authorization_code" {
            let nonce: String? = locked {
                let n = pendingNonce
                pendingNonce = nil
                return n
            }
            guard let expected = nonce else { throw HCGConnectError.mismatch("token verification: no sign-in in progress") }
            policy = .required(expected)
        } else {
            policy = .matchIfPresent(locked { signInNonce })
        }
        do {
            _ = try await verifier.verifyTokenResponse(data, grantType: grant, nonce: policy)
        } catch let error as HCGConnectTokenError {
            throw HCGConnectError.mismatch("token verification: " + error.description)
        }
        if case .required(let nonce) = policy {
            locked { signInNonce = nonce }
        }
        return (data, status)
    }

    /// The same ephemeral URLSession request the vendored client uses by default.
    private static let urlSessionSend: Send = { request in
        try await withCheckedThrowingContinuation { continuation in
            URLSession(configuration: .ephemeral).dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: HCGConnectError.unavailable(error.localizedDescription))
                    return
                }
                continuation.resume(returning: (data ?? Data(), (response as? HTTPURLResponse)?.statusCode ?? 0))
            }.resume()
        }
    }
}
