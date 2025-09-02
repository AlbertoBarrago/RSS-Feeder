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
    }
}

/// MARK: - Menubar Controller
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
            
            button.action = #selector(handleButtonClick)
            button.target = self
            
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.contentSize = NSSize(width: 800, height: 600)
        self.popover.contentViewController = NSHostingController(rootView: ContentView().environment(\.modelContext, modelContext))
        
        NSApp.setActivationPolicy(.accessory)
    }
    
    @objc private func handleButtonClick() {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                // Right-click: Show the menu
                showRightClickMenu()
            } else if event.type == .leftMouseUp {
                // Left-click: Toggle the popover
                togglePopover(self)
            }
        }
    }

    
    private func showRightClickMenu() {
        guard let button = self.statusItem.button else { return }
        
        let menu = NSMenu()
        
        let aboutItem = NSMenuItem(title: "About RSS Reader", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        let isDockHidden = NSApp.activationPolicy() == .accessory
        let toggleTitle = isDockHidden ? "Show in Dock" : "Hide from Dock"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleDockVisibility), keyEquivalent: "h")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let quitItem = NSMenuItem(title: "Quit RSS Reader", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
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
                    y: button.bounds.minY,
                    width: button.bounds.width,
                    height: button.bounds.height
                )
                self.popover.show(relativeTo: adjustedBounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
