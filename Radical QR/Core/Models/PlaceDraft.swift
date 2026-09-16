import Foundation

/// An address the user can still edit, and the Apple Maps link it encodes.
///
/// The link carries the address as written — nothing is geocoded on the device,
/// so nothing leaves it. Scanning opens Maps on an iPhone and Apple Maps on the
/// web elsewhere, which look the address up themselves.
nonisolated struct PlaceDraft: Equatable, Sendable {
    var address: String

    static let mapsHost = "maps.apple.com"

    var mapsURL: String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.mapsHost
        components.path = "/"
        components.queryItems = [URLQueryItem(name: "address", value: address.trimmingCharacters(in: .whitespacesAndNewlines))]
        // URLComponents leaves "," and "&"-free text readable; spaces become %20.
        return components.string ?? "https://\(Self.mapsHost)/"
    }

    init(address: String) {
        self.address = address
    }

    /// Reads back a link this form could have written: maps.apple.com with an
    /// `address` and nothing else. A link with coordinates or a search keeps
    /// its own meaning and is not turned into an address.
    init?(mapsURL: String) {
        guard let components = URLComponents(string: mapsURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.host?.lowercased() == Self.mapsHost,
              let items = components.queryItems, items.count == 1,
              items[0].name == "address",
              let address = items[0].value, !address.isEmpty else { return nil }
        self.address = address
    }
}
