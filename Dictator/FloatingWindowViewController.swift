//
//  FloatingWindowViewController.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import AppKit

protocol FloatingWindowDelegate: AnyObject {
    func didTapStopRecording()
    func didTapCopyText(_ text: String)
    func didTapClose()
}

class FloatingWindowViewController: NSViewController {
    weak var delegate: FloatingWindowDelegate?
    
    // UI Elements
    private var statusLabel: NSTextField!
    private var actionButton: NSButton!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var copyButton: NSButton!
    private var closeButton: NSButton!
    private var recordingIndicator: NSView!
    
    // State
    private var currentState: WindowState = .idle
    private var transcriptionText: String = ""
    
    enum WindowState {
        case idle
        case recording
        case transcribing
        case result(String)
        case error(String)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 180))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.layer?.cornerRadius = 12
        
        setupUI()
        updateUI(for: .idle)
    }
    
    private func setupUI() {
        // Close button (top-right)
        closeButton = NSButton(frame: NSRect(x: 290, y: 150, width: 20, height: 20))
        closeButton.title = "×"
        closeButton.bezelStyle = .circular
        closeButton.target = self
        closeButton.action = #selector(closeButtonTapped)
        view.addSubview(closeButton)
        
        // Status label
        statusLabel = NSTextField(frame: NSRect(x: 20, y: 130, width: 250, height: 20))
        statusLabel.isEditable = false
        statusLabel.isBezeled = false
        statusLabel.drawsBackground = false
        statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.alignment = .center
        view.addSubview(statusLabel)
        
        // Recording indicator (animated red dot)
        recordingIndicator = NSView(frame: NSRect(x: 20, y: 100, width: 12, height: 12))
        recordingIndicator.wantsLayer = true
        recordingIndicator.layer?.backgroundColor = NSColor.systemRed.cgColor
        recordingIndicator.layer?.cornerRadius = 6
        recordingIndicator.isHidden = true
        view.addSubview(recordingIndicator)
        
        // Action button (Stop/Start)
        actionButton = NSButton(frame: NSRect(x: 110, y: 90, width: 100, height: 32))
        actionButton.bezelStyle = .rounded
        actionButton.target = self
        actionButton.action = #selector(actionButtonTapped)
        view.addSubview(actionButton)
        
        // Scroll view for text
        scrollView = NSScrollView(frame: NSRect(x: 20, y: 40, width: 280, height: 60))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.isHidden = true
        
        // Create text view with proper frame
        let textFrame = NSRect(x: 0, y: 0, width: 280, height: 60)
        textView = NSTextView(frame: textFrame)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 12)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 280, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = textView
        view.addSubview(scrollView)
        
        // Copy button
        copyButton = NSButton(frame: NSRect(x: 220, y: 10, width: 80, height: 24))
        copyButton.title = "Copy"
        copyButton.bezelStyle = .rounded
        copyButton.target = self
        copyButton.action = #selector(copyButtonTapped)
        copyButton.isHidden = true
        view.addSubview(copyButton)
    }
    
    func updateState(_ newState: WindowState) {
        currentState = newState
        updateUI(for: newState)
    }
    
    private func updateUI(for state: WindowState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch state {
            case .idle:
                self.statusLabel.stringValue = "Ready to record"
                self.actionButton.title = "Start Recording"
                self.actionButton.isHidden = false
                self.recordingIndicator.isHidden = true
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                self.stopRecordingAnimation()
                
            case .recording:
                self.statusLabel.stringValue = "Recording... Speak now"
                self.actionButton.title = "Stop Recording"
                self.actionButton.isHidden = false
                self.recordingIndicator.isHidden = false
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                self.startRecordingAnimation()
                
            case .transcribing:
                self.statusLabel.stringValue = "Transcribing..."
                self.actionButton.isHidden = true
                self.recordingIndicator.isHidden = true
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                self.stopRecordingAnimation()
                
            case .result(let text):
                self.statusLabel.stringValue = "Transcription complete"
                self.actionButton.title = "Record Again"
                self.actionButton.isHidden = false
                self.recordingIndicator.isHidden = true
                self.scrollView.isHidden = false
                self.copyButton.isHidden = false
                self.transcriptionText = text
                
                // Update text view content
                self.textView.string = text
                
                // Force layout update
                self.textView.needsLayout = true
                self.textView.layoutSubtreeIfNeeded()
                
                // Scroll to top
                self.textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                
                self.stopRecordingAnimation()
                
                print("✅ Text set in textView: '\(text)'") // Debug log
                
            case .error(let message):
                self.statusLabel.stringValue = "Error: \(message)"
                self.actionButton.title = "Try Again"
                self.actionButton.isHidden = false
                self.recordingIndicator.isHidden = true
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                self.stopRecordingAnimation()
            }
        }
    }
    
    private func startRecordingAnimation() {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.3
        animation.duration = 0.8
        animation.repeatCount = .infinity
        animation.autoreverses = true
        recordingIndicator.layer?.add(animation, forKey: "pulse")
    }
    
    private func stopRecordingAnimation() {
        recordingIndicator.layer?.removeAnimation(forKey: "pulse")
    }
    
    @objc private func actionButtonTapped() {
        switch currentState {
        case .idle, .error, .result:
            // Start recording
            delegate?.didTapStopRecording() // This will toggle to recording state
        case .recording:
            // Stop recording
            delegate?.didTapStopRecording()
        case .transcribing:
            break // Do nothing while transcribing
        }
    }
    
    @objc private func copyButtonTapped() {
        delegate?.didTapCopyText(transcriptionText)
    }
    
    @objc private func closeButtonTapped() {
        delegate?.didTapClose()
    }
}
