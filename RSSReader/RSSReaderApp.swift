//
//  RSSReaderApp.swift
//  RSSReader
//
//  Created by Alberto Barrago on 2025.
//

import AppKit
import SwiftData
import SwiftUI
import ServiceManagement
import UserNotifications

// MARK: - Main App Entry Point
@main
struct RSSReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: RSSFeedItem.self, RSSFeedSource.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - AppDelegate for Menubar Integration
class AppDelegate: NSObject, NSApplicationDelegate {
    var menubarController: MenubarController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menubarController = MenubarController()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }
}

/// MARK: - Menubar Controller
@MainActor
class MenubarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let parser = RSSParser()

    private var modelContainer: ModelContainer
    private var modelContext: ModelContext
    @AppStorage("keepOpen") private var keepOpen: Bool = false
    @AppStorage("RunOnStart") private var runOnStart: Bool = false
    @AppStorage("pollingInterval") private var pollingInterval: TimeInterval = 300 // 5 minutes

    private var timer: Timer?


    override init() {
        do {
            modelContainer = try ModelContainer(for: RSSFeedItem.self, RSSFeedSource.self, DeletedArticle.self)
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create MenubarController ModelContainer: \(error)")
        }

        super.init()

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "RSS Reader")

            button.action = #selector(handleButtonClick)
            button.target = self

            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        if runOnStart {
           DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
               self.togglePopover(nil)
           }
        }

        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.contentSize = NSSize(width: 800, height: 600)
        self.popover.contentViewController = NSHostingController(rootView: ContentView().environment(\.modelContext, modelContext))

        NSApp.setActivationPolicy(.accessory)
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate() // Invalidate the old timer before creating a new one
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshFeeds()
            }
        }
    }

    private func refreshFeeds() {
        do {
            let sources = try modelContext.fetch(FetchDescriptor<RSSFeedSource>())
            parser.refreshAllFeeds(sources: sources, in: modelContext) {}
        } catch {
            print("Failed to fetch feed sources: \(error.localizedDescription)")
        }
    }

    @objc private func handleButtonClick() {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                // Right-click: Show the menu
                showRightClickMenu()
            } else if event.type == .leftMouseUp {
                // Left-click: Toggle the popover
                popover.behavior = keepOpen ? .semitransient : .transient
                togglePopover(self)
            }
        }
    }


    private func showRightClickMenu() {
        guard let button = self.statusItem.button else { return }

        let menu = NSMenu()
        let runOnStartItem = NSMenuItem(title: "Run on Start", action: #selector(toggleRunOnStart), keyEquivalent: "")
        runOnStartItem.target = self
        runOnStartItem.state = runOnStart ? .on : .off
        menu.addItem(runOnStartItem)

        menu.addItem(NSMenuItem.separator())

        let pollingMenuItem = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
        pollingMenuItem.submenu = createPollingIntervalMenu()
        menu.addItem(pollingMenuItem)

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About RSS Reader", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit RSS Reader", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    private func createPollingIntervalMenu() -> NSMenu {
        let menu = NSMenu()
        let intervals: [TimeInterval] = [300, 600, 900, 1800] // 5, 10, 15, 30 minutes

        for interval in intervals {
            let menuItem = NSMenuItem(title: "\(Int(interval / 60)) minutes", action: #selector(changePollingInterval(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = interval
            if pollingInterval == interval {
                menuItem.state = .on
            }
            menu.addItem(menuItem)
        }

        return menu
    }
    
    @objc private func toggleRunOnStart() {
        runOnStart.toggle()
        
        if #available(macOS 13.0, *) {
            do {
                if runOnStart {
                    if SMAppService.mainApp.status == .notRegistered {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(runOnStart ? "register" : "unregister") login item: \(error.localizedDescription)")
            }
        } else {
            // Use the deprecated SMLoginItemSetEnabled function on older versions of macOS
            let launcherAppId = "com.example.RSSReaderLauncher"
            if !SMLoginItemSetEnabled(launcherAppId as CFString, runOnStart) {
                print("Failed to \(runOnStart ? "register" : "unregister") login item.")
            }
        }
    }

    @objc private func changePollingInterval(_ sender: NSMenuItem) {
        if let interval = sender.representedObject as? TimeInterval {
            pollingInterval = interval
            startTimer()
        }
    }

    @objc private func toggleKeepOpen() {
        keepOpen.toggle()
    }

    @objc private func toggleDockVisibility() {
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc func showAboutPanel() {
        let creditsString = """
            Developed by: Alberto Barrago
            © 2025 RSS Reader
            """

        let credits = NSAttributedString(
            string: creditsString,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor,
            ]
        )

        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "RSS Reader",
                .credits: credits,
            ]
        )
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = self.statusItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                let adjustedBounds = NSRect(
                    x: button.bounds.minX,
                    y: button.bounds.minY,
                    width: button.bounds.width,
                    height: button.bounds.height
                )
                self.popover.show(relativeTo: adjustedBounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
