import Foundation

/// Lee la fecha de caducidad del perfil `embedded.mobileprovision` que Sideloadly o AltStore
/// incluyen al firmar la app. El archivo es un contenedor CMS firmado que envuelve un plist XML;
/// basta con extraer ese plist, sin validar la firma, porque solo se usa para avisar al usuario.
public enum ProvisioningProfileParser {
    private static let plistStart = Data("<?xml".utf8)
    private static let plistEnd = Data("</plist>".utf8)
    /// Un perfil real ocupa unos pocos kilobytes; se descarta cualquier archivo desproporcionado.
    private static let maximumProfileSize = 1024 * 1024

    public static func expirationDate(from data: Data) -> Date? {
        guard data.count <= maximumProfileSize,
              let start = data.range(of: plistStart)?.lowerBound,
              let end = data.range(of: plistEnd, in: start..<data.endIndex)?.upperBound else { return nil }

        let plistData = data.subdata(in: start..<end)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil),
              let dictionary = plist as? [String: Any] else { return nil }
        return dictionary["ExpirationDate"] as? Date
    }
}
