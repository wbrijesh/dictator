//
//  DictatorApp.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import SwiftUI
import AppKit

@main
struct DictatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var menuBarController: MenuBarController?
    var hotkeyManager: HotkeyManager?
    var settingsWindowController: SettingsWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.text.bubble.right", accessibilityDescription: "Dictator")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            
            // Add right-click menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create menu
        setupStatusBarMenu()
        
        // Initialize menu bar controller
        menuBarController = MenuBarController()
        
        // Setup global hotkey
        setupGlobalHotkey()
        
        // Check for API key on first launch
        checkAPIKeySetup()
    }
    
    @objc func statusBarButtonClicked() {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Show menu on right click
            statusBarItem?.menu = createMenu()
            statusBarItem?.button?.performClick(nil)
            statusBarItem?.menu = nil
        } else {
            // Toggle recording on left click
            menuBarController?.toggleRecording()
        }
    }
    
    private func setupStatusBarMenu() {
        // Menu will be created dynamically on right-click
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Record item
        let recordItem = NSMenuItem(title: "Start Recording", action: #selector(recordMenuClicked), keyEquivalent: "")
        recordItem.target = self
        menu.addItem(recordItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings item
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsMenuClicked), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // About item
        let aboutItem = NSMenuItem(title: "About Dictator", action: #selector(aboutMenuClicked), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit item
        let quitItem = NSMenuItem(title: "Quit Dictator", action: #selector(quitMenuClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc func recordMenuClicked() {
        menuBarController?.toggleRecording()
    }
    
    @objc func settingsMenuClicked() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(audioRecorder: menuBarController?.audioRecorder)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func aboutMenuClicked() {
        let alert = NSAlert()
        alert.messageText = "Dictator"
        alert.informativeText = "A lightweight speech-to-text app for macOS\n\nHotkey: Cmd+Shift+D\nPowered by OpenAI Whisper"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func quitMenuClicked() {
        NSApplication.shared.terminate(nil)
    }
    
    func setupGlobalHotkey() {
        hotkeyManager = HotkeyManager()
        hotkeyManager?.delegate = self
    }
    
    private func checkAPIKeySetup() {
        if KeychainHelper.getAPIKey() == nil && ProcessInfo.processInfo.environment["OPENAI_API_KEY"] == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.settingsMenuClicked()
            }
        }
    }
}

// MARK: - HotkeyManagerDelegate
extension AppDelegate: HotkeyManagerDelegate {
    func hotkeyPressed() {
        menuBarController?.toggleRecording()
    }
}
