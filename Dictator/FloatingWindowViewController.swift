//
//  FloatingWindowViewController.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import AppKit
import AVFoundation

protocol FloatingWindowDelegate: AnyObject {
    func didTapStopRecording()
    func didTapCopyText(_ text: String)
    func didTapClose()
    func getAudioLevel() -> Float
}

class FloatingWindowViewController: NSViewController {
    weak var delegate: FloatingWindowDelegate?
    
    // UI Elements
    private var containerView: NSView!
    private var statusLabel: NSTextField!
    private var actionButton: NSButton!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var copyButton: NSButton!
    private var closeButton: NSButton!
    private var recordingIndicator: NSView!
    private var progressIndicator: NSProgressIndicator!
    private var keyboardHintLabel: NSTextField!
    
    // State
    private var currentState: WindowState = .idle
    private var transcriptionText: String = ""
    
    // Dynamic sizing
    private let baseWidth: CGFloat = 360
    private let baseHeight: CGFloat = 180
    private let expandedHeight: CGFloat = 260
    private let recordingWidth: CGFloat = 240
    private let recordingHeight: CGFloat = 50
    
    enum WindowState {
        case idle
        case recording
        case transcribing
        case result(String)
        case error(String)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: baseWidth, height: baseHeight))
        view.wantsLayer = true
        setupUI()
        updateUI(for: .idle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardShortcuts()
        setupAppearanceObserver()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Make sure window can receive key events
        view.window?.makeKeyAndOrderFront(nil)
    }
    
    private func setupUI() {
        // Main container
        containerView = NSView(frame: view.bounds)
        containerView.wantsLayer = true
        updateContainerAppearance()
        
        view.addSubview(containerView)
        
        // Close button (minimal, top-right)
        closeButton = NSButton(frame: NSRect(x: baseWidth - 30, y: baseHeight - 30, width: 20, height: 20))
        closeButton.title = ""
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeButtonTapped)
        containerView.addSubview(closeButton)
        
        // Status label
        statusLabel = NSTextField(frame: NSRect(x: 20, y: baseHeight - 50, width: baseWidth - 40, height: 24))
        statusLabel.isEditable = false
        statusLabel.isBezeled = false
        statusLabel.drawsBackground = false
        statusLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.alignment = .center
        containerView.addSubview(statusLabel)
        
        // Recording indicator (red circle)
        recordingIndicator = NSView(frame: NSRect(x: 20, y: 0, width: 12, height: 12))
        recordingIndicator.wantsLayer = true
        recordingIndicator.layer?.backgroundColor = NSColor.systemRed.cgColor
        recordingIndicator.layer?.cornerRadius = 6
        recordingIndicator.isHidden = true
        containerView.addSubview(recordingIndicator)
        
        // Small progress indicator (centered)
        progressIndicator = NSProgressIndicator(frame: NSRect(x: (baseWidth - 20) / 2, y: 90, width: 20, height: 20))
        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isHidden = true
        containerView.addSubview(progressIndicator)
        
        // Action button
        actionButton = NSButton(frame: NSRect(x: (baseWidth - 100) / 2, y: 50, width: 100, height: 32))
        actionButton.bezelStyle = .rounded
        actionButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        actionButton.target = self
        actionButton.action = #selector(actionButtonTapped)
        containerView.addSubview(actionButton)
        
        // Scroll view for text
        scrollView = NSScrollView(frame: NSRect(x: 20, y: 50, width: baseWidth - 40, height: 120))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.isHidden = true
        
        // Text view
        let textFrame = NSRect(x: 0, y: 0, width: baseWidth - 40, height: 120)
        textView = NSTextView(frame: textFrame)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: baseWidth - 40, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        
        scrollView.documentView = textView
        containerView.addSubview(scrollView)
        
        // Copy button
        copyButton = NSButton(frame: NSRect(x: baseWidth - 110, y: 15, width: 80, height: 28))
        copyButton.title = "Copy"
        copyButton.bezelStyle = .rounded
        copyButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        copyButton.target = self
        copyButton.action = #selector(copyButtonTapped)
        copyButton.isHidden = true
        containerView.addSubview(copyButton)
        
        // Keyboard shortcut hint
        keyboardHintLabel = NSTextField(frame: NSRect(x: 20, y: 20, width: 200, height: 16))
        keyboardHintLabel.isEditable = false
        keyboardHintLabel.isBezeled = false
        keyboardHintLabel.drawsBackground = false
        keyboardHintLabel.font = NSFont.systemFont(ofSize: 11)
        keyboardHintLabel.stringValue = "⌘↩ Copy • ⎋ Close"
        keyboardHintLabel.isHidden = true
        containerView.addSubview(keyboardHintLabel)
        
        updateTextColors()
    }
    
    private func setupAppearanceObserver() {
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAppearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )
    }
    
    @objc private func systemAppearanceChanged() {
        updateContainerAppearance()
        updateTextColors()
    }
    
    private func updateContainerAppearance() {
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        containerView.layer?.borderWidth = 1
        
        // Subtle shadow
        containerView.shadow = NSShadow()
        containerView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.15)
        containerView.shadow?.shadowOffset = NSSize(width: 0, height: -2)
        containerView.shadow?.shadowBlurRadius = 6
    }
    
    private func updateTextColors() {
        statusLabel.textColor = NSColor.labelColor
        keyboardHintLabel.textColor = NSColor.secondaryLabelColor
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        
        scrollView.layer?.cornerRadius = 6
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
    }
    
    private func resizeWindow(to newSize: NSSize, animated: Bool = true) {
        guard let window = view.window else { return }
        
        let currentFrame = window.frame
        let newFrame = NSRect(
            x: currentFrame.origin.x + (currentFrame.width - newSize.width) / 2, // Center horizontally
            y: currentFrame.origin.y + (currentFrame.height - newSize.height),
            width: newSize.width,
            height: newSize.height
        )
        
        // Update view and container frames
        view.frame = NSRect(origin: .zero, size: newSize)
        containerView.frame = view.bounds
        
        // Update container corner radius based on size
        if newSize.width == recordingWidth && newSize.height == recordingHeight {
            // Pill shape for recording
            containerView.layer?.cornerRadius = recordingHeight / 2
        } else {
            // Normal corner radius for other states
            containerView.layer?.cornerRadius = 12
        }
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        } else {
            window.setFrame(newFrame, display: true)
        }
    }
    
    private func setupKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event) ?? event
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        if modifiers == .command && event.keyCode == 36 {
            if case .result = currentState {
                copyButtonTapped()
                return nil
            }
        }
        
        if event.keyCode == 53 {
            closeButtonTapped()
            return nil
        }
        
        return event
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
                self.resizeWindow(to: NSSize(width: self.baseWidth, height: self.baseHeight))
                
                // Update close button position
                self.closeButton.frame = NSRect(x: self.baseWidth - 30, y: self.baseHeight - 30, width: 20, height: 20)
                self.closeButton.isHidden = false
                
                // Update status label
                self.statusLabel.frame = NSRect(x: 20, y: self.baseHeight - 50, width: self.baseWidth - 40, height: 24)
                self.statusLabel.stringValue = "Ready to Record"
                self.statusLabel.alignment = .center
                self.statusLabel.isHidden = false
                
                self.actionButton.title = "Start Recording"
                self.actionButton.isHidden = false
                self.actionButton.frame = NSRect(x: (self.baseWidth - 100) / 2, y: 50, width: 100, height: 32)
                
                self.recordingIndicator.isHidden = true
                self.progressIndicator.isHidden = true
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                self.keyboardHintLabel.isHidden = true
                self.stopRecordingAnimation()
                
            case .recording:
                self.resizeWindow(to: NSSize(width: self.recordingWidth, height: self.recordingHeight))
                
                // Hide other elements
                self.statusLabel.isHidden = true
                self.actionButton.isHidden = true
                self.progressIndicator.isHidden = true
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                self.keyboardHintLabel.isHidden = true
                
                // Show recording elements in a single line
                // Red circle indicator
                self.recordingIndicator.isHidden = false
                self.recordingIndicator.frame = NSRect(x: 15, y: (self.recordingHeight - 12) / 2, width: 12, height: 12)
                
                // Recording text
                self.statusLabel.isHidden = false
                self.statusLabel.frame = NSRect(x: 35, y: (self.recordingHeight - 20) / 2, width: 140, height: 20)
                self.statusLabel.stringValue = "Recording..."
                self.statusLabel.alignment = .left
                self.statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
                
                // Close button (X)
                self.closeButton.isHidden = false
                self.closeButton.frame = NSRect(x: self.recordingWidth - 30, y: (self.recordingHeight - 20) / 2, width: 20, height: 20)
                
                self.startRecordingAnimation()
                
            case .transcribing:
                self.resizeWindow(to: NSSize(width: self.recordingWidth, height: self.recordingHeight))
                
                // Hide other elements
                self.statusLabel.isHidden = true
                self.actionButton.isHidden = true
                self.recordingIndicator.isHidden = true
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                self.keyboardHintLabel.isHidden = true
                
                // Show transcribing elements in a single line (same as recording)
                // Progress spinner
                self.progressIndicator.isHidden = false
                self.progressIndicator.frame = NSRect(x: 15, y: (self.recordingHeight - 16) / 2, width: 16, height: 16)
                self.progressIndicator.controlSize = .small
                self.progressIndicator.startAnimation(nil)
                
                // Transcribing text
                self.statusLabel.isHidden = false
                self.statusLabel.frame = NSRect(x: 40, y: (self.recordingHeight - 20) / 2, width: 140, height: 20)
                self.statusLabel.stringValue = "Transcribing..."
                self.statusLabel.alignment = .left
                self.statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
                
                // Close button (X)
                self.closeButton.isHidden = false
                self.closeButton.frame = NSRect(x: self.recordingWidth - 30, y: (self.recordingHeight - 20) / 2, width: 20, height: 20)
                
                self.stopRecordingAnimation()
                
            case .result(let text):
                self.resizeWindow(to: NSSize(width: self.baseWidth, height: self.expandedHeight))
                
                // Close button position (top right)
                self.closeButton.frame = NSRect(x: self.baseWidth - 30, y: self.expandedHeight - 30, width: 20, height: 20)
                self.closeButton.isHidden = false
                
                // Title on same line as close button (top left)
                self.statusLabel.frame = NSRect(x: 20, y: self.expandedHeight - 30, width: 200, height: 20)
                self.statusLabel.stringValue = "Transcription"
                self.statusLabel.alignment = .left
                self.statusLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
                self.statusLabel.isHidden = false
                
                // Text area - more space since no centered title
                self.scrollView.isHidden = false
                self.scrollView.frame = NSRect(x: 20, y: 50, width: self.baseWidth - 40, height: 170)
                
                // Buttons on RIGHT side - flush alignment with increased height
                self.copyButton.isHidden = false
                self.copyButton.frame = NSRect(x: self.baseWidth - 90, y: 12, width: 70, height: 34)
                
                self.actionButton.title = "Record Again"
                self.actionButton.isHidden = false
                self.actionButton.frame = NSRect(x: self.baseWidth - 170, y: 12, width: 75, height: 34)
                
                // Keyboard shortcuts on LEFT side - flush alignment
                self.keyboardHintLabel.isHidden = false
                self.keyboardHintLabel.frame = NSRect(x: 20, y: 20, width: 150, height: 16)
                
                self.recordingIndicator.isHidden = true
                self.progressIndicator.isHidden = true
                self.progressIndicator.stopAnimation(nil)
                
                self.transcriptionText = text
                self.textView.string = text
                self.textView.needsLayout = true
                self.textView.layoutSubtreeIfNeeded()
                self.textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                
                self.stopRecordingAnimation()
                
            case .error(let message):
                self.resizeWindow(to: NSSize(width: self.baseWidth, height: self.baseHeight))
                
                // Update close button position
                self.closeButton.frame = NSRect(x: self.baseWidth - 30, y: self.baseHeight - 30, width: 20, height: 20)
                self.closeButton.isHidden = false
                
                // Update status label
                self.statusLabel.frame = NSRect(x: 20, y: self.baseHeight - 50, width: self.baseWidth - 40, height: 24)
                self.statusLabel.stringValue = "Error: \(message)"
                self.statusLabel.alignment = .center
                self.statusLabel.isHidden = false
                
                self.actionButton.title = "Try Again"
                self.actionButton.isHidden = false
                self.actionButton.frame = NSRect(x: (self.baseWidth - 100) / 2, y: 50, width: 100, height: 32)
                
                self.recordingIndicator.isHidden = true
                self.progressIndicator.isHidden = true
                self.progressIndicator.stopAnimation(nil)
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                self.keyboardHintLabel.isHidden = true
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
            delegate?.didTapStopRecording()
        case .recording:
            delegate?.didTapStopRecording()
        case .transcribing:
            break
        }
    }
    
    @objc private func copyButtonTapped() {
        delegate?.didTapCopyText(transcriptionText)
        
        let originalTitle = copyButton.title
        copyButton.title = "Copied!"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.copyButton.title = originalTitle
        }
    }
    
    @objc private func closeButtonTapped() {
        delegate?.didTapClose()
    }
    
    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
    }
}
