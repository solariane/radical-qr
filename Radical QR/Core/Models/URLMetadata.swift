import Foundation

/// Enriched metadata for URL-type QR inputs
struct URLMetadata: Sendable, Hashable {
    enum URLCategory: String, Sendable, Hashable {
        case website
        case socialProfile
        case deepLink
    }

    let category: URLCategory
    let platform: String
    let handle: String?
    let displayLabel: String
    let iconName: String
}

// MARK: - URL Metadata Extraction

/// Extracts rich metadata (social profiles, deep links) from URLs
enum URLMetadataExtractor {

    // MARK: - Public API

    /// Extracts metadata from a URL string, returning nil for generic websites
    static func extract(from urlString: String) -> URLMetadata? {
        let normalized = urlString.lowercased().hasPrefix("http") ? urlString : "https://\(urlString)"
        guard let url = URL(string: normalized), let host = url.host?.lowercased() else {
            return nil
        }

        // Check social profiles
        for platform in socialPlatforms {
            if platform.domains.contains(host) {
                let handle = platform.handleExtractor(url)
                return URLMetadata(
                    category: .socialProfile,
                    platform: platform.name,
                    handle: handle,
                    displayLabel: handle ?? platform.name,
                    iconName: platform.icon
                )
            }
        }

        // Check deep links / app links
        for platform in appPlatforms {
            if platform.domains.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
                let label = platform.labelExtractor(url)
                return URLMetadata(
                    category: .deepLink,
                    platform: platform.name,
                    handle: nil,
                    displayLabel: label ?? platform.name,
                    iconName: platform.icon
                )
            }
        }

        return nil
    }

    // MARK: - Social Platform Definitions

    private struct SocialPlatform {
        let domains: [String]
        let name: String
        let icon: String
        let handleExtractor: @Sendable (URL) -> String?
    }

    private static let socialPlatforms: [SocialPlatform] = [
        SocialPlatform(
            domains: ["instagram.com", "www.instagram.com"],
            name: "Instagram",
            icon: "camera",
            handleExtractor: { url in
                extractPathHandle(from: url, excluding: ["p", "reel", "reels", "stories", "explore", "accounts", "about", "legal"])
            }
        ),
        SocialPlatform(
            domains: ["twitter.com", "www.twitter.com", "x.com", "www.x.com"],
            name: "X (Twitter)",
            icon: "at",
            handleExtractor: { url in
                extractPathHandle(from: url, excluding: ["search", "explore", "settings", "home", "i", "tos", "privacy"])
            }
        ),
        SocialPlatform(
            domains: ["linkedin.com", "www.linkedin.com"],
            name: "LinkedIn",
            icon: "briefcase",
            handleExtractor: { url in
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard path.hasPrefix("in/") else { return nil }
                return String(path.dropFirst(3)).split(separator: "/").first.map(String.init)
            }
        ),
        SocialPlatform(
            domains: ["facebook.com", "www.facebook.com", "fb.com", "www.fb.com"],
            name: "Facebook",
            icon: "person.2",
            handleExtractor: { url in
                extractPathHandle(from: url, excluding: ["groups", "events", "pages", "marketplace", "watch", "gaming", "help", "settings", "login"])
            }
        ),
        SocialPlatform(
            domains: ["tiktok.com", "www.tiktok.com"],
            name: "TikTok",
            icon: "music.note",
            handleExtractor: { url in
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard let first = path.split(separator: "/").first, String(first).hasPrefix("@") else { return nil }
                return String(first)
            }
        ),
        SocialPlatform(
            domains: ["snapchat.com", "www.snapchat.com"],
            name: "Snapchat",
            icon: "camera.viewfinder",
            handleExtractor: { url in
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard path.hasPrefix("add/") else { return nil }
                return path.dropFirst(4).split(separator: "/").first.map(String.init)
            }
        ),
        SocialPlatform(
            domains: ["github.com", "www.github.com"],
            name: "GitHub",
            icon: "chevron.left.forwardslash.chevron.right",
            handleExtractor: { url in
                extractPathHandle(from: url, excluding: ["orgs", "explore", "marketplace", "settings", "notifications", "features", "pricing", "login", "join"])
            }
        ),
        SocialPlatform(
            domains: ["youtube.com", "www.youtube.com"],
            name: "YouTube",
            icon: "play.rectangle",
            handleExtractor: { url in
                let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if path.hasPrefix("@") {
                    return path.split(separator: "/").first.map(String.init)
                }
                if path.hasPrefix("c/") || path.hasPrefix("channel/") {
                    return path.split(separator: "/").dropFirst().first.map(String.init)
                }
                return nil
            }
        ),
    ]

    // MARK: - App / Deep Link Definitions

    private struct AppPlatform {
        let domains: [String]
        let name: String
        let icon: String
        let labelExtractor: @Sendable (URL) -> String?
    }

    private static let appPlatforms: [AppPlatform] = [
        AppPlatform(
            domains: ["zoom.us"],
            name: "Zoom",
            icon: "video",
            labelExtractor: { url in
                if url.path.contains("/j/") {
                    return url.path.split(separator: "/").last.map { "Meeting: \($0)" }
                }
                return nil
            }
        ),
        AppPlatform(
            domains: ["teams.microsoft.com"],
            name: "Microsoft Teams",
            icon: "person.3",
            labelExtractor: { _ in "Teams Meeting" }
        ),
        AppPlatform(
            domains: ["open.spotify.com"],
            name: "Spotify",
            icon: "music.note.list",
            labelExtractor: { url in
                let segments = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).split(separator: "/")
                guard let first = segments.first else { return nil }
                return String(first).capitalized
            }
        ),
        AppPlatform(
            domains: ["maps.apple.com"],
            name: "Apple Maps",
            icon: "map",
            labelExtractor: { _ in "Location" }
        ),
        AppPlatform(
            domains: ["maps.google.com", "google.com/maps", "goo.gl"],
            name: "Google Maps",
            icon: "map",
            labelExtractor: { _ in "Location" }
        ),
        AppPlatform(
            domains: ["meet.google.com"],
            name: "Google Meet",
            icon: "video",
            labelExtractor: { url in
                let code = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return code.isEmpty ? nil : "Meeting: \(code)"
            }
        ),
    ]

    // MARK: - Helpers

    /// Extracts the first path component as a handle, excluding known non-profile paths
    private nonisolated static func extractPathHandle(from url: URL, excluding: [String]) -> String? {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let first = path.split(separator: "/").first else { return nil }
        let segment = String(first)
        guard !excluding.contains(segment.lowercased()) else { return nil }
        guard !segment.isEmpty else { return nil }
        return segment.hasPrefix("@") ? segment : "@\(segment)"
    }
}
