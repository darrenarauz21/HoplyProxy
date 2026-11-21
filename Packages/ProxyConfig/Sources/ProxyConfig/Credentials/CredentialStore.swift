/// Almacenamiento seguro de la contraseña del proxy.
public protocol CredentialStore: AnyObject {
    func loadPassword() throws -> String?
    func savePassword(_ password: String) throws
    func deletePassword() throws
}

public enum CredentialStoreError: Error, Equatable {
    case unexpectedStatus(Int32)
    case invalidData
}
