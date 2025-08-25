//
//  MenuBarController.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import AppKit
import AVFoundation

class MenuBarController: NSObject {
    private var floatingWindow: NSWindow?
    private var windowController: FloatingWindowViewController?
    private var audioRecorder: AudioRecorder?
    private var transcriptionService: TranscriptionService?
    private var isRecording = false
    
    override init() {
        super.init()
        audioRecorder = AudioRecorder()
        transcriptionService = TranscriptionService()
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard !isRecording else { return }
        
        // Request microphone permission if needed
        requestMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.showFloatingWindow()
                    self?.beginRecording()
                } else {
                    self?.showPermissionError()
                }
            }
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        windowController?.updateState(.transcribing)
        
        audioRecorder?.stopRecording { [weak self] audioURL in
            DispatchQueue.main.async {
                self?.transcribeAudio(url: audioURL)
            }
        }
    }
    
    private func beginRecording() {
        isRecording = true
        audioRecorder?.startRecording()
        windowController?.updateState(.recording)
    }
    
    private func showFloatingWindow() {
        if floatingWindow == nil {
            createFloatingWindow()
        }
        
        floatingWindow?.makeKeyAndOrderFront(nil)
        floatingWindow?.center()
    }
    
    private func createFloatingWindow() {
        let windowRect = NSRect(x: 0, y: 0, width: 320, height: 180)
        
        floatingWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        floatingWindow?.level = .floating
        floatingWindow?.backgroundColor = NSColor.clear
        floatingWindow?.hasShadow = true
        floatingWindow?.isOpaque = false
        floatingWindow?.titlebarAppearsTransparent = true
        
        // Create and set up the view controller
        windowController = FloatingWindowViewController()
        windowController?.delegate = self
        floatingWindow?.contentViewController = windowController
    }
    
    private func transcribeAudio(url: URL?) {
        guard let audioURL = url else {
            print("❌ Failed to get audio URL")
            windowController?.updateState(.error("Failed to record audio"))
            return
        }
        
        print("🎵 Starting transcription for: \(audioURL.lastPathComponent)")
        
        transcriptionService?.transcribe(audioURL: audioURL) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    print("✅ Transcription successful: '\(text)'")
                    self?.windowController?.updateState(.result(text))
                case .failure(let error):
                    let errorMessage = self?.getErrorMessage(from: error) ?? "Unknown error"
                    print("❌ Transcription failed: \(errorMessage)")
                    self?.windowController?.updateState(.error(errorMessage))
                }
                
                // Clean up audio file
                try? FileManager.default.removeItem(at: audioURL)
                print("🗑️ Cleaned up audio file")
            }
        }
    }
    
    private func getErrorMessage(from error: TranscriptionService.TranscriptionError) -> String {
        switch error {
        case .noAPIKey:
            return "No API key found. Please set your OpenAI API key."
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let underlyingError):
            return "Network error: \(underlyingError.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
    
    private func showPermissionError() {
        showFloatingWindow()
        windowController?.updateState(.error("Microphone permission required"))
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        // For macOS, we need to check microphone access differently
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted)
            }
        @unknown default:
            completion(false)
        }
    }
    
    func showMicrophoneSelector() {
        let devices = audioRecorder?.getAvailableInputDevices() ?? []
        let currentDevice = audioRecorder?.getCurrentSelectedDevice()
        
        let alert = NSAlert()
        alert.messageText = "Select Microphone"
        alert.informativeText = "Choose which microphone to use for recording:"
        alert.alertStyle = .informational
        
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        
        var selectedIndex = 0
        for (index, device) in devices.enumerated() {
            popup.addItem(withTitle: device.name)
            
            // Set the current selection if it matches
            if let current = currentDevice, current.id == device.id {
                selectedIndex = index
            }
        }
        
        // Select the current device in the dropdown
        popup.selectItem(at: selectedIndex)
        
        alert.accessoryView = popup
        alert.addButton(withTitle: "Select")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let selectedIndex = popup.indexOfSelectedItem
            if selectedIndex >= 0 && selectedIndex < devices.count {
                let selectedDevice = devices[selectedIndex]
                audioRecorder?.setInputDevice(selectedDevice)
                print("✅ Selected microphone: \(selectedDevice.name)")
            }
        }
    }
}

// MARK: - FloatingWindowDelegate
extension MenuBarController: FloatingWindowDelegate {
    func didTapStopRecording() {
        toggleRecording()
    }
    
    func didTapCopyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Optionally close window after copying
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.didTapClose()
        }
    }
    
    func didTapClose() {
        floatingWindow?.orderOut(nil)
        windowController?.updateState(.idle)
        
        // Reset recording state if needed
        if isRecording {
            isRecording = false
            audioRecorder?.stopRecording { _ in }
        }
    }
}
