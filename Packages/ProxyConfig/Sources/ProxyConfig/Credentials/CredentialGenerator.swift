/// Genera credenciales aleatorias. En plataformas Apple `SystemRandomNumberGenerator`
/// usa el generador criptográfico del sistema.
public enum CredentialGenerator {
    /// Sin caracteres ambiguos (0/O, 1/l/I) para facilitar copiarlas a mano.
    private static let passwordAlphabet = Array("abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    private static let usernameAlphabet = Array("abcdefghijkmnpqrstuvwxyz23456789")
    private static let usernamePrefix = "tp-"

    public static func makeUsername() -> String {
        usernamePrefix + randomString(length: 6, alphabet: usernameAlphabet)
    }

    public static func makePassword(length: Int = 20) -> String {
        let clampedLength = min(max(length, ProxySettingsValidator.passwordLengthRange.lowerBound),
                                ProxySettingsValidator.passwordLengthRange.upperBound)
        return randomString(length: clampedLength, alphabet: passwordAlphabet)
    }

    private static func randomString(length: Int, alphabet: [Character]) -> String {
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in alphabet.randomElement(using: &generator) ?? "x" })
    }
}
