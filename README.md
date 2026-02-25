# AlgorithmMan (formerly known as CodeMan)
  
An iOS app that either lets the user scan handwritten/typed pseudocode or type an algorithm description, feeds that image/description to Apple Intelligence and generates runnable, editable Python.

## Features:
- Take a photo or select one from Photos library
- Alternatively, describe an algorithm in plain text
- OCRs text using Vision
- Apple Intelligence (Foundation Models) translates that pseudocode/description to Python
- Execute simple Python from within the app
- Edit and refine code with syntax highlighting
- Persistent storage with iCloud syncing between user's devices
  
## Technologies
- SwiftUI for main UI
- AVFoundation for camera integration
- Vision for OCR
- Foundation Models for code/description translation
- C interop with Python/C API for execution
- SQLiteData for data persistence and iCloud sync
- Highlighter for syntax highlighting

## Download
  [Download from App Store](https://apps.apple.com/us/app/algorithmman/id6759346966)
