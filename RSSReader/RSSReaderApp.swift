//
//  RSSReaderApp.swift
//  RSSReader
//
//  Created by Alberto on 2025.
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
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.contentSize = NSSize(width: 400, height: 500)
        
        let contentView = ContentView()
            .environment(\.modelContext, modelContext)
        
        self.popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = self.statusItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                // Simple fix: Add margin to avoid menu bar overlap
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
