
import AppKit
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
<<<<<<< HEAD
        let mainAppIdentifier = "com.example.RSSReader"
||||||| 6e6c5d8
=======
        let mainAppIdentifier = "com.albz.RSSReader"
>>>>>>> develop
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty

        if !isRunning {
            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast()
            components.removeLast()
            components.removeLast()
            components.append("MacOS")
            components.append("RSSReader")

            let newPath = NSString.path(withComponents: components)

            NSWorkspace.shared.launchApplication(newPath)
        }
        else {
            os_log("RSSReader is already running")
        }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
