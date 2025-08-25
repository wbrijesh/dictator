//
//  AudioRecorder.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import AVFoundation
import Foundation
import CoreAudio

struct AudioDevice {
    let id: AudioDeviceID
    let name: String
}

class AudioRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private var recordingURL: URL?
    private var selectedInputDevice: AudioDevice?
    
    override init() {
        super.init()
        loadSelectedDevice()
    }
    
    func getAvailableInputDevices() -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        
        if status == noErr {
            let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
            let deviceIDs = UnsafeMutablePointer<AudioDeviceID>.allocate(capacity: deviceCount)
            defer { deviceIDs.deallocate() }
            
            status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, deviceIDs)
            
            if status == noErr {
                for i in 0..<deviceCount {
                    let deviceID = deviceIDs[i]
                    
                    // Check if device has input streams
                    var inputAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyStreamConfiguration,
                        mScope: kAudioDevicePropertyScopeInput,
                        mElement: kAudioObjectPropertyElementMain
                    )
                    
                    var inputDataSize: UInt32 = 0
                    status = AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &inputDataSize)
                    
                    if status == noErr && inputDataSize > 0 {
                        // Get device name
                        var nameAddress = AudioObjectPropertyAddress(
                            mSelector: kAudioDevicePropertyDeviceNameCFString,
                            mScope: kAudioObjectPropertyScopeGlobal,
                            mElement: kAudioObjectPropertyElementMain
                        )
                        
                        var nameSize: UInt32 = UInt32(MemoryLayout<CFString>.size)
                        var deviceName: CFString?
                        
                        status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &deviceName)
                        
                        if status == noErr, let name = deviceName {
                            devices.append(AudioDevice(id: deviceID, name: String(name)))
                        }
                    }
                }
            }
        }
        
        return devices
    }
    
    func getCurrentSelectedDevice() -> AudioDevice? {
        return selectedInputDevice
    }
    
    func setInputDevice(_ device: AudioDevice) {
        selectedInputDevice = device
        saveSelectedDevice(device)
        print("🎤 Selected and saved device: \(device.name)")
    }
    
    private func saveSelectedDevice(_ device: AudioDevice) {
        UserDefaults.standard.set(device.id, forKey: "SelectedMicrophoneID")
        UserDefaults.standard.set(device.name, forKey: "SelectedMicrophoneName")
    }
    
    private func loadSelectedDevice() {
        let deviceID = UserDefaults.standard.object(forKey: "SelectedMicrophoneID") as? AudioDeviceID
        let deviceName = UserDefaults.standard.string(forKey: "SelectedMicrophoneName")
        
        if let id = deviceID, let name = deviceName {
            selectedInputDevice = AudioDevice(id: id, name: name)
            print("🔄 Loaded saved device: \(name)")
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            // Create temporary file for recording
            recordingURL = createTemporaryAudioFile()
            guard let url = recordingURL else {
                print("❌ Failed to create temporary audio file")
                return
            }
            
            // If we have a selected device, set it as system default first
            if let selectedDevice = selectedInputDevice {
                print("🎤 Setting device: \(selectedDevice.name) (ID: \(selectedDevice.id))")
                
                var deviceID = selectedDevice.id
                var propertyAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDefaultInputDevice,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                
                let status = AudioObjectSetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &propertyAddress,
                    0,
                    nil,
                    UInt32(MemoryLayout<AudioDeviceID>.size),
                    &deviceID
                )
                
                if status == noErr {
                    print("✅ Successfully set system default input device")
                    // Give the system time to switch - this is crucial
                    Thread.sleep(forTimeInterval: 1.5)
                } else {
                    print("❌ Failed to set system default device (status: \(status))")
                }
            }
            
            // Setup audio engine AFTER setting the device
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            print("📊 Input format: \(recordingFormat)")
            print("🔊 Sample rate: \(recordingFormat.sampleRate) Hz")
            print("📻 Channels: \(recordingFormat.channelCount)")
            
            // Verify we're using the right device by checking the current default
            var currentDeviceID: AudioDeviceID = 0
            var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            let status = AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                &propertySize,
                &currentDeviceID
            )
            
            if status == noErr {
                print("🔍 Current system input device ID: \(currentDeviceID)")
                if let selectedDevice = selectedInputDevice {
                    if currentDeviceID == selectedDevice.id {
                        print("✅ Confirmed using selected device: \(selectedDevice.name)")
                    } else {
                        print("⚠️ System is using different device than selected!")
                    }
                }
            }
            
            // Create audio file with proper settings for M4A
            // Use the device's native sample rate to avoid conversion artifacts
            let deviceSampleRate = recordingFormat.sampleRate
            print("🎵 Using device native sample rate: \(deviceSampleRate) Hz")
            
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: deviceSampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioFile = try AVAudioFile(forWriting: url, settings: settings)
            
            // Install tap on input node
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                do {
                    try self?.audioFile?.write(from: buffer)
                } catch {
                    print("❌ Error writing audio buffer: \(error)")
                }
            }
            
            // Start the audio engine
            try audioEngine.start()
            isRecording = true
            
            print("✅ Recording started successfully")
            
        } catch {
            print("❌ Failed to start recording: \(error)")
            cleanup()
        }
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }
        
        isRecording = false
        
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        // Close audio file
        audioFile = nil
        
        print("🛑 Recording stopped")
        
        // Return the recorded file URL
        completion(recordingURL)
        
        // Clean up will happen after transcription
    }
    
    private func createTemporaryAudioFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "dictator_recording_\(Date().timeIntervalSince1970).m4a"
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func cleanup() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        audioFile = nil
        
        // Clean up temporary file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
    }
    
    deinit {
        cleanup()
    }
}
