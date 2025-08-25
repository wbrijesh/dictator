# Dictator - macOS Speech-to-Text App

A lightweight native macOS menu bar app that transcribes audio to text using OpenAI's Whisper API.

## Features

- **Global Hotkey**: Press `Option+Space` to start/stop recording
- **Menu Bar Integration**: Click the microphone icon in the menu bar
- **Privacy-Focused**: No persistent storage of audio or transcripts
- **Fast & Efficient**: Minimal resource usage when idle
- **Secure**: API key stored securely in macOS Keychain

## Setup

1. **Get OpenAI API Key**
   - Visit [OpenAI Platform](https://platform.openai.com/api-keys)
   - Create a new API key
   - Copy the key (starts with `sk-`)

2. **Install & Configure**
   - Build and run the app in Xcode
   - On first launch, you'll be prompted to enter your API key
   - Grant microphone permissions when requested

3. **Alternative API Key Setup**
   - Set environment variable: `export OPENAI_API_KEY=your_key_here`
   - Or use the "Change API Key..." menu option

## Usage

### Recording Audio
- **Hotkey**: Press `Option+Space` anywhere on your Mac
- **Menu Bar**: Left-click the microphone icon
- **Menu**: Right-click → "Start Recording"

### During Recording
- Speak clearly into your microphone
- Click "Stop Recording" or press the hotkey again to finish

### After Transcription
- View the transcribed text in the floating window
- Click "Copy" to copy text to clipboard
- Window auto-closes after copying

### Menu Options
Right-click the menu bar icon for:
- Start Recording
- Change API Key
- About Dictator
- Quit Dictator

## Requirements

- macOS 13.0 (Ventura) or later
- Microphone access permission
- Internet connection for OpenAI API
- Valid OpenAI API key with credits

## Privacy & Security

- Audio is recorded temporarily and deleted after transcription
- No local storage of recordings or transcripts
- API key stored securely in macOS Keychain
- All API communication uses HTTPS

## Troubleshooting

### No Microphone Permission
- Go to System Settings → Privacy & Security → Microphone
- Enable access for Dictator

### API Key Issues
- Verify your API key is valid and has credits
- Use "Change API Key..." from the menu to update

### Recording Issues
- Check microphone is working in other apps
- Ensure you're speaking clearly and close to the mic
- Try recording in a quiet environment

### Network Issues
- Verify internet connection
- Check if OpenAI API is accessible from your network

## Technical Details

- **Audio Format**: M4A, optimized for speech
- **API Model**: `gpt-4o-transcribe` (OpenAI's latest Whisper model)
- **File Size Limit**: 25MB (OpenAI API limit)
- **Supported Languages**: 98+ languages supported by Whisper

## Development

Built with:
- Swift 5+
- AppKit (native macOS UI)
- AVFoundation (audio recording)
- URLSession (API communication)
- Keychain Services (secure storage)

## License

This project is for educational and personal use.
