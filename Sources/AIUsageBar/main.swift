import Foundation

switch CommandLine.arguments.dropFirst().first {
case "--statusline":
    CLI.runStatusLine()
case "--install-hook":
    CLI.installHook()
case "--uninstall-hook":
    CLI.uninstallHook()
default:
    AIUsageBarApp.main()
}
