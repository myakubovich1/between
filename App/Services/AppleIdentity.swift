import Foundation
import AuthenticationServices
import CryptoKit
import Security
import Supabase

@MainActor
extension AppStore {
    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { error = "Couldn’t start a secure sign-in. Try again."; return }
        let nonce = Data(bytes).base64EncodedString()
        appleNonce = nonce
        request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
        request.requestedScopes = []
    }
    func completeApple(_ result: Result<ASAuthorization, Error>, deleting: Bool = false) async {
        self.error = nil
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                  let nonce = appleNonce, let live else { throw AppFailure.message("Sign-in needs the live backend configuration.") }
            if deleting {
                struct DeleteBody: Encodable { var authorizationCode: String }
                guard let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }) else { throw AppFailure.message("Apple did not return an authorization code. Try again.") }
                let _: EmptyResponse = try await live.request("account", method: "DELETE", body: JSONEncoder.between.encode(DeleteBody(authorizationCode: code)), authenticated: true)
                try? await live.client.auth.signOut(scope: .local)
                signedIn = false
                myReports = []
                evidence = []
                try await cache.clear()
                UserDefaults.standard.removeObject(forKey: "between.appleUser")
                notice = "Your account and contributions were deleted."
            } else {
                _ = try await live.client.auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: token, nonce: nonce))
                UserDefaults.standard.set(credential.user, forKey: "between.appleUser")
                signedIn = true
                await refresh()
            }
        } catch let authError as ASAuthorizationError where authError.code == .canceled {
            // The report's @State choices remain intact.
        } catch { self.error = error.localizedDescription }
        appleNonce = nil
    }
    func checkAppleCredential() async {
        guard !config.isDemo, let user = UserDefaults.standard.string(forKey: "between.appleUser"), let live else { return }
        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: user)
            if state == .revoked || state == .notFound { try? await live.client.auth.signOut(scope: .local); signedIn = false; error = "Apple sign-in was revoked. Sign in again to report." }
        } catch { /* Offline credential checks do not discard a valid local session. */ }
    }
}
struct EmptyResponse: Codable, Sendable { var ok: Bool }
