import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:ggwave_ffi/ggwave_ffi.dart';
import 'package:convert/convert.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  GGWave? _ggwave;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recordingSubscription;
  bool _isListening = false;
  bool _hasPermission = false;
  String _statusMessage = 'Tap to start listening';
  Uint8List? _receivedPayload;
  final List<Uint8List> _receivedHistory = [];

  @override
  void initState() {
    super.initState();
    _initGGWave();
    _checkPermission();
  }

  void _initGGWave() {
    try {
      _ggwave = GGWave.rx(sampleRate: 48000.0);
      setState(() {
        _statusMessage = 'GGWave initialized. Tap to start listening.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize GGWave: $e';
      });
    }
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    setState(() {
      _hasPermission = status.isGranted;
    });
  }

  Future<void> _requestPermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _hasPermission = status.isGranted;
      if (!_hasPermission) {
        _statusMessage = 'Microphone permission denied';
      }
    });
  }

  Future<void> _toggleListening() async {
    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) return;
    }

    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (_ggwave == null) return;

    try {
      // Check if we can record
      if (!await _recorder.hasPermission()) {
        setState(() {
          _statusMessage = 'Microphone permission required';
        });
        return;
      }

      // Configure recording for raw PCM at 48kHz mono
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 48000,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
      );

      // Start recording as a stream
      final stream = await _recorder.startStream(config);

      setState(() {
        _isListening = true;
        _statusMessage = 'Listening for data...';
        _receivedPayload = null;
        _chunkCount = 0;
        _totalSamples = 0;
      });

      // Process audio chunks
      _recordingSubscription = stream.listen(
        (chunk) {
          _processAudioChunk(chunk);
        },
        onError: (e) {
          setState(() {
            _statusMessage = 'Recording error: $e';
            _isListening = false;
          });
        },
        onDone: () {
          setState(() {
            if (_isListening) {
              _statusMessage = 'Recording stopped';
              _isListening = false;
            }
          });
        },
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Error starting recording: $e';
        _isListening = false;
      });
    }
  }

  int _chunkCount = 0;
  int _totalSamples = 0;

  void _processAudioChunk(Uint8List chunk) {
    if (_ggwave == null) return;

    try {
      // Convert PCM16 bytes to Int16List
      // Copy to new buffer to ensure proper alignment (chunks may have odd offsets)
      final alignedBytes = Uint8List.fromList(chunk);
      final int16Data = alignedBytes.buffer.asInt16List(0, alignedBytes.length ~/ 2);

      _chunkCount++;
      _totalSamples += int16Data.length;

      // Debug: log every 50 chunks (~1 second at typical chunk sizes)
      if (_chunkCount % 50 == 0) {
        // Calculate peak amplitude for debugging
        int maxAmp = 0;
        double maxFloat = 0;
        for (var i = 0; i < int16Data.length; i++) {
          final abs = int16Data[i].abs();
          if (abs > maxAmp) maxAmp = abs;
        }
        // Also check float conversion
        final testFloat = int16Data[0] / 32768.0;
        debugPrint('Audio: chunks=$_chunkCount, samples=$_totalSamples, peak=$maxAmp, firstSample=${int16Data[0]}, asFloat=$testFloat');
      }

      // Convert Int16 to Float32 (normalized)
      final float32Data = Float32List(int16Data.length);
      for (var i = 0; i < int16Data.length; i++) {
        float32Data[i] = int16Data[i] / 32768.0;
      }

      // Try to decode
      final (result, statusCode) = _ggwave!.decodeWithStatus(float32Data);

      // Debug: log decode attempts periodically
      if (_chunkCount % 50 == 0) {
        debugPrint('Decode: status=$statusCode, result=${result?.length ?? "null"}, samples=${float32Data.length}');
      }

      if (result != null && result.isNotEmpty) {
        setState(() {
          _receivedPayload = result;
          _receivedHistory.insert(0, result);
          if (_receivedHistory.length > 10) {
            _receivedHistory.removeLast();
          }
          _statusMessage = 'Data received! (${result.length} bytes)';
        });
      }
    } catch (e) {
      // Decoding errors are expected when no valid signal is present
      // Only log unexpected errors
      if (!e.toString().contains('decode')) {
        debugPrint('Processing error: $e');
      }
    }
  }

  Future<void> _stopListening() async {
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      // Ignore errors when checking recording state during disposal
      debugPrint('Stop listening error: $e');
    }

    if (mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = _receivedPayload != null
            ? 'Listening stopped. Last received: ${_receivedPayload!.length} bytes'
            : 'Listening stopped';
      });
    }
  }

  @override
  void dispose() {
    _recordingSubscription?.cancel();
    _ggwave?.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Data'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Listening indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _isListening
                    ? Colors.deepPurple.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isListening ? Colors.deepPurple : Colors.grey,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isListening ? Icons.hearing : Icons.mic,
                    size: 80,
                    color: _isListening ? Colors.deepPurple : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isListening ? 'Listening...' : 'Not Listening',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isListening ? Colors.deepPurple : Colors.grey,
                    ),
                  ),
                  if (_isListening) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Listen button
            ElevatedButton.icon(
              onPressed: _toggleListening,
              icon: Icon(
                _isListening ? Icons.stop : Icons.play_arrow,
                size: 28,
              ),
              label: Text(_isListening ? 'Stop Listening' : 'Start Listening'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor:
                    _isListening ? Colors.red : Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Status card
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
                          _isListening
                              ? Icons.sync
                              : _statusMessage.contains('Error') ||
                                      _statusMessage.contains('denied')
                                  ? Icons.error
                                  : _receivedPayload != null
                                      ? Icons.check_circle
                                      : Icons.info,
                          color: _isListening
                              ? Colors.blue
                              : _statusMessage.contains('Error') ||
                                      _statusMessage.contains('denied')
                                  ? Colors.red
                                  : _receivedPayload != null
                                      ? Colors.green
                                      : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(
                              color: _statusMessage.contains('Error') ||
                                      _statusMessage.contains('denied')
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
            const SizedBox(height: 16),

            // Received data card
            if (_receivedPayload != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Received Payload (${_receivedPayload!.length} bytes)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: SelectableText(
                          hex.encode(_receivedPayload!).toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // History
            if (_receivedHistory.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._receivedHistory.take(5).map((payload) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '${hex.encode(payload).toUpperCase().substring(0, 16)}... (${payload.length}B)',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],

            // Permission warning
            if (!_hasPermission)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Microphone permission is required to receive data.',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                      TextButton(
                        onPressed: _requestPermission,
                        child: const Text('Grant'),
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
}
