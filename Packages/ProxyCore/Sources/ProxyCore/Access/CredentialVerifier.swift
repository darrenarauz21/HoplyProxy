/// Compara las credenciales recibidas con las configuradas en tiempo constante respecto
/// al contenido, para no revelar por temporización cuántos caracteres coinciden.
struct CredentialVerifier {
    private let username: [UInt8]
    private let password: [UInt8]

    init(credentials: ProxyCredentials) {
        username = Array(credentials.username.utf8)
        password = Array(credentials.password.utf8)
    }

    func verify(username candidateUsername: [UInt8], password candidatePassword: [UInt8]) -> Bool {
        let usernameMatches = Self.constantTimeEquals(candidateUsername, username)
        let passwordMatches = Self.constantTimeEquals(candidatePassword, password)
        return usernameMatches && passwordMatches
    }

    static func constantTimeEquals(_ left: [UInt8], _ right: [UInt8]) -> Bool {
        var difference: UInt8 = left.count == right.count ? 0 : 1
        for index in 0..<max(left.count, right.count) {
            let leftByte = index < left.count ? left[index] : 0
            let rightByte = index < right.count ? right[index] : 0
            difference |= leftByte ^ rightByte
        }
        return difference == 0
    }
}
