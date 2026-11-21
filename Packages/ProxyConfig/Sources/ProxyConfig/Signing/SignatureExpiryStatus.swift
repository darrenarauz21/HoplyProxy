import Foundation

/// Situación de la firma de la app. Con un Apple ID gratuito la firma dura 7 días;
/// al caducar, iOS no permite abrir la app hasta reinstalarla o renovarla.
public enum SignatureExpiryStatus: Equatable, Sendable {
    /// No hay perfil de aprovisionamiento (por ejemplo, en el simulador).
    case unknown
    case valid(expiresAt: Date)
    /// Queda menos de `warningInterval`.
    case expiringSoon(expiresAt: Date)
    case expired(expiresAt: Date)

    /// Margen del aviso: un día, es decir, al sexto día de una firma de siete.
    public static let warningInterval: TimeInterval = 24 * 60 * 60

    public static func evaluate(expirationDate: Date?, now: Date) -> SignatureExpiryStatus {
        guard let expirationDate else { return .unknown }
        if expirationDate <= now {
            return .expired(expiresAt: expirationDate)
        }
        if expirationDate.timeIntervalSince(now) <= warningInterval {
            return .expiringSoon(expiresAt: expirationDate)
        }
        return .valid(expiresAt: expirationDate)
    }

    /// Momento en que conviene recordar la renovación, o `nil` si ya pasó.
    public static func reminderDate(forExpiration expirationDate: Date, now: Date) -> Date? {
        let reminder = expirationDate.addingTimeInterval(-warningInterval)
        return reminder > now ? reminder : nil
    }

    public var expirationDate: Date? {
        switch self {
        case .unknown:
            return nil
        case .valid(let date), .expiringSoon(let date), .expired(let date):
            return date
        }
    }
}
