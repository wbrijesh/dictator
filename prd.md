# 📄 Product Requirements Document (PRD)

**Project Name:** Dictator (working title)
**Platform:** macOS (13+ Ventura or later)
**Technology Stack:** Swift (AppKit), OpenAI Whisper (GPT-4o-Transcribe)

---

## 🧭 Product Overview

Dictator is a lightweight native macOS app that transcribes audio to text on demand. When the user presses a **global keyboard shortcut**, a **menu bar UI** appears, immediately starts recording audio, and shows a **Stop** button. Once the user stops the recording, the app sends the audio to **OpenAI's GPT-4o transcription API** (`/v1/audio/transcriptions`) and displays the resulting text with an option to **copy** it to the clipboard.

The app prioritizes:

* **Speed** (quick startup and transcription),
* **Privacy** (short-lived audio, no local storage),
* **Battery efficiency** (runs only on-demand),
* **Minimal footprint** (no dock icon, menu bar UI only).

---

## 🎯 Goals

* Allow speech-to-text conversion via a **hotkey**.
* Use **OpenAI’s Whisper/GPT-4o API** for transcription.
* Maintain a **native macOS look and feel**.
* Keep resource usage negligible outside active use.

---

## ✅ Functional Requirements

| Feature                      | Description                                                                                              |
| ---------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Global Hotkey Activation** | Triggers the app's menu bar window and starts recording audio immediately.                         |
| **Menu bar UI**                 | A small, always-on-top floating panel with a Stop button and (after transcription) a Text + Copy button. |
| **Audio Recording**          | Uses `AVAudioEngine` and `AVAudioRecorder` to capture the microphone input.                              |
| **Transcription**            | Sends recorded audio as a `.wav` or `.m4a` file to OpenAI’s `v1/audio/transcriptions` endpoint.          |
| **Display Result**           | Transcribed text is shown in the menu bar.                                                                  |
| **Copy to Clipboard**        | One-click button to copy transcription result.                                                           |
| **Auto-Close**               | Optionally closes or hides the menu bar after copy or timeout.                                              |
| **No Dock Icon**             | Runs as a background utility (accessory app or menu bar item).                                           |

---

## 🛠️ Non-Functional Requirements

| Category            | Requirement                                                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Battery Usage**   | Zero activity when not recording; lightweight use of CPU/GPU during recording/transcription.                     |
| **Performance**     | Start recording within 200ms of hotkey trigger. Transcription returned within 1–3 seconds for short input.       |
| **Security**        | No persistent storage of audio or transcripts; transcriptions use HTTPS; API key is securely stored in Keychain. |
| **User Experience** | Minimalist UI, no learning curve. Intuitive and fast.                                                            |
| **Accessibility**   | Buttons and text readable and usable with keyboard navigation.                                                   |
| **Reliability**     | Handles microphone permission errors, API failures, and poor connectivity gracefully.                            |

---

## 🧰 Technical Architecture

### 🔧 Tech Stack

| Layer         | Technology                                                                                     |
| ------------- | ---------------------------------------------------------------------------------------------- |
| Language      | **Swift 5+**                                                                                   |
| UI Framework  | **AppKit** (custom floating `NSWindow`)                                                        |
| Audio         | `AVAudioEngine`, `AVAudioRecorder`                                                             |
| Network       | `URLSession` (multipart POST to OpenAI API)                                                    |
| Transcription | OpenAI Whisper (`gpt-4o-transcribe`)                                                           |
| Hotkey        | [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) (modern, Swift-based) |
| Key Storage   | `KeychainAccess` or native `Keychain` APIs for API key                                         |

---

## 🪟 UI Components

| Component           | Description                                                            |
| ------------------- | ---------------------------------------------------------------------- |
| **Menu bar**    | Frameless `NSWindow`, centered on screen, always on top                |
| **Recording State** | Stop button + recording indicator (e.g. pulsating red dot or waveform) |
| **Result View**     | Multiline text view with result + Copy button                          |
| **Error State**     | Inline display for errors (API/network/mic access)                     |

---

## 🔐 OpenAI Integration

* Endpoint: `POST https://api.openai.com/v1/audio/transcriptions`
* Headers: `Authorization: Bearer <api_key>`, `Content-Type: multipart/form-data`
* File: `m4a` or `wav` audio from `AVAudioRecorder`
* Model: `whisper-1`
* Response: JSON with `text` field containing transcription

---

## 🧪 Future Enhancements (Post-MVP)

* Local whisper model fallback for offline mode
* Real-time streaming transcription
* Multilingual transcription
* History log of transcriptions
* Output to clipboard + paste automatically

---

## ✅ Summary

You're building a native, privacy-conscious speech-to-text app for macOS using:

* Modern Swift + AppKit
* OpenAI’s Whisper (`gpt-4o-transcribe`)
* Minimal UI and near-zero idle power use
* Global shortcut + fast menu bar UX

This design will deliver a professional, performant, and elegant speech-to-text experience for Mac users.

---

