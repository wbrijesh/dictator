//
//  AudioRecorder.swift
//  Dictator
//
//  Created by Brijesh Wawdhane on 25/08/25.
//

import AVFoundation
import Foundation

class AudioRecorder: NSObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var isRecording = false
    private var recordingURL: URL?
    
    override init() {
        super.init()
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            // Create temporary file for recording
            recordingURL = createTemporaryAudioFile()
            guard let url = recordingURL else {
                print("Failed to create temporary audio file")
                return
            }
            
            // Setup audio engine
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Create audio file with proper settings for M4A
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioFile = try AVAudioFile(forWriting: url, settings: settings)
            
            // Install tap on input node
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                do {
                    try self?.audioFile?.write(from: buffer)
                } catch {
                    print("Error writing audio buffer: \(error)")
                }
            }
            
            // Start the audio engine
            try audioEngine.start()
            isRecording = true
            
            print("Recording started")
            
        } catch {
            print("Failed to start recording: \(error)")
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
        
        print("Recording stopped")
        
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
