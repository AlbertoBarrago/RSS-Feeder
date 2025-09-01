//
//  RSSReaderApp.swift
//  RSSReader
//
//  Created by Alberto Barrago on 2025.
//

import SwiftUI
import AppKit
import SwiftData

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
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 600)
                .background(Color(.windowBackgroundColor))
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(modelContainer)
    }
}

// MARK: - AppDelegate for Menubar Integration
class AppDelegate: NSObject, NSApplicationDelegate {
    var menubarController: MenubarController!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        menubarController = MenubarController()
    }
}

// MARK: - Menubar Controller
@MainActor
class MenubarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    
    private var modelContainer: ModelContainer
    private var modelContext: ModelContext

    override init() {
        do {
            modelContainer = try ModelContainer(for: RSSFeedItem.self, RSSFeedSource.self)
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create MenubarController ModelContainer: \(error)")
        }
        
        super.init()

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "RSS Reader")
            button.action = nil
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        
        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.contentSize = NSSize(width: 400, height: 500)
        self.popover.contentViewController = NSHostingController(rootView: ContentView().environment(\.modelContext, modelContext))

        let menu = NSMenu()
        
        let showHideItem = NSMenuItem(title: "Show/Hide Reader", action: #selector(togglePopover), keyEquivalent: "")
        showHideItem.target = self
        menu.addItem(showHideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = NSMenuItem(title: "About RSS Reader", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let quitItem = NSMenuItem(title: "Quit RSS Reader", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        self.statusItem.menu = menu
    }
    
    // Presents the About panel with your custom info.
    @objc func showAboutPanel() {
        let creditsString = """
        Developed by: Alberto Barrago 👨‍💻
        Role: Fullstack, Devops & AI Researcher
        """
        
        let credits = NSAttributedString(
            string: creditsString,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor
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
                    y: button.bounds.minY - 5,
                    width: button.bounds.width,
                    height: button.bounds.height
                )
                self.popover.show(relativeTo: adjustedBounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
