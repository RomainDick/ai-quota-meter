import AppKit

enum AppLocation {
    private typealias OriginalPathFunction = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
    private static let securityFramework = "/System/Library/Frameworks/Security.framework/Security"

    static var bundleURL: URL { Bundle.main.bundleURL }
    static var isBundled: Bool { bundleURL.pathExtension == "app" }
    static var isTranslocated: Bool { bundleURL.path.contains("/AppTranslocation/") }
    static var canHostHook: Bool { isBundled && !isTranslocated }
    static var destination: URL { AppPaths.userApplications.appendingPathComponent(bundleURL.lastPathComponent) }

    static var isInApplications: Bool {
        let path = bundleURL.resolvingSymlinksInPath().path
        return path.hasPrefix("/Applications/") || path.hasPrefix(AppPaths.userApplications.path + "/")
    }

    static var originalURL: URL {
        guard isTranslocated,
              let handle = dlopen(securityFramework, RTLD_LAZY),
              let symbol = dlsym(handle, "SecTranslocateCreateOriginalPathForURL") else { return bundleURL }
        let function = unsafeBitCast(symbol, to: OriginalPathFunction.self)
        return function(bundleURL as CFURL, nil)?.takeRetainedValue() as URL? ?? bundleURL
    }

    static func moveToApplications() throws -> URL {
        let manager = FileManager.default
        let original = originalURL
        let target = destination
        try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if manager.fileExists(atPath: target.path) {
            try manager.removeItem(at: target)
        }
        try manager.copyItem(at: bundleURL, to: target)
        removeQuarantine(target)
        if original.standardizedFileURL != target.standardizedFileURL {
            try? manager.trashItem(at: original, resultingItemURL: nil)
        }
        return target
    }

    static func relaunch(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    static func moveToTrash() {
        try? FileManager.default.trashItem(at: originalURL, resultingItemURL: nil)
    }

    static let legacyNames = ["AIUsageBar.app"]

    static func removeLegacyCopies() {
        let current = bundleURL.standardizedFileURL
        let folders = [AppPaths.userApplications, URL(fileURLWithPath: "/Applications")]
        for running in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        where running.bundleURL?.standardizedFileURL != current {
            running.terminate()
        }
        for folder in folders {
            for name in legacyNames {
                let url = folder.appendingPathComponent(name)
                guard url.standardizedFileURL != current, FileManager.default.fileExists(atPath: url.path) else { continue }
                try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
        }
    }

    static func removeQuarantine(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", url.path]
        try? process.run()
        process.waitUntilExit()
    }
}
