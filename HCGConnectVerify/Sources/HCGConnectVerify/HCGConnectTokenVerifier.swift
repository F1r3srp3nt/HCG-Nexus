import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

// HCG Connect token verification for HCG Nexus.
//
// The same rules as HCG-Server's verifier (internal/hcgconnect/verifier.go), which
// is the established HCG Connect implementation:
//   * ES256 only, with keys from the issuer's own JWKS (EC P-256, "sig"), cached
//     for 10 minutes; an unknown key ID causes exactly one re-fetch.
//   * The exact issuer; a UUID subject; exp required; nbf/iat honoured; 60 s leeway.
//   * Access tokens: audience "authenticated", role "authenticated", client_id ==
//     this app's client.
//   * ID tokens (OpenID Connect Core 3.1.3.7): audience contains this app's client
//     (and azp == client when present or when there are several audiences), and the
//     nonce of this sign-in attempt.
// Nothing here trusts a claim that was only decoded.

// MARK: Trust anchors

/// What Nexus trusts: one issuer, its JWKS on the same host, and Nexus's own client.
public struct HCGConnectTrust: Sendable, Equatable {
    public static let defaultLeeway: TimeInterval = 60

    public let issuer: String
    public let jwksURL: URL
    public let clientId: String
    public let leeway: TimeInterval

    /// nil unless the issuer and JWKS are https on the same host and a client ID is given.
    public init?(issuer: String, clientId: String?, jwksURL: URL? = nil, leeway: TimeInterval = HCGConnectTrust.defaultLeeway) {
        guard let clientId = clientId, !clientId.isEmpty,
              let issuerURL = URL(string: issuer), issuerURL.scheme == "https", let host = issuerURL.host, !host.isEmpty,
              issuerURL.query == nil, issuerURL.fragment == nil else { return nil }
        let keys = jwksURL ?? URL(string: issuer + "/.well-known/jwks.json")
        guard let keysURL = keys, keysURL.scheme == "https", keysURL.host == host else { return nil }
        self.issuer = issuer
        self.jwksURL = keysURL
        self.clientId = clientId
        self.leeway = leeway
    }
}

// MARK: Errors

public enum HCGConnectTokenError: Error, Equatable, CustomStringConvertible {
    case malformed
    case unsupportedAlgorithm(String)
    case unknownSigningKey
    case invalidSignature
    case wrongIssuer
    case wrongAudience
    case wrongClient
    case notAUserAccessToken
    case invalidSubject
    case subjectMismatch
    case missingExpiry
    case expired
    case notYetValid
    case issuedInFuture
    case missingNonce
    case nonceMismatch
    case missingToken(String)
    case keysUnavailable(String)
    case notConfigured

    public var description: String {
        switch self {
        case .malformed: return "the token is malformed"
        case .unsupportedAlgorithm(let a): return "the token must be signed with ES256, not \(a.isEmpty ? "nothing" : a)"
        case .unknownSigningKey: return "the token was not signed by a current HCG Connect key"
        case .invalidSignature: return "the token signature is not valid"
        case .wrongIssuer: return "the token was not issued by HCG Connect"
        case .wrongAudience: return "the token was issued for another audience"
        case .wrongClient: return "the token was issued to another application"
        case .notAUserAccessToken: return "the token is not an HCG Connect user access token"
        case .invalidSubject: return "the token has no valid account subject"
        case .subjectMismatch: return "the ID token and access token name different accounts"
        case .missingExpiry: return "the token has no expiry"
        case .expired: return "the token has expired"
        case .notYetValid: return "the token is not valid yet"
        case .issuedInFuture: return "the token was issued in the future"
        case .missingNonce: return "the ID token has no nonce"
        case .nonceMismatch: return "the ID token belongs to another sign-in"
        case .missingToken(let which): return "the response has no \(which)"
        case .keysUnavailable(let why): return "HCG Connect signing keys could not be loaded (\(why))"
        case .notConfigured: return "token verification is not configured (no HCG Connect client)"
        }
    }
}

// MARK: Signing keys

/// The issuer's signing keys (JWKS), cached for `cacheLifetime`.
public actor HCGConnectSigningKeys {
    public typealias Fetch = @Sendable (URL) async throws -> (Data, Int)
    public static let cacheLifetime: TimeInterval = 600
    static let maximumKeySetBytes = 1 << 20

    private let url: URL
    private let fetch: Fetch
    private let now: @Sendable () -> Date
    private var keys: [String: P256.Signing.PublicKey]?
    private var fetchedAt = Date.distantPast
    public private(set) var fetchCount = 0

    public init(url: URL, now: @escaping @Sendable () -> Date = { Date() }, fetch: @escaping Fetch) {
        self.url = url
        self.now = now
        self.fetch = fetch
    }

    public func key(id: String) async throws -> P256.Signing.PublicKey {
        if let cached = keys, now().timeIntervalSince(fetchedAt) < Self.cacheLifetime, let k = cached[id] {
            return k
        }
        try await reload() // unknown key ID or stale cache: one re-fetch
        guard let k = keys?[id] else { throw HCGConnectTokenError.unknownSigningKey }
        return k
    }

    private func reload() async throws {
        fetchCount += 1
        let data: Data
        let status: Int
        do {
            (data, status) = try await fetch(url)
        } catch {
            throw HCGConnectTokenError.keysUnavailable("network")
        }
        guard status == 200 else { throw HCGConnectTokenError.keysUnavailable("HTTP \(status)") }
        guard data.count <= Self.maximumKeySetBytes,
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let list = object["keys"] as? [[String: Any]] else {
            throw HCGConnectTokenError.keysUnavailable("not a JSON Web Key Set")
        }
        var parsed: [String: P256.Signing.PublicKey] = [:]
        for entry in list {
            if let pair = Self.signingKey(entry) { parsed[pair.0] = pair.1 }
        }
        keys = parsed
        fetchedAt = now()
    }

    /// An ES256 verification key, or nil for anything else (other curves, RSA, symmetric, encryption keys).
    public static func signingKey(_ jwk: [String: Any]) -> (String, P256.Signing.PublicKey)? {
        guard jwk["kty"] as? String == "EC", jwk["crv"] as? String == "P-256" else { return nil }
        if let alg = jwk["alg"] as? String, alg != "ES256" { return nil }
        if let use = jwk["use"] as? String, use != "sig" { return nil }
        guard let x = (jwk["x"] as? String).flatMap(HCGJWT.base64URLDecode), x.count == 32,
              let y = (jwk["y"] as? String).flatMap(HCGJWT.base64URLDecode), y.count == 32,
              let key = try? P256.Signing.PublicKey(rawRepresentation: x + y) else { return nil } // rejects off-curve points
        return (jwk["kid"] as? String ?? "", key)
    }
}

// MARK: JWT helpers

public enum HCGJWT {
    public static let maximumLength = 8192

    public static func base64URLDecode(_ s: String) -> Data? {
        guard !s.contains("=") else { return nil }
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t += "=" }
        return Data(base64Encoded: t)
    }

    public static func base64URLEncode(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        return nil
    }

    static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<x.count { diff |= x[i] ^ y[i] }
        return diff == 0
    }

    static func isUUID(_ s: String) -> Bool {
        let groups = s.split(separator: "-", omittingEmptySubsequences: false)
        guard groups.map({ $0.count }) == [8, 4, 4, 4, 12] else { return false }
        return groups.allSatisfy { $0.allSatisfy { $0.isHexDigit } }
    }

    static func audiences(_ value: Any?) -> [String]? {
        if let one = value as? String { return [one] }
        if let many = value as? [Any] {
            let strings = many.compactMap { $0 as? String }
            return strings.count == many.count ? strings : nil
        }
        return nil
    }
}

// MARK: Verified result

public struct HCGConnectVerifiedToken: Sendable, Equatable {
    public let subject: String
    public let email: String?
    public let expiresAt: Date
    public let nonce: String?
}

/// How the ID token's nonce is checked.
public enum HCGConnectNoncePolicy: Sendable, Equatable {
    /// A sign-in: the nonce must be present and equal this attempt's nonce.
    case required(String)
    /// A refresh: if a nonce is present it must equal the original sign-in's (when known).
    case matchIfPresent(String?)
}

// MARK: Verifier

public struct HCGConnectTokenVerifier: Sendable {
    public let trust: HCGConnectTrust
    public let keys: HCGConnectSigningKeys
    private let now: @Sendable () -> Date

    public init(trust: HCGConnectTrust, keys: HCGConnectSigningKeys, now: @escaping @Sendable () -> Date = { Date() }) {
        self.trust = trust
        self.keys = keys
        self.now = now
    }

    /// Signature, issuer, subject and time checks shared by both token kinds.
    func verifiedClaims(_ jwt: String) async throws -> [String: Any] {
        guard jwt.utf8.count <= HCGJWT.maximumLength else { throw HCGConnectTokenError.malformed }
        let parts = jwt.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              let headerData = HCGJWT.base64URLDecode(parts[0]),
              let header = (try? JSONSerialization.jsonObject(with: headerData)) as? [String: Any] else {
            throw HCGConnectTokenError.malformed
        }
        let alg = header["alg"] as? String ?? ""
        guard alg == "ES256" else { throw HCGConnectTokenError.unsupportedAlgorithm(alg) }
        guard let signatureBytes = HCGJWT.base64URLDecode(parts[2]), signatureBytes.count == 64,
              let signature = try? P256.Signing.ECDSASignature(rawRepresentation: signatureBytes) else {
            throw HCGConnectTokenError.malformed
        }
        let key = try await keys.key(id: header["kid"] as? String ?? "")
        // CryptoKit hashes the signing input with SHA-256 for P-256 (ES256).
        guard key.isValidSignature(signature, for: Data((parts[0] + "." + parts[1]).utf8)) else {
            throw HCGConnectTokenError.invalidSignature
        }
        guard let payloadData = HCGJWT.base64URLDecode(parts[1]),
              let claims = (try? JSONSerialization.jsonObject(with: payloadData)) as? [String: Any] else {
            throw HCGConnectTokenError.malformed
        }
        guard claims["iss"] as? String == trust.issuer else { throw HCGConnectTokenError.wrongIssuer }
        guard let subject = claims["sub"] as? String, HCGJWT.isUUID(subject) else { throw HCGConnectTokenError.invalidSubject }
        let current = now().timeIntervalSince1970
        guard let exp = HCGJWT.number(claims["exp"]) else { throw HCGConnectTokenError.missingExpiry }
        guard current <= exp + trust.leeway else { throw HCGConnectTokenError.expired }
        if let nbf = HCGJWT.number(claims["nbf"]), current + trust.leeway < nbf { throw HCGConnectTokenError.notYetValid }
        if let iat = HCGJWT.number(claims["iat"]), current + trust.leeway < iat { throw HCGConnectTokenError.issuedInFuture }
        return claims
    }

    private static func result(_ claims: [String: Any]) -> HCGConnectVerifiedToken {
        HCGConnectVerifiedToken(subject: (claims["sub"] as? String ?? "").lowercased(), email: claims["email"] as? String,
                                expiresAt: Date(timeIntervalSince1970: HCGJWT.number(claims["exp"]) ?? 0),
                                nonce: claims["nonce"] as? String)
    }

    /// An HCG Connect user access token issued to this app.
    public func verifyAccessToken(_ jwt: String) async throws -> HCGConnectVerifiedToken {
        let claims = try await verifiedClaims(jwt)
        guard let aud = HCGJWT.audiences(claims["aud"]), aud.contains("authenticated"),
              claims["role"] as? String == "authenticated" else { throw HCGConnectTokenError.notAUserAccessToken }
        guard claims["client_id"] as? String == trust.clientId else { throw HCGConnectTokenError.wrongClient }
        return Self.result(claims)
    }

    /// An OpenID Connect ID token for this app.
    public func verifyIDToken(_ jwt: String, nonce policy: HCGConnectNoncePolicy) async throws -> HCGConnectVerifiedToken {
        let claims = try await verifiedClaims(jwt)
        guard let aud = HCGJWT.audiences(claims["aud"]), aud.contains(trust.clientId) else { throw HCGConnectTokenError.wrongAudience }
        if let azp = claims["azp"] as? String {
            guard azp == trust.clientId else { throw HCGConnectTokenError.wrongClient }
        } else if aud.count > 1 {
            throw HCGConnectTokenError.wrongClient
        }
        let nonce = claims["nonce"] as? String
        switch policy {
        case .required(let expected):
            guard let nonce = nonce else { throw HCGConnectTokenError.missingNonce }
            guard !expected.isEmpty, HCGJWT.constantTimeEqual(nonce, expected) else { throw HCGConnectTokenError.nonceMismatch }
        case .matchIfPresent(let original):
            if let nonce = nonce, let original = original, !HCGJWT.constantTimeEqual(nonce, original) {
                throw HCGConnectTokenError.nonceMismatch
            }
        }
        return Self.result(claims)
    }

    /// Checks a successful token-endpoint response before anything reads it: the access token
    /// always; the ID token always for a sign-in (authorization_code) and whenever one is present
    /// on a refresh; both must name the same account.
    public func verifyTokenResponse(_ data: Data, grantType: String?, nonce policy: HCGConnectNoncePolicy) async throws -> HCGConnectVerifiedToken {
        guard let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw HCGConnectTokenError.malformed }
        guard let accessToken = body["access_token"] as? String, !accessToken.isEmpty else {
            throw HCGConnectTokenError.missingToken("access token")
        }
        let access = try await verifyAccessToken(accessToken)
        let idToken = body["id_token"] as? String
        if grantType == "authorization_code" && (idToken ?? "").isEmpty {
            throw HCGConnectTokenError.missingToken("ID token")
        }
        if let idToken = idToken, !idToken.isEmpty {
            let id = try await verifyIDToken(idToken, nonce: policy)
            guard id.subject == access.subject else { throw HCGConnectTokenError.subjectMismatch }
        }
        return access
    }

    /// grant_type of an application/x-www-form-urlencoded token request body.
    public static func grantType(ofFormBody body: Data?) -> String? {
        guard let body = body, let text = String(data: body, encoding: .utf8) else { return nil }
        for pair in text.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            if kv.count == 2, kv[0] == "grant_type" { return String(kv[1]).removingPercentEncoding }
        }
        return nil
    }
}
