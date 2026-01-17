import 'dart:math';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ggwave_ffi/ggwave_ffi.dart';
import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  GGWave? _ggwave;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSending = false;
  String _statusMessage = 'Ready to send';
  Uint8List? _payload;
  GGWaveProtocol _selectedProtocol = GGWaveProtocol.PROTOCOL_AUDIBLE_FAST;

  final List<DropdownMenuItem<GGWaveProtocol>> _protocolItems = [
    const DropdownMenuItem(
      value: GGWaveProtocol.PROTOCOL_AUDIBLE_NORMAL,
      child: Text('Audible Normal'),
    ),
    const DropdownMenuItem(
      value: GGWaveProtocol.PROTOCOL_AUDIBLE_FAST,
      child: Text('Audible Fast'),
    ),
    const DropdownMenuItem(
      value: GGWaveProtocol.PROTOCOL_AUDIBLE_FASTEST,
      child: Text('Audible Fastest'),
    ),
    const DropdownMenuItem(
      value: GGWaveProtocol.PROTOCOL_ULTRASOUND_NORMAL,
      child: Text('Ultrasound Normal'),
    ),
    const DropdownMenuItem(
      value: GGWaveProtocol.PROTOCOL_ULTRASOUND_FAST,
      child: Text('Ultrasound Fast'),
    ),
    const DropdownMenuItem(
      value: GGWaveProtocol.PROTOCOL_ULTRASOUND_FASTEST,
      child: Text('Ultrasound Fastest'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initGGWave();
    _generateTestPayload();
  }

  void _initGGWave() {
    try {
      _ggwave = GGWave.tx(sampleRate: 48000.0);
      setState(() {
        _statusMessage = 'GGWave initialized';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize GGWave: $e';
      });
    }
  }

  void _generateTestPayload() {
    // Generate a random 32-byte payload (simulating a Veilid public key)
    final random = Random.secure();
    _payload = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      _payload![i] = random.nextInt(256);
    }
    setState(() {});
  }

  Future<void> _sendPayload() async {
    if (_ggwave == null || _payload == null || _isSending) return;

    setState(() {
      _isSending = true;
      _statusMessage = 'Encoding payload...';
    });

    try {
      // Encode the payload to audio
      final waveform = _ggwave!.encode(
        _payload!,
        protocol: _selectedProtocol,
        volume: 50,
      );

      setState(() {
        _statusMessage = 'Playing audio (${waveform.length} samples)...';
      });

      // Convert Float32 samples to WAV file
      final wavBytes = _float32ToWav(waveform, 48000);

      // Write to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/ggwave_output.wav');
      await tempFile.writeAsBytes(wavBytes);

      // Play the audio
      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();

      // Wait for playback to complete
      await _audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );

      setState(() {
        _statusMessage = 'Transmission complete!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  /// Converts Float32 samples to WAV file bytes
  Uint8List _float32ToWav(Float32List samples, int sampleRate) {
    // Convert float samples to 16-bit PCM
    final pcmData = Int16List(samples.length);
    for (var i = 0; i < samples.length; i++) {
      // Clamp and convert to 16-bit
      final sample = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      pcmData[i] = sample;
    }

    // Create WAV header
    final dataSize = pcmData.length * 2;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little); // AudioFormat (PCM)
    header.setUint16(22, 1, Endian.little); // NumChannels (Mono)
    header.setUint32(24, sampleRate, Endian.little); // SampleRate
    header.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    header.setUint16(32, 2, Endian.little); // BlockAlign
    header.setUint16(34, 16, Endian.little); // BitsPerSample

    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    // Combine header and data
    final wavBytes = Uint8List(44 + dataSize);
    wavBytes.setAll(0, header.buffer.asUint8List());

    // Copy PCM data
    final pcmBytes = pcmData.buffer.asUint8List();
    wavBytes.setAll(44, pcmBytes);

    return wavBytes;
  }

  @override
  void dispose() {
    _ggwave?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Data'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payload (32 bytes)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _payload != null
                            ? hex.encode(_payload!).toUpperCase()
                            : 'No payload',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _generateTestPayload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Generate New Payload'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Protocol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<GGWaveProtocol>(
                      value: _selectedProtocol,
                      items: _protocolItems,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedProtocol = value;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getProtocolDescription(_selectedProtocol),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSending ? null : _sendPayload,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volume_up, size: 28),
              label: Text(_isSending ? 'Sending...' : 'Send via Sound'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isSending
                              ? Icons.sync
                              : _statusMessage.contains('Error')
                                  ? Icons.error
                                  : Icons.check_circle,
                          color: _isSending
                              ? Colors.blue
                              : _statusMessage.contains('Error')
                                  ? Colors.red
                                  : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _statusMessage.contains('Error')
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProtocolDescription(GGWaveProtocol protocol) {
    switch (protocol) {
      case GGWaveProtocol.PROTOCOL_AUDIBLE_NORMAL:
        return 'Slower but more reliable. You can hear the transmission.';
      case GGWaveProtocol.PROTOCOL_AUDIBLE_FAST:
        return 'Balanced speed and reliability. Audible tones.';
      case GGWaveProtocol.PROTOCOL_AUDIBLE_FASTEST:
        return 'Fastest audible protocol. May be less reliable.';
      case GGWaveProtocol.PROTOCOL_ULTRASOUND_NORMAL:
        return 'Uses ultrasonic frequencies. Inaudible to humans.';
      case GGWaveProtocol.PROTOCOL_ULTRASOUND_FAST:
        return 'Faster ultrasonic transmission.';
      case GGWaveProtocol.PROTOCOL_ULTRASOUND_FASTEST:
        return 'Fastest ultrasonic protocol. Requires good conditions.';
      default:
        return '';
    }
  }
}
