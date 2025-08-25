//
//  SettingsWindowController.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import AppKit
import AVFoundation

class SettingsWindowController: NSWindowController {
    
    // UI Elements
    private var microphonePopup: NSPopUpButton!
    private var modelPopup: NSPopUpButton!
    private var apiKeyField: NSSecureTextField!
    private var saveButton: NSButton!
    private var cancelButton: NSButton!
    
    // Data
    private var availableDevices: [AudioDevice] = []
    private var audioRecorder: AudioRecorder?
    
    init(audioRecorder: AudioRecorder?) {
        self.audioRecorder = audioRecorder
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        setupUI()
        loadSettings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        // Microphone section
        let micLabel = NSTextField(labelWithString: "Microphone:")
        micLabel.frame = NSRect(x: 20, y: 220, width: 100, height: 20)
        micLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(micLabel)
        
        microphonePopup = NSPopUpButton(frame: NSRect(x: 20, y: 190, width: 360, height: 26))
        microphonePopup.target = self
        microphonePopup.action = #selector(microphoneChanged)
        contentView.addSubview(microphonePopup)
        
        // Model section
        let modelLabel = NSTextField(labelWithString: "Transcription Model:")
        modelLabel.frame = NSRect(x: 20, y: 160, width: 150, height: 20)
        modelLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(modelLabel)
        
        modelPopup = NSPopUpButton(frame: NSRect(x: 20, y: 130, width: 360, height: 26))
        modelPopup.addItem(withTitle: "gpt-4o-transcribe (Recommended)")
        modelPopup.addItem(withTitle: "gpt-4o-mini-transcribe (Faster)")
        modelPopup.target = self
        modelPopup.action = #selector(modelChanged)
        contentView.addSubview(modelPopup)
        
        // API Key section
        let apiKeyLabel = NSTextField(labelWithString: "OpenAI API Key:")
        apiKeyLabel.frame = NSRect(x: 20, y: 100, width: 150, height: 20)
        apiKeyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        contentView.addSubview(apiKeyLabel)
        
        apiKeyField = NSSecureTextField(frame: NSRect(x: 20, y: 70, width: 360, height: 24))
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.target = self
        apiKeyField.action = #selector(apiKeyChanged)
        contentView.addSubview(apiKeyField)
        
        let apiKeyHint = NSTextField(labelWithString: "Get your API key from https://platform.openai.com/api-keys")
        apiKeyHint.frame = NSRect(x: 20, y: 50, width: 360, height: 16)
        apiKeyHint.font = NSFont.systemFont(ofSize: 11)
        apiKeyHint.textColor = NSColor.secondaryLabelColor
        contentView.addSubview(apiKeyHint)
        
        // Buttons
        cancelButton = NSButton(frame: NSRect(x: 220, y: 15, width: 80, height: 28))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        contentView.addSubview(cancelButton)
        
        saveButton = NSButton(frame: NSRect(x: 310, y: 15, width: 70, height: 28))
        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Enter key
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        contentView.addSubview(saveButton)
        
        // Load microphone devices
        loadMicrophoneDevices()
    }
    
    private func loadMicrophoneDevices() {
        availableDevices = audioRecorder?.getAvailableInputDevices() ?? []
        
        microphonePopup.removeAllItems()
        for device in availableDevices {
            microphonePopup.addItem(withTitle: device.name)
        }
        
        // Select current device
        if let currentDevice = audioRecorder?.getCurrentSelectedDevice(),
           let index = availableDevices.firstIndex(where: { $0.id == currentDevice.id }) {
            microphonePopup.selectItem(at: index)
        }
    }
    
    private func loadSettings() {
        // Load API key
        if let apiKey = getAPIKey() {
            apiKeyField.stringValue = apiKey
        }
        
        // Load selected model
        let selectedModel = UserDefaults.standard.string(forKey: "selectedTranscriptionModel") ?? "gpt-4o-transcribe"
        if selectedModel == "gpt-4o-mini-transcribe" {
            modelPopup.selectItem(at: 1)
        } else {
            modelPopup.selectItem(at: 0)
        }
    }
    
    @objc private func microphoneChanged() {
        // Selection will be saved when Save button is clicked
    }
    
    @objc private func modelChanged() {
        // Selection will be saved when Save button is clicked
    }
    
    @objc private func apiKeyChanged() {
        // API key will be saved when Save button is clicked
    }
    
    @objc private func saveClicked() {
        // Save microphone selection
        if microphonePopup.indexOfSelectedItem >= 0 && microphonePopup.indexOfSelectedItem < availableDevices.count {
            let selectedDevice = availableDevices[microphonePopup.indexOfSelectedItem]
            audioRecorder?.setInputDevice(selectedDevice)
            UserDefaults.standard.set(selectedDevice.id, forKey: "selectedInputDevice")
        }
        
        // Save model selection
        let selectedModel = modelPopup.indexOfSelectedItem == 1 ? "gpt-4o-mini-transcribe" : "gpt-4o-transcribe"
        UserDefaults.standard.set(selectedModel, forKey: "selectedTranscriptionModel")
        
        // Save API key
        let apiKey = apiKeyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            if saveAPIKey(apiKey) {
                showSuccessAlert()
            } else {
                showErrorAlert("Failed to save API key to Keychain")
                return
            }
        }
        
        window?.close()
    }
    
    @objc private func cancelClicked() {
        window?.close()
    }
    
    private func showSuccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Settings Saved"
        alert.informativeText = "Your settings have been saved successfully."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - API Key Management
extension SettingsWindowController {
    private func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Dictator",
            kSecAttrAccount as String: "OpenAI_API_Key",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
    }
    
    private func saveAPIKey(_ key: String) -> Bool {
        let data = key.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Dictator",
            kSecAttrAccount as String: "OpenAI_API_Key",
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}
