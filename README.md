# Sound Transfer - Veilid Key Demo

A Flutter app demonstrating data-over-sound transmission using the ggwave library. This can be used to transfer small payloads (like a 32-byte Veilid public key) between devices using audio.

## Status

**Work in Progress** - The app builds and runs on both iOS and Android, but cross-device data transfer does not currently work. The ggwave decoder fails to decode transmitted audio. See [Known Issues](#known-issues) below.

## Features

- **Send Screen**: Encode and transmit a 32-byte payload via sound
- **Receive Screen**: Listen for and decode incoming sound transmissions
- **Protocol Selection**: Choose between audible and ultrasonic protocols
- **Cross-Platform**: Builds on both iOS and Android

## Project Structure

```
sound-transfer-veilid-key/
└── ggwave_ffi/                    # Flutter FFI plugin
    ├── src/                       # C wrapper (Android/CMake)
    │   ├── ggwave_ffi.c
    │   ├── ggwave_ffi.h
    │   └── CMakeLists.txt
    ├── third_party/
    │   └── ggwave/                # ggwave library (cloned)
    ├── ios/
    │   ├── ggwave_ffi.podspec
    │   └── Classes/               # iOS native sources
    │       ├── ggwave_ffi.c
    │       ├── ggwave_ffi.h
    │       ├── ggwave.cpp
    │       ├── fft.h
    │       ├── ggwave/ggwave.h
    │       └── reed-solomon/
    ├── android/
    │   └── build.gradle
    ├── lib/
    │   ├── ggwave_ffi.dart        # High-level Dart API
    │   └── ggwave_ffi_bindings_generated.dart
    └── example/                   # Demo app
        └── lib/
            ├── main.dart
            └── screens/
                ├── send_screen.dart
                └── receive_screen.dart
```

## Building

### Prerequisites

- Flutter 3.38+ installed
- Xcode (for iOS)
- Android Studio with NDK (for Android)

### Build Commands

```bash
cd ggwave_ffi/example

# iOS
flutter build ios

# Android
flutter build apk
```

## Usage

### Running the App

```bash
cd ggwave_ffi/example
flutter run
```

### Testing Data Transfer

1. **On Device A (Sender)**:
   - Open the app and tap "Send Data"
   - A random 32-byte payload is generated (or tap "Generate New Payload")
   - Select a protocol (start with "Audible Fast" for testing)
   - Tap "Send via Sound"

2. **On Device B (Receiver)**:
   - Open the app and tap "Receive Data"
   - Grant microphone permission when prompted
   - Tap "Start Listening"
   - Position the devices close together (within 1-2 meters)
   - The received payload will appear when successfully decoded

### Protocol Options

| Protocol | Description | Use Case |
|----------|-------------|----------|
| Audible Normal | Slowest, most reliable | Noisy environments |
| Audible Fast | Balanced speed/reliability | General use |
| Audible Fastest | Fastest audible | Quiet environments |
| Ultrasound Normal | Inaudible, slower | Discreet transfer |
| Ultrasound Fast | Inaudible, faster | Quick discreet transfer |
| Ultrasound Fastest | Inaudible, fastest | Optimal conditions |

## API Usage

### Encoding (Sending)

```dart
import 'package:ggwave_ffi/ggwave_ffi.dart';

// Create a TX-only instance
final ggwave = GGWave.tx(sampleRate: 48000.0);

// Encode payload to audio waveform
final waveform = ggwave.encode(
  payload, // Uint8List
  protocol: GGWaveProtocol.PROTOCOL_AUDIBLE_FAST,
  volume: 25,
);

// Play the waveform through speakers (Float32List)
// ... use your preferred audio playback library

// Don't forget to dispose
ggwave.dispose();
```

### Decoding (Receiving)

```dart
import 'package:ggwave_ffi/ggwave_ffi.dart';

// Create an RX-only instance
final ggwave = GGWave.rx(sampleRate: 48000.0);

// Feed audio samples to the decoder
// (call repeatedly with microphone input)
final result = ggwave.decode(audioSamples); // Float32List

if (result != null) {
  // Message received!
  print('Received: ${result.length} bytes');
}

ggwave.dispose();
```

## Technical Details

- **Sample Rate**: 48000 Hz
- **Sample Format**: Float32
- **Max Payload Size**: ~140 bytes (variable length) or 64 bytes (fixed length)
- **Bandwidth**: 8-16 bytes/sec depending on protocol
- **Error Correction**: Reed-Solomon codes

## Permissions

### iOS (Info.plist)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to receive data transmitted via sound.</string>
```

### Android (AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

## Troubleshooting

### No data received
**Note**: Cross-device transfer is currently not working due to a decoder issue. See [Known Issues](#known-issues).

If debugging:
- Ensure both devices are using the same protocol
- Try moving devices closer together (within 30cm)
- Use audible protocol first (you should hear the tones)
- Check that microphone permission is granted
- Check debug logs for peak amplitude values (should be 10000+ when receiving)

### Distorted audio
- Lower the volume setting (default 25 is usually good)
- Ensure no other apps are using the microphone

### iOS build errors

**"symbol not found" errors**: The native library isn't loading correctly.
- Run `flutter clean`
- Delete `ios/Pods` and `ios/Podfile.lock`
- Run `cd ios && pod install`
- Rebuild with `flutter build ios`

**Header file not found**: Ensure `ios/Classes/` contains all required source files including the `ggwave/` subdirectory with `ggwave.h`.

### Android build errors
- Ensure Android NDK is installed
- Run `flutter clean` and rebuild

### General build issues
- Run `flutter clean` and rebuild
- For iOS: Delete `ios/Pods` and `ios/Podfile.lock`, then run `pod install`

## Known Issues

### Data transfer not working
The ggwave decoder does not successfully decode transmitted audio. Testing shows:
- Audio encoding and playback works (you can hear the chirpy tones)
- Microphone captures audio (peak amplitudes visible in debug logs)
- Decoder always returns "need more data" even with strong audio signal

This appears to be an issue with either the FFI bindings or how audio is fed to the decoder. Further investigation needed.

### iOS microphone sensitivity
iOS captures audio at much lower levels than Android. This may be related to audio session configuration in the `record` package.

## Credits

- [ggwave](https://github.com/ggerganov/ggwave) - The underlying data-over-sound library by Georgi Gerganov
- Built with Flutter FFI for cross-platform native bindings
