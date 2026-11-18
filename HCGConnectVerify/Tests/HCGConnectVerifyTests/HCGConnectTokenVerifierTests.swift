import XCTest
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
import HCGConnectVerify

private let issuer = "https://qggdyzoydveafkmjgkpq.supabase.co/auth/v1"
private let client = "11111111-2222-4333-8444-555555555555"
private let subject = "0f8fad5b-d9cb-469f-a165-70867728950e"
private let start = Date(timeIntervalSince1970: 1_800_000_000)

private func encode(_ object: [String: Any]) -> String {
    HCGJWT.base64URLEncode(try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
}

private struct Signer {
    let key = P256.Signing.PrivateKey()
    let kid: String

    func jwk(extra: [String: Any] = [:]) -> [String: Any] {
        let raw = key.publicKey.rawRepresentation
        var k: [String: Any] = ["kty": "EC", "crv": "P-256", "alg": "ES256", "use": "sig", "kid": kid,
                                "x": HCGJWT.base64URLEncode(raw.prefix(32)), "y": HCGJWT.base64URLEncode(raw.suffix(32))]
        for (name, value) in extra { k[name] = value }
        return k
    }

    func sign(_ claims: [String: Any], header: [String: Any]? = nil) -> String {
        let input = encode(header ?? ["alg": "ES256", "typ": "JWT", "kid": kid]) + "." + encode(claims)
        let signature = try! key.signature(for: Data(input.utf8)).rawRepresentation
        return input + "." + HCGJWT.base64URLEncode(signature)
    }
}

/// A JWKS endpoint and a clock the tests control.
private final class World: @unchecked Sendable {
    private let lock = NSLock()
    private var keySet: [[String: Any]] = []
    private var status = 200
    private var offline = false
    private var hits = 0
    private var time = start

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func publish(_ keys: [[String: Any]], status: Int = 200) { locked { keySet = keys; self.status = status } }
    func goOffline() { locked { offline = true } }
    func advance(_ seconds: TimeInterval) { locked { time = time.addingTimeInterval(seconds) } }
    var now: Date { locked { time } }
    var fetches: Int { locked { hits } }

    func fetch() throws -> (Data, Int) {
        let (keys, code, down): ([[String: Any]], Int, Bool) = locked {
            hits += 1
            return (keySet, status, offline)
        }
        if down { throw URLError(.notConnectedToInternet) }
        return (try JSONSerialization.data(withJSONObject: ["keys": keys]), code)
    }
}

final class HCGConnectTokenVerifierTests: XCTestCase {
    private var world: World!
    private var signer: Signer!
    private var verifier: HCGConnectTokenVerifier!

    override func setUp() {
        super.setUp()
        world = World()
        signer = Signer(kid: "key-1")
        world.publish([signer.jwk()])
        verifier = makeVerifier()
    }

    private func makeVerifier() -> HCGConnectTokenVerifier {
        let w = world!
        let trust = HCGConnectTrust(issuer: issuer, clientId: client)!
        let keys = HCGConnectSigningKeys(url: trust.jwksURL, now: { w.now }, fetch: { _ in try w.fetch() })
        return HCGConnectTokenVerifier(trust: trust, keys: keys, now: { w.now })
    }

    private var t: Double { world.now.timeIntervalSince1970 }

    private func idClaims(_ changes: [String: Any?] = [:]) -> [String: Any] {
        var c: [String: Any] = ["iss": issuer, "sub": subject, "aud": client, "exp": t + 3600, "iat": t, "nonce": "n-123",
                                "email": "person@example.invalid"]
        for (k, v) in changes { c[k] = v }
        return c
    }

    private func accessClaims(_ changes: [String: Any?] = [:]) -> [String: Any] {
        var c: [String: Any] = ["iss": issuer, "sub": subject, "aud": "authenticated", "role": "authenticated",
                                "client_id": client, "exp": t + 3600, "iat": t, "email": "person@example.invalid"]
        for (k, v) in changes { c[k] = v }
        return c
    }

    private func expect(_ error: HCGConnectTokenError, _ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            try await body()
            XCTFail("accepted; expected \(error)", file: file, line: line)
        } catch let e as HCGConnectTokenError {
            XCTAssertEqual(e, error, file: file, line: line)
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }

    // MARK: accepted

    func testValidTokensAreAccepted() async throws {
        let id = try await verifier.verifyIDToken(signer.sign(idClaims()), nonce: .required("n-123"))
        XCTAssertEqual(id.subject, subject)
        XCTAssertEqual(id.email, "person@example.invalid")
        let access = try await verifier.verifyAccessToken(signer.sign(accessClaims()))
        XCTAssertEqual(access.subject, subject)
        XCTAssertEqual(access.expiresAt, Date(timeIntervalSince1970: t + 3600))
    }

    // MARK: signature and keys

    func testTamperedPayloadIsRejected() async {
        let token = signer.sign(idClaims())
        let parts = token.split(separator: ".").map(String.init)
        let forged = parts[0] + "." + encode(idClaims(["sub": "6f1c7a1e-0000-4000-8000-000000000000"])) + "." + parts[2]
        await expect(.invalidSignature) { _ = try await self.verifier.verifyIDToken(forged, nonce: .required("n-123")) }
    }

    func testTokenSignedByAnUntrustedKeyWithATrustedKeyIDIsRejected() async {
        let impostor = Signer(kid: "key-1")
        await expect(.invalidSignature) { _ = try await self.verifier.verifyIDToken(impostor.sign(self.idClaims()), nonce: .required("n-123")) }
    }

    func testUnknownKeyIDIsRejectedAfterExactlyOneRefetch() async {
        let other = Signer(kid: "key-2")
        await expect(.unknownSigningKey) { _ = try await self.verifier.verifyIDToken(other.sign(self.idClaims()), nonce: .required("n-123")) }
        XCTAssertEqual(world.fetches, 1)
        // A key that is not in the set stays unknown; each attempt costs one fetch, never a loop.
        await expect(.unknownSigningKey) { _ = try await self.verifier.verifyIDToken(other.sign(self.idClaims()), nonce: .required("n-123")) }
        XCTAssertEqual(world.fetches, 2)
    }

    func testRotatedKeyIsPickedUpAndCacheIsReused() async throws {
        _ = try await verifier.verifyAccessToken(signer.sign(accessClaims()))
        _ = try await verifier.verifyAccessToken(signer.sign(accessClaims()))
        XCTAssertEqual(world.fetches, 1, "keys are cached")
        let next = Signer(kid: "key-2")
        world.publish([signer.jwk(), next.jwk()])
        _ = try await verifier.verifyAccessToken(next.sign(accessClaims()))
        XCTAssertEqual(world.fetches, 2, "an unknown key ID re-fetches once")
        world.advance(HCGConnectSigningKeys.cacheLifetime + 1)
        _ = try await verifier.verifyAccessToken(signer.sign(accessClaims()))
        XCTAssertEqual(world.fetches, 3, "stale keys are re-fetched")
    }

    func testOnlyES256SigningKeysAreTrusted() async {
        let raw = signer.key.publicKey.rawRepresentation
        let x = HCGJWT.base64URLEncode(raw.prefix(32)), y = HCGJWT.base64URLEncode(raw.suffix(32))
        world.publish([
            ["kty": "EC", "crv": "P-256", "alg": "ES256", "use": "enc", "kid": "key-1", "x": x, "y": y],
            ["kty": "EC", "crv": "P-256", "alg": "ES384", "kid": "key-1", "x": x, "y": y],
            ["kty": "EC", "crv": "P-384", "kid": "key-1", "x": x, "y": y],
            ["kty": "RSA", "kid": "key-1", "n": "AQAB", "e": "AQAB"],
            ["kty": "oct", "kid": "key-1", "k": "c2VjcmV0"],
            ["kty": "EC", "crv": "P-256", "kid": "key-1", "x": x, "y": HCGJWT.base64URLEncode(Data(repeating: 7, count: 32))],
        ])
        await expect(.unknownSigningKey) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims()), nonce: .required("n-123")) }
    }

    func testUnsignedAndSymmetricTokensAreRejected() async {
        let claims = encode(idClaims())
        for alg in ["none", "HS256", "RS256", "ES384", ""] {
            let token = encode(["alg": alg, "kid": "key-1"]) + "." + claims + "." + HCGJWT.base64URLEncode(Data(repeating: 1, count: 64))
            await expect(.unsupportedAlgorithm(alg)) { _ = try await self.verifier.verifyIDToken(token, nonce: .required("n-123")) }
        }
        let unsigned = encode(["alg": "none"]) + "." + claims + "."
        await expect(.unsupportedAlgorithm("none")) { _ = try await self.verifier.verifyIDToken(unsigned, nonce: .required("n-123")) }
        XCTAssertEqual(world.fetches, 0, "no key lookup for an unacceptable algorithm")
    }

    func testSigningKeysUnavailableFailsClosed() async {
        world.publish([signer.jwk()], status: 503)
        await expect(.keysUnavailable("HTTP 503")) { _ = try await self.verifier.verifyAccessToken(self.signer.sign(self.accessClaims())) }
        world.goOffline()
        await expect(.keysUnavailable("network")) { _ = try await self.verifier.verifyAccessToken(self.signer.sign(self.accessClaims())) }
    }

    func testMalformedTokensAreRejected() async {
        let good = signer.sign(idClaims())
        let parts = good.split(separator: ".").map(String.init)
        let cases = [
            parts[0] + "." + parts[1],                                  // two parts
            good + ".x",                                                // four parts
            "%%%." + parts[1] + "." + parts[2],                         // header not base64url
            parts[0] + "." + parts[1] + "." + parts[2] + "==",          // padded signature
            parts[0] + "." + parts[1] + "." + HCGJWT.base64URLEncode(Data(repeating: 1, count: 63)), // short signature
            parts[0] + "." + String(repeating: "A", count: HCGJWT.maximumLength) + "." + parts[2],  // oversized
        ]
        for token in cases {
            await expect(.malformed) { _ = try await self.verifier.verifyIDToken(token, nonce: .required("n-123")) }
        }
    }

    // MARK: claims

    func testIssuerMustMatchExactly() async {
        for iss in [issuer + "/", "https://evil.example/auth/v1", "http://qggdyzoydveafkmjgkpq.supabase.co/auth/v1"] {
            await expect(.wrongIssuer) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["iss": iss])), nonce: .required("n-123")) }
        }
        await expect(.wrongIssuer) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["iss": nil])), nonce: .required("n-123")) }
    }

    func testIDTokenAudienceMustBeThisApp() async throws {
        await expect(.wrongAudience) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["aud": "af487795-ead1-4671-8b09-76301762ee2c"])), nonce: .required("n-123")) }
        await expect(.wrongAudience) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["aud": nil])), nonce: .required("n-123")) }
        // Several audiences need azp == this client; azp naming another client is refused.
        await expect(.wrongClient) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["aud": [client, "other"]])), nonce: .required("n-123")) }
        await expect(.wrongClient) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["azp": "other"])), nonce: .required("n-123")) }
        _ = try await verifier.verifyIDToken(signer.sign(idClaims(["aud": [client, "other"], "azp": client])), nonce: .required("n-123"))
    }

    func testExpiryIsRequiredAndEnforcedWithLeeway() async throws {
        await expect(.missingExpiry) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["exp": nil])), nonce: .required("n-123")) }
        await expect(.missingExpiry) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["exp": "never"])), nonce: .required("n-123")) }
        await expect(.expired) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["exp": self.t - 61])), nonce: .required("n-123")) }
        _ = try await verifier.verifyIDToken(signer.sign(idClaims(["exp": t - 30])), nonce: .required("n-123")) // within 60 s leeway
        let token = signer.sign(accessClaims(["exp": t + 10]))
        _ = try await verifier.verifyAccessToken(token)
        world.advance(71)
        await expect(.expired) { _ = try await self.verifier.verifyAccessToken(token) }
    }

    func testNotBeforeAndIssuedAtInTheFutureAreRejected() async {
        await expect(.notYetValid) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["nbf": self.t + 120])), nonce: .required("n-123")) }
        await expect(.issuedInFuture) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["iat": self.t + 120])), nonce: .required("n-123")) }
    }

    func testSubjectMustBeAnAccountUUID() async {
        for sub in ["", "admin", "0f8fad5b-d9cb-469f-a165-70867728950", "0f8fad5bxd9cb-469f-a165-70867728950e"] {
            await expect(.invalidSubject) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["sub": sub])), nonce: .required("n-123")) }
        }
        await expect(.invalidSubject) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["sub": nil])), nonce: .required("n-123")) }
    }

    func testNonceBindsTheIDTokenToThisSignIn() async throws {
        await expect(.nonceMismatch) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims()), nonce: .required("n-other")) }
        await expect(.missingNonce) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["nonce": nil])), nonce: .required("n-123")) }
        await expect(.nonceMismatch) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims(["nonce": ""])), nonce: .required("")) }
        // Refresh: a nonce, when present, must be the original one; an absent nonce is allowed.
        await expect(.nonceMismatch) { _ = try await self.verifier.verifyIDToken(self.signer.sign(self.idClaims()), nonce: .matchIfPresent("n-original")) }
        _ = try await verifier.verifyIDToken(signer.sign(idClaims(["nonce": nil])), nonce: .matchIfPresent("n-original"))
        _ = try await verifier.verifyIDToken(signer.sign(idClaims()), nonce: .matchIfPresent("n-123"))
    }

    func testAccessTokenMustBeAUserTokenForThisApp() async {
        await expect(.wrongClient) { _ = try await self.verifier.verifyAccessToken(self.signer.sign(self.accessClaims(["client_id": "94e51fe2-ba09-426d-8b41-8d36bf0dcac5"]))) }
        await expect(.wrongClient) { _ = try await self.verifier.verifyAccessToken(self.signer.sign(self.accessClaims(["client_id": nil]))) }
        await expect(.notAUserAccessToken) { _ = try await self.verifier.verifyAccessToken(self.signer.sign(self.accessClaims(["aud": "anon"]))) }
        await expect(.notAUserAccessToken) { _ = try await self.verifier.verifyAccessToken(self.signer.sign(self.accessClaims(["role": "service_role"]))) }
        // An ID token is not an access token.
        await expect(.notAUserAccessToken) { _ = try await self.verifier.verifyAccessToken(self.signer.sign(self.idClaims())) }
    }

    // MARK: token responses

    private func response(access: String?, id: String?) -> Data {
        var body: [String: Any] = ["token_type": "bearer", "expires_in": 3600, "refresh_token": "r-1"]
        if let access = access { body["access_token"] = access }
        if let id = id { body["id_token"] = id }
        return try! JSONSerialization.data(withJSONObject: body)
    }

    func testSignInResponseNeedsBothVerifiedTokensForOneAccount() async throws {
        let access = signer.sign(accessClaims()), id = signer.sign(idClaims())
        let ok = try await verifier.verifyTokenResponse(response(access: access, id: id), grantType: "authorization_code", nonce: .required("n-123"))
        XCTAssertEqual(ok.subject, subject)
        await expect(.missingToken("ID token")) { _ = try await self.verifier.verifyTokenResponse(self.response(access: access, id: nil), grantType: "authorization_code", nonce: .required("n-123")) }
        await expect(.missingToken("access token")) { _ = try await self.verifier.verifyTokenResponse(self.response(access: nil, id: id), grantType: "authorization_code", nonce: .required("n-123")) }
        let otherAccount = signer.sign(idClaims(["sub": "6f1c7a1e-0000-4000-8000-000000000000"]))
        await expect(.subjectMismatch) { _ = try await self.verifier.verifyTokenResponse(self.response(access: access, id: otherAccount), grantType: "authorization_code", nonce: .required("n-123")) }
        let forgedID = Signer(kid: "key-1").sign(idClaims())
        await expect(.invalidSignature) { _ = try await self.verifier.verifyTokenResponse(self.response(access: access, id: forgedID), grantType: "authorization_code", nonce: .required("n-123")) }
        await expect(.malformed) { _ = try await self.verifier.verifyTokenResponse(Data("not json".utf8), grantType: "authorization_code", nonce: .required("n-123")) }
    }

    func testRefreshResponseVerifiesTheAccessTokenAndAnyIDToken() async throws {
        _ = try await verifier.verifyTokenResponse(response(access: signer.sign(accessClaims()), id: nil), grantType: "refresh_token", nonce: .matchIfPresent(nil))
        let forgedAccess = Signer(kid: "key-1").sign(accessClaims())
        await expect(.invalidSignature) { _ = try await self.verifier.verifyTokenResponse(self.response(access: forgedAccess, id: nil), grantType: "refresh_token", nonce: .matchIfPresent(nil)) }
    }

    // MARK: configuration

    func testTrustAnchorsMustBeHTTPSOnTheIssuersHost() {
        XCTAssertNil(HCGConnectTrust(issuer: issuer, clientId: nil))
        XCTAssertNil(HCGConnectTrust(issuer: issuer, clientId: ""))
        XCTAssertNil(HCGConnectTrust(issuer: "http://qggdyzoydveafkmjgkpq.supabase.co/auth/v1", clientId: client))
        XCTAssertNil(HCGConnectTrust(issuer: issuer, clientId: client, jwksURL: URL(string: "https://keys.example/jwks.json")!))
        XCTAssertNil(HCGConnectTrust(issuer: issuer + "?x=1", clientId: client))
        let trust = HCGConnectTrust(issuer: issuer, clientId: client)
        XCTAssertEqual(trust?.jwksURL.absoluteString, issuer + "/.well-known/jwks.json")
        XCTAssertEqual(trust?.leeway, 60)
    }

    func testGrantTypeIsReadFromTheFormBody() {
        XCTAssertEqual(HCGConnectTokenVerifier.grantType(ofFormBody: Data("client_id=a&code=b&grant_type=authorization_code".utf8)), "authorization_code")
        XCTAssertEqual(HCGConnectTokenVerifier.grantType(ofFormBody: Data("grant_type=refresh_token&refresh_token=x".utf8)), "refresh_token")
        XCTAssertNil(HCGConnectTokenVerifier.grantType(ofFormBody: Data("code=b".utf8)))
        XCTAssertNil(HCGConnectTokenVerifier.grantType(ofFormBody: nil))
    }
}
