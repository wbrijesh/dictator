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
    func getAudioLevel() -> Float // For waveform animation
}

class FloatingWindowViewController: NSViewController {
    weak var delegate: FloatingWindowDelegate?
    
    // UI Elements
    private var containerView: NSView!
    private var headerView: NSView!
    private var statusLabel: NSTextField!
    private var actionButton: NSButton!
    private var textView: NSTextView!
    private var scrollView: NSScrollView!
    private var copyButton: NSButton!
    private var closeButton: NSButton!
    private var waveformView: WaveformView!
    private var progressIndicator: NSProgressIndicator!
    
    // State
    private var currentState: WindowState = .idle
    private var transcriptionText: String = ""
    private var waveformTimer: Timer?
    
    enum WindowState {
        case idle
        case recording
        case transcribing
        case result(String)
        case error(String)
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 280))
        view.wantsLayer = true
        setupUI()
        updateUI(for: .idle)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupKeyboardShortcuts()
    }
    
    private func setupUI() {
        // Main container with modern styling
        containerView = NSView(frame: view.bounds)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        containerView.layer?.cornerRadius = 16
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Add subtle shadow
        containerView.shadow = NSShadow()
        containerView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.1)
        containerView.shadow?.shadowOffset = NSSize(width: 0, height: -2)
        containerView.shadow?.shadowBlurRadius = 8
        
        view.addSubview(containerView)
        
        // Header view
        headerView = NSView(frame: NSRect(x: 0, y: 240, width: 400, height: 40))
        headerView.wantsLayer = true
        headerView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        headerView.layer?.cornerRadius = 16
        headerView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        containerView.addSubview(headerView)
        
        // Close button (modern style)
        closeButton = NSButton(frame: NSRect(x: 360, y: 250, width: 20, height: 20))
        closeButton.title = ""
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeButtonTapped)
        containerView.addSubview(closeButton)
        
        // Status label with better typography
        statusLabel = NSTextField(frame: NSRect(x: 20, y: 250, width: 320, height: 20))
        statusLabel.isEditable = false
        statusLabel.isBezeled = false
        statusLabel.drawsBackground = false
        statusLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = NSColor.labelColor
        statusLabel.alignment = .center
        containerView.addSubview(statusLabel)
        
        // Waveform visualization
        waveformView = WaveformView(frame: NSRect(x: 50, y: 180, width: 300, height: 40))
        waveformView.isHidden = true
        containerView.addSubview(waveformView)
        
        // Progress indicator for transcribing
        progressIndicator = NSProgressIndicator(frame: NSRect(x: 180, y: 190, width: 40, height: 40))
        progressIndicator.style = .spinning
        progressIndicator.isHidden = true
        containerView.addSubview(progressIndicator)
        
        // Action button with modern styling
        actionButton = NSButton(frame: NSRect(x: 150, y: 140, width: 100, height: 36))
        actionButton.bezelStyle = .rounded
        actionButton.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        actionButton.target = self
        actionButton.action = #selector(actionButtonTapped)
        containerView.addSubview(actionButton)
        
        // Scroll view for text with better styling
        scrollView = NSScrollView(frame: NSRect(x: 20, y: 50, width: 360, height: 120))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 8
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = NSColor.separatorColor.cgColor
        scrollView.isHidden = true
        
        // Text view with better styling
        let textFrame = NSRect(x: 0, y: 0, width: 360, height: 120)
        textView = NSTextView(frame: textFrame)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        
        scrollView.documentView = textView
        containerView.addSubview(scrollView)
        
        // Copy button with modern styling
        copyButton = NSButton(frame: NSRect(x: 290, y: 15, width: 90, height: 28))
        copyButton.title = "Copy"
        copyButton.bezelStyle = .rounded
        copyButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        copyButton.target = self
        copyButton.action = #selector(copyButtonTapped)
        copyButton.isHidden = true
        containerView.addSubview(copyButton)
        
        // Keyboard shortcut hint
        let hintLabel = NSTextField(frame: NSRect(x: 20, y: 20, width: 250, height: 16))
        hintLabel.isEditable = false
        hintLabel.isBezeled = false
        hintLabel.drawsBackground = false
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = NSColor.secondaryLabelColor
        hintLabel.stringValue = "⌘↩ Copy • ⎋ Close"
        hintLabel.isHidden = true
        containerView.addSubview(hintLabel)
        
        // Store reference for showing/hiding
        copyButton.tag = 100 // Use tag to identify hint label
    }
    
    private func setupKeyboardShortcuts() {
        // Make the view accept first responder
        view.window?.makeFirstResponder(view)
        
        // Add local monitor for key events
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            return self?.handleKeyDown(event) ?? event
        }
    }
    
    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        // Command + Enter: Copy text
        if modifiers == .command && event.keyCode == 36 { // Enter key
            if case .result = currentState {
                copyButtonTapped()
                return nil // Consume the event
            }
        }
        
        // Escape: Close window
        if event.keyCode == 53 { // Escape key
            closeButtonTapped()
            return nil // Consume the event
        }
        
        return event // Let other events pass through
    }
    
    func updateState(_ newState: WindowState) {
        currentState = newState
        updateUI(for: newState)
    }
    
    private func updateUI(for state: WindowState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Find hint label
            let hintLabel = self.containerView.subviews.first { $0 is NSTextField && ($0 as! NSTextField).stringValue.contains("⌘↩") } as? NSTextField
            
            switch state {
            case .idle:
                self.statusLabel.stringValue = "🎤 Ready to Record"
                self.actionButton.title = "Start Recording"
                self.actionButton.isHidden = false
                self.waveformView.isHidden = true
                self.progressIndicator.isHidden = true
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                hintLabel?.isHidden = true
                self.stopWaveformAnimation()
                self.updateButtonStyle(recording: false)
                
            case .recording:
                self.statusLabel.stringValue = "🔴 Recording... Speak clearly"
                self.actionButton.title = "Stop Recording"
                self.actionButton.isHidden = false
                self.waveformView.isHidden = false
                self.progressIndicator.isHidden = true
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                hintLabel?.isHidden = true
                self.startWaveformAnimation()
                self.updateButtonStyle(recording: true)
                
            case .transcribing:
                self.statusLabel.stringValue = "🤖 Transcribing audio..."
                self.actionButton.isHidden = true
                self.waveformView.isHidden = true
                self.progressIndicator.isHidden = false
                self.progressIndicator.startAnimation(nil)
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                hintLabel?.isHidden = true
                self.stopWaveformAnimation()
                
            case .result(let text):
                self.statusLabel.stringValue = "✅ Transcription Complete"
                self.actionButton.title = "Record Again"
                self.actionButton.isHidden = false
                self.waveformView.isHidden = true
                self.progressIndicator.isHidden = true
                self.progressIndicator.stopAnimation(nil)
                self.scrollView.isHidden = false
                self.copyButton.isHidden = false
                hintLabel?.isHidden = false
                self.transcriptionText = text
                
                // Update text view with animation
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3
                    self.scrollView.animator().alphaValue = 1.0
                }
                
                self.textView.string = text
                self.textView.needsLayout = true
                self.textView.layoutSubtreeIfNeeded()
                self.textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
                
                self.stopWaveformAnimation()
                self.updateButtonStyle(recording: false)
                
            case .error(let message):
                self.statusLabel.stringValue = "❌ Error: \(message)"
                self.actionButton.title = "Try Again"
                self.actionButton.isHidden = false
                self.waveformView.isHidden = true
                self.progressIndicator.isHidden = true
                self.progressIndicator.stopAnimation(nil)
                self.scrollView.isHidden = true
                self.copyButton.isHidden = true
                hintLabel?.isHidden = true
                self.stopWaveformAnimation()
                self.updateButtonStyle(recording: false)
            }
        }
    }
    
    private func updateButtonStyle(recording: Bool) {
        if recording {
            actionButton.contentTintColor = NSColor.systemRed
        } else {
            actionButton.contentTintColor = NSColor.controlAccentColor
        }
    }
    
    private func startWaveformAnimation() {
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let audioLevel = self.delegate?.getAudioLevel() ?? 0.0
            self.waveformView.updateLevel(audioLevel)
        }
    }
    
    private func stopWaveformAnimation() {
        waveformTimer?.invalidate()
        waveformTimer = nil
        waveformView.updateLevel(0.0)
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
        
        // Visual feedback
        let originalTitle = copyButton.title
        copyButton.title = "Copied!"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.copyButton.title = originalTitle
        }
    }
    
    @objc private func closeButtonTapped() {
        delegate?.didTapClose()
    }
}

// MARK: - Waveform Visualization
class WaveformView: NSView {
    private var audioLevel: Float = 0.0
    private var bars: [CALayer] = []
    private let barCount = 20
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupBars()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBars()
    }
    
    private func setupBars() {
        wantsLayer = true
        
        let barWidth: CGFloat = 8
        let barSpacing: CGFloat = 4
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2
        
        for i in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = NSColor.controlAccentColor.cgColor
            bar.cornerRadius = barWidth / 2
            
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            bar.frame = NSRect(x: x, y: bounds.height / 2, width: barWidth, height: 2)
            
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }
    
    func updateLevel(_ level: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for (index, bar) in self.bars.enumerated() {
                // Create wave-like pattern
                let normalizedIndex = Float(index) / Float(self.barCount - 1)
                let wave = sin(normalizedIndex * .pi * 2 + level * 10) * 0.5 + 0.5
                let height = max(2, CGFloat(level * wave * 30 + 2))
                
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.1)
                bar.frame.size.height = height
                bar.frame.origin.y = (self.bounds.height - height) / 2
                CATransaction.commit()
            }
        }
    }
}
