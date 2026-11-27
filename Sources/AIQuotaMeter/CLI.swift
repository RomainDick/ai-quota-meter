import AppKit

enum CLI {
    static func runStatusLine() {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let object = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]
        writeSnapshot(from: object)

        var output = ""
        if let previous = HookManager.previousCommand() {
            output = runPrevious(command: previous, input: input)
        } else if let limits = object["rate_limits"] as? [String: Any],
                  let five = percent(limits["five_hour"]), let week = percent(limits["seven_day"]) {
            output = "5h \(five)% · 7j \(week)%"
        }
        print(output)
    }

    static func installHook() {
        guard let executable = Bundle.main.executablePath else { fail("Chemin de l'exécutable introuvable") }
        do {
            if let preserved = try HookManager.install(executable: executable) {
                print("statusLine existante conservée et chaînée : \(preserved)")
            }
            print("Hook statusLine installé dans \(AppPaths.settingsURL.path)")
        } catch {
            fail(error.localizedDescription)
        }
    }

    static func uninstallHook() {
        do {
            try HookManager.uninstall()
            print("Hook statusLine retiré")
        } catch {
            fail(error.localizedDescription)
        }
    }

    static func update() {
        let done = DispatchSemaphore(value: 0)
        var status: Int32 = 0
        Task {
            do {
                let release = try await Updater.latestRelease()
                if Updater.isNewer(release) {
                    let target = AppLocation.bundleURL
                    print("Mise à jour \(Updater.currentVersion) → \(release.version)")
                    try await Updater.install(release, into: target)
                    let running = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
                        .filter { $0.bundleURL?.standardizedFileURL == target.standardizedFileURL }
                    if !running.isEmpty {
                        running.forEach { $0.terminate() }
                        Updater.relaunch(target)
                    }
                    print("Version \(release.version) installée dans \(target.path)")
                } else {
                    print("Déjà à jour (\(Updater.currentVersion))")
                }
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                status = 1
            }
            done.signal()
        }
        done.wait()
        exit(status)
    }

    private static func percent(_ raw: Any?) -> Int? {
        guard let value = (raw as? [String: Any])?["used_percentage"] as? NSNumber else { return nil }
        return Int(value.doubleValue.rounded(.down))
    }

    private static func writeSnapshot(from object: [String: Any]) {
        let limits = object["rate_limits"] as? [String: Any]
        let model = object["model"] as? [String: Any]
        var snapshot: [String: Any] = ["updatedAt": Date().timeIntervalSince1970]
        if let id = object["session_id"] { snapshot["sessionId"] = id }
        if let name = model?["display_name"] ?? model?["id"] { snapshot["model"] = name }
        if let five = limits?["five_hour"] { snapshot["fiveHour"] = five }
        if let week = limits?["seven_day"] { snapshot["sevenDay"] = week }
        guard let data = try? JSONSerialization.data(withJSONObject: snapshot) else { return }
        try? FileManager.default.createDirectory(at: AppPaths.supportDir, withIntermediateDirectories: true)
        try? data.write(to: AppPaths.snapshotURL, options: .atomic)
    }

    private static func runPrevious(command: String, input: Data) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        guard (try? process.run()) != nil else { return "" }
        stdin.fileHandleForWriting.write(input)
        try? stdin.fileHandleForWriting.close()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .newlines) ?? ""
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
