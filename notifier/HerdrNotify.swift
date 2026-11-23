import AppKit
import UserNotifications

/// Posts one banner per run and turns a click into the focus command. macOS only delivers banners
/// for a bundle started by LaunchServices, so `watch` runs this through `open -n -g <app> --args`.
final class Helper: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  private let args = CommandLine.arguments

  private func opt(_ key: String) -> String? {
    guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
    return args[i + 1]
  }

  private func fail(_ message: String, _ code: Int32) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
  }

  // Set before launch completes: a click that relaunches the app must reach the delegate.
  func applicationWillFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().delegate = self
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    guard args.count > 1, args[1] == "post" else {
      // Relaunched by a click: the response arrives through didReceive, or nothing arrives.
      DispatchQueue.main.asyncAfter(deadline: .now() + 10) { NSApp.terminate(nil) }
      return
    }
    post()
  }

  private func post() {
    // An unanswered permission prompt would hang the watcher's post forever.
    DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
      self.fail("post timed out after 30 s", 4)
    }
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
      guard granted else {
        self.fail("not authorised: \(error.map(String.init(describing:)) ?? "no error")", 2)
      }
      let content = UNMutableNotificationContent()
      content.title = self.opt("--title") ?? "Herdr"
      content.body = self.opt("--body") ?? ""
      content.threadIdentifier = "herdr"
      content.sound = .default

      // The address doubles as the identifier, so a newer banner replaces the older one, and as
      // the argument handed to the focus command on click.
      let address = self.opt("--address") ?? ""
      content.userInfo = ["address": address, "exec": self.opt("--exec") ?? ""]
      let request = UNNotificationRequest(identifier: address.isEmpty ? UUID().uuidString : address,
                                          content: content, trigger: nil)
      center.add(request) { error in
        if let error { self.fail("post failed: \(error)", 3) }
        exit(0)
      }
    }
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completion: @escaping () -> Void) {
    let info = response.notification.request.content.userInfo
    if let exec = info["exec"] as? String, exec.hasPrefix("/"),
       FileManager.default.isExecutableFile(atPath: exec) {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: "/bin/zsh")
      process.arguments = [exec, info["address"] as? String ?? ""]
      do {
        try process.run()
        process.waitUntilExit()
      } catch {
        FileHandle.standardError.write(Data("click: \(error)\n".utf8))
      }
    }
    completion()
    NSApp.terminate(nil)
  }

  // A banner from a helper that happens to be frontmost is still worth showing.
  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                              withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
    completion([.banner, .sound])
  }
}

let app = NSApplication.shared
let helper = Helper()
app.delegate = helper
app.setActivationPolicy(.accessory)
app.run()
