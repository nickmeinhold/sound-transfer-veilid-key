# Sound Transfer Veilid Key - Project Guide

## Overview

A Flutter app demonstrating data-over-sound transmission using the ggwave library. Designed to transfer small payloads (like 32-byte Veilid public keys) between devices via audio.

## Project Structure

```
sound-transfer-veilid-key/
├── CLAUDE.md                 # This file
├── README.md                 # User-facing documentation
└── ggwave_ffi/               # Flutter FFI plugin
    ├── src/                  # C wrapper source (used by Android/CMake)
    │   ├── ggwave_ffi.c
    │   ├── ggwave_ffi.h
    │   └── CMakeLists.txt
    ├── third_party/ggwave/   # ggwave library (submodule/cloned)
    ├── lib/
    │   ├── ggwave_ffi.dart                    # High-level Dart API (GGWave class)
    │   └── ggwave_ffi_bindings_generated.dart # FFI bindings (auto-generated)
    ├── example/              # Demo Flutter app
    │   └── lib/
    │       ├── main.dart
    │       └── screens/
    │           ├── send_screen.dart    # TX: encode + play audio
    │           └── receive_screen.dart # RX: record + decode audio
    ├── ios/
    │   ├── ggwave_ffi.podspec
    │   └── Classes/          # iOS native sources (compiled via CocoaPods)
    │       ├── ggwave_ffi.c
    │       ├── ggwave_ffi.h
    │       ├── ggwave.cpp
    │       ├── fft.h
    │       ├── ggwave/
    │       │   └── ggwave.h
    │       └── reed-solomon/
    ├── android/build.gradle
    ├── ffigen.yaml           # FFI generator config
    └── pubspec.yaml
```

## Key Commands

```bash
# Run the example app
cd ggwave_ffi/example && flutter run

# Regenerate FFI bindings (after modifying ggwave_ffi.h)
cd ggwave_ffi && dart run ffigen --config ffigen.yaml

# Build iOS
cd ggwave_ffi/example && flutter build ios

# Build Android
cd ggwave_ffi/example && flutter build apk

# Clean iOS build (if having issues)
cd ggwave_ffi/example && flutter clean && cd ios && rm -rf Pods Podfile.lock && pod install
```

## Architecture

### Native Layer (C/C++)
- `ggwave_ffi.c/h`: Thin wrapper around ggwave C++ library
- Exposes: `ggwave_ffi_init`, `ggwave_ffi_encode`, `ggwave_ffi_decode`, `ggwave_ffi_free`

### Platform-Specific Build

**iOS (CocoaPods)**:
- Native sources must be in `ios/Classes/` directory
- Uses `DynamicLibrary.process()` since code is statically linked
- Header path: `ggwave/ggwave.h` (requires subdirectory structure)

**Android (CMake)**:
- Uses `src/` directory with CMakeLists.txt
- Uses `DynamicLibrary.open('libggwave_ffi.so')`

### Dart API (`lib/ggwave_ffi.dart`)
- `GGWave.tx()` - Create TX-only instance for encoding
- `GGWave.rx()` - Create RX-only instance for decoding
- `GGWave.txRx()` - Create bidirectional instance
- `encode(Uint8List payload, {protocol, volume})` - Returns Float32List waveform
- `decode(Float32List waveform)` - Returns Uint8List? payload or null
- `decodeInt16(Int16List)` - Helper for 16-bit PCM microphone input

### Example App
- **SendScreen**: Uses `just_audio` to play encoded WAV file
- **ReceiveScreen**: Uses `record` package for streaming PCM capture

## Audio Specs
- Sample rate: 48000 Hz
- Format: Float32 (internally), WAV 16-bit PCM for playback
- Protocols: Audible (Normal/Fast/Fastest) and Ultrasound variants

## Dependencies (example app)
- `just_audio` - Audio playback
- `record` - Microphone recording
- `permission_handler` - Mic permission requests
- `convert` - Hex encoding for display
- `path_provider` - Temp file storage

## iOS Build Notes

The iOS build requires native sources in `ios/Classes/` because CocoaPods doesn't reliably handle relative paths (`../`) through Flutter's symlink structure. Key points:

1. Source files are copied to `ios/Classes/` (not symlinked from `src/`)
2. `ggwave.h` must be in `ios/Classes/ggwave/` subdirectory to match the include path in `ggwave.cpp`
3. The Dart FFI uses `DynamicLibrary.process()` for iOS (statically linked)
4. podspec uses `source_files = 'Classes/**/*'`

If updating native code, remember to update both `src/` (for Android) and `ios/Classes/` (for iOS).

## Current Status

Working prototype with:
- Complete FFI bindings for ggwave
- Working send/receive UI on iOS and Android
- Protocol selection (audible/ultrasound)
- 32-byte payload generation and display

## Potential Next Steps
- Add actual Veilid integration
- Test cross-device transmission
- Add error handling/retry logic
- Consider adding QR code fallback
