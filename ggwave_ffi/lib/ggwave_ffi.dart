import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ggwave_ffi_bindings_generated.dart';

export 'ggwave_ffi_bindings_generated.dart'
    show GGWaveProtocol, GGWaveSampleFormat, GGWaveOperatingMode;

const String _libName = 'ggwave_ffi';

/// The dynamic library in which the symbols for [GgwaveFfiBindings] can be found.
final DynamicLibrary _dylib = () {
  if (Platform.isIOS) {
    // On iOS, the native code is statically linked into the app via CocoaPods
    return DynamicLibrary.process();
  }
  if (Platform.isMacOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

/// The bindings to the native functions in [_dylib].
final GgwaveFfiBindings _bindings = GgwaveFfiBindings(_dylib);

/// High-level wrapper for ggwave data-over-sound library.
class GGWave {
  final int _instance;
  bool _disposed = false;

  GGWave._(this._instance);

  /// Creates a new GGWave instance for encoding (TX) only.
  factory GGWave.tx({
    double sampleRate = 48000.0,
    int samplesPerFrame = 1024,
    GGWaveSampleFormat sampleFormat = GGWaveSampleFormat.SAMPLE_FORMAT_F32,
  }) {
    final instance = _bindings.ggwave_ffi_init(
      sampleRate,
      sampleRate,
      samplesPerFrame,
      sampleFormat.value,
      sampleFormat.value,
      GGWaveOperatingMode.OPERATING_MODE_TX.value,
    );
    if (instance < 0) {
      throw Exception('Failed to initialize ggwave TX instance');
    }
    return GGWave._(instance);
  }

  /// Creates a new GGWave instance for decoding (RX) only.
  factory GGWave.rx({
    double sampleRate = 48000.0,
    int samplesPerFrame = 1024,
    GGWaveSampleFormat sampleFormat = GGWaveSampleFormat.SAMPLE_FORMAT_F32,
  }) {
    final instance = _bindings.ggwave_ffi_init(
      sampleRate,
      sampleRate,
      samplesPerFrame,
      sampleFormat.value,
      sampleFormat.value,
      GGWaveOperatingMode.OPERATING_MODE_RX.value,
    );
    if (instance < 0) {
      throw Exception('Failed to initialize ggwave RX instance');
    }
    return GGWave._(instance);
  }

  /// Creates a new GGWave instance for both encoding and decoding.
  factory GGWave.txRx({
    double sampleRate = 48000.0,
    int samplesPerFrame = 1024,
    GGWaveSampleFormat sampleFormat = GGWaveSampleFormat.SAMPLE_FORMAT_F32,
  }) {
    final instance = _bindings.ggwave_ffi_init(
      sampleRate,
      sampleRate,
      samplesPerFrame,
      sampleFormat.value,
      sampleFormat.value,
      GGWaveOperatingMode.OPERATING_MODE_RX_AND_TX.value,
    );
    if (instance < 0) {
      throw Exception('Failed to initialize ggwave TX/RX instance');
    }
    return GGWave._(instance);
  }

  /// Encodes the given payload into an audio waveform.
  ///
  /// Returns the waveform as Float32 samples.
  Float32List encode(
    Uint8List payload, {
    GGWaveProtocol protocol = GGWaveProtocol.PROTOCOL_AUDIBLE_FAST,
    int volume = 25,
  }) {
    _checkDisposed();

    // First, get the required buffer size
    final payloadPtr = calloc<Uint8>(payload.length);
    try {
      payloadPtr.asTypedList(payload.length).setAll(0, payload);

      final requiredSize = _bindings.ggwave_ffi_encode(
        _instance,
        payloadPtr,
        payload.length,
        protocol.value,
        volume,
        nullptr,
        0,
      );

      if (requiredSize < 0) {
        throw Exception('Failed to query encode buffer size');
      }

      // Allocate the waveform buffer and encode
      final waveformPtr = calloc<Uint8>(requiredSize);
      try {
        final actualSize = _bindings.ggwave_ffi_encode(
          _instance,
          payloadPtr,
          payload.length,
          protocol.value,
          volume,
          waveformPtr,
          requiredSize,
        );

        if (actualSize < 0) {
          throw Exception('Failed to encode payload');
        }

        // Convert bytes to Float32List
        final bytes = waveformPtr.asTypedList(actualSize);
        final floatData = Float32List(actualSize ~/ 4);
        final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
        for (var i = 0; i < floatData.length; i++) {
          floatData[i] = byteData.getFloat32(i * 4, Endian.little);
        }

        return floatData;
      } finally {
        calloc.free(waveformPtr);
      }
    } finally {
      calloc.free(payloadPtr);
    }
  }

  /// Decodes audio waveform data.
  ///
  /// Returns the decoded payload if a complete message is received,
  /// or null if more data is needed.
  Uint8List? decode(Float32List waveform) {
    final (result, _) = decodeWithStatus(waveform);
    return result;
  }

  /// Decodes audio waveform data with status code.
  ///
  /// Returns a tuple of (payload, statusCode) where:
  /// - payload is the decoded data or null
  /// - statusCode is: >0 = bytes decoded, 0 = need more data, <0 = error
  (Uint8List?, int) decodeWithStatus(Float32List waveform) {
    _checkDisposed();

    // Convert Float32List to bytes
    final bytes = Uint8List(waveform.length * 4);
    final byteData = ByteData.sublistView(bytes);
    for (var i = 0; i < waveform.length; i++) {
      byteData.setFloat32(i * 4, waveform[i], Endian.little);
    }

    final waveformPtr = calloc<Uint8>(bytes.length);
    final payloadPtr = calloc<Uint8>(256); // Max payload size

    try {
      waveformPtr.asTypedList(bytes.length).setAll(0, bytes);

      final result = _bindings.ggwave_ffi_decode(
        _instance,
        waveformPtr,
        bytes.length,
        payloadPtr,
        256,
      );

      if (result < 0) {
        // Error
        return (null, result);
      }

      if (result == 0) {
        // No complete message yet
        return (null, 0);
      }

      // Message decoded successfully
      return (Uint8List.fromList(payloadPtr.asTypedList(result)), result);
    } finally {
      calloc.free(waveformPtr);
      calloc.free(payloadPtr);
    }
  }

  /// Decodes audio waveform data from Int16 samples (common for microphone input).
  Uint8List? decodeInt16(Int16List waveform) {
    _checkDisposed();

    // Convert Int16List to Float32List (normalized to -1.0 to 1.0)
    final floatData = Float32List(waveform.length);
    for (var i = 0; i < waveform.length; i++) {
      floatData[i] = waveform[i] / 32768.0;
    }

    return decode(floatData);
  }

  /// Releases native resources.
  void dispose() {
    if (!_disposed) {
      _bindings.ggwave_ffi_free(_instance);
      _disposed = true;
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('GGWave instance has been disposed');
    }
  }

  /// Returns the default sample rate (48000 Hz).
  static double get defaultSampleRate =>
      _bindings.ggwave_ffi_get_default_sample_rate();

  /// Returns the default samples per frame (1024).
  static int get defaultSamplesPerFrame =>
      _bindings.ggwave_ffi_get_default_samples_per_frame();
}
