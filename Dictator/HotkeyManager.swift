//
//  HotkeyManager.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import AppKit
import Carbon

class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x44494354), id: 1) // 'DICT'
    
    weak var delegate: HotkeyManagerDelegate?
    
    init() {
        setupGlobalHotkey()
    }
    
    deinit {
        unregisterHotkey()
    }
    
    private func setupGlobalHotkey() {
        // Register Option+Space as the global hotkey
        let keyCode: UInt32 = 49 // Space key
        let modifiers: UInt32 = UInt32(optionKey)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent, OSType(kEventParamDirectObject), OSType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if let manager = Unmanaged<HotkeyManager>.fromOpaque(userData!).takeUnretainedValue() as HotkeyManager? {
                DispatchQueue.main.async {
                    manager.delegate?.hotkeyPressed()
                }
            }
            
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)
        
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    private func unregisterHotkey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyPressed()
}
