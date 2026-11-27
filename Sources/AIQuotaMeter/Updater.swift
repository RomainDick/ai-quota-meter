import AppKit
import CryptoKit
import Foundation

struct AppVersion: Comparable {
    let parts: [Int]

    init?(_ value: String) {
        let trimmed = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = trimmed.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        self.parts = parts.compactMap { $0 }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        let left = lhs.parts + Array(repeating: 0, count: count - lhs.parts.count)
        let right = rhs.parts + Array(repeating: 0, count: count - rhs.parts.count)
        return left.lexicographicallyPrecedes(right)
    }
}

struct ReleaseInfo: Equatable {
    let version: String
    let pageURL: URL
    let zipURL: URL
    let checksumURL: URL
}

enum UpdateError: LocalizedError {
    case badResponse(Int)
    case missingAsset
    case checksumMismatch
    case invalidBundle
    case extraction

    var errorDescription: String? {
        switch self {
        case .badResponse(let code): return "GitHub a répondu \(code)"
        case .missingAsset: return "Dernière release introuvable sur GitHub"
        case .checksumMismatch: return "Somme de contrôle invalide, mise à jour annulée"
        case .invalidBundle: return "L'archive téléchargée ne contient pas la bonne application"
        case .extraction: return "Décompression de l'archive impossible"
        }
    }
}

enum Updater {
    static let repository = "RomainDick/ai-quota-meter"
    private static let archiveName = "AIQuotaMeter.zip"
    private static let checksumName = "AIQuotaMeter.zip.sha256"
    private static let requestTimeout: TimeInterval = 30

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var canSelfUpdate: Bool {
        AppLocation.canHostHook && FileManager.default.isWritableFile(atPath: AppLocation.bundleURL.deletingLastPathComponent().path)
    }

    static func isNewer(_ release: ReleaseInfo) -> Bool {
        guard let latest = AppVersion(release.version), let current = AppVersion(currentVersion) else { return false }
        return latest > current
    }

    static func latestRelease() async throws -> ReleaseInfo {
        let base = "https://github.com/\(repository)/releases"
        var request = URLRequest(url: URL(string: "\(base)/latest")!)
        request.httpMethod = "HEAD"
        request.setValue("AIQuotaMeter", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = requestTimeout
        let (_, response) = try await URLSession.shared.data(for: request)
        try check(response)

        guard let page = response.url,
              page.pathComponents.dropLast().last == "tag",
              AppVersion(page.lastPathComponent) != nil else { throw UpdateError.missingAsset }
        let tag = page.lastPathComponent
        let download = "\(base)/download/\(tag)"
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return ReleaseInfo(
            version: version,
            pageURL: page,
            zipURL: URL(string: "\(download)/\(archiveName)")!,
            checksumURL: URL(string: "\(download)/\(checksumName)")!
        )
    }

    static func install(_ release: ReleaseInfo, into target: URL) async throws {
        let manager = FileManager.default
        let work = manager.temporaryDirectory.appendingPathComponent("ai-quota-meter-update-\(UUID().uuidString)")
        try manager.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: work) }

        let (downloaded, response) = try await URLSession.shared.download(from: release.zipURL)
        try check(response)
        let archive = work.appendingPathComponent(archiveName)
        try manager.moveItem(at: downloaded, to: archive)

        let (checksumData, checksumResponse) = try await URLSession.shared.data(from: release.checksumURL)
        try check(checksumResponse)
        let expected = String(decoding: checksumData, as: UTF8.self).split(separator: " ").first.map { $0.lowercased() }
        let actual = SHA256.hash(data: try Data(contentsOf: archive, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
        guard expected == actual else { throw UpdateError.checksumMismatch }

        let extracted = work.appendingPathComponent("extracted")
        guard run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path]) else { throw UpdateError.extraction }
        let contents = (try? manager.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil)) ?? []
        guard let app = contents.first(where: { $0.pathExtension == "app" }),
              let bundle = Bundle(url: app),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.infoDictionary?["CFBundleShortVersionString"] as? String == release.version else {
            throw UpdateError.invalidBundle
        }

        _ = try manager.replaceItemAt(target, withItemAt: app)
        AppLocation.removeQuarantine(target)
    }

    static func relaunch(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", url.path]
        try? process.run()
    }

    private static func check(_ response: URLResponse) throws {
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw UpdateError.badResponse(code) }
    }

    private static func run(_ executable: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
