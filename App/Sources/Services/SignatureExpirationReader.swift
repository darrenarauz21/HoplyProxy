import Foundation
import ProxyConfig

/// Lee la caducidad de la firma desde el perfil incluido en la app.
enum SignatureExpirationReader {
    static func expirationDate(in bundle: Bundle = .main) -> Date? {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return nil }
        return ProvisioningProfileParser.expirationDate(from: data)
    }
}
