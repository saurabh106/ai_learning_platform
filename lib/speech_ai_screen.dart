// ignore_for_file: depend_on_referenced_packages, unused_field

import 'package:ai_learning/services/text_to_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SpeechAIScreen extends StatefulWidget {
  const SpeechAIScreen({super.key});

  @override
  State<SpeechAIScreen> createState() => _SpeechAIScreenState();
}

class _SpeechAIScreenState extends State<SpeechAIScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  String _aiResponse = '';
  bool _isLoading = false;
  final List<String> _consoleOutput = [];
  final ScrollController _scrollController = ScrollController();
  late TextToSpeechService _tts;
  Timer? _speechDetectionTimer;
  String _lastRecognizedText = '';

  @override
  void initState() {
    super.initState();
    _tts = TextToSpeechService();
    _initSpeech();
    _addToConsole('App started. Click "Start Listening" to begin.');
  }

  void _initSpeech() async {
    await Permission.microphone.request();
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'done' && _isListening) {
          _stopListening();
        }
      },
      onError: (error) {
        print('Speech error: $error');
        _addToConsole('Error: $error');
        _stopListening();
      },
    );

    if (available) {
      _addToConsole('Speech recognition initialized successfully');
    } else {
      _addToConsole('Speech recognition not available');
    }
  }

  void _startListening() async {
    if (!await _speech.isAvailable) {
      _addToConsole('Speech recognition not available');
      return;
    }

    // Add haptic feedback
    _vibrate();

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _lastRecognizedText = '';
    });

    _addToConsole('🎤 Started listening... Speak now!');

    // Start speech detection timer
    _startSpeechDetectionTimer();

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });

        // Print to console in real-time
        if (result.finalResult) {
          _addToConsole('🗣️ Final: ${result.recognizedWords}');
          // Reset timer when new speech is detected
          _resetSpeechDetectionTimer();
        } else {
          // Only print interim results occasionally to avoid spam
          if (result.recognizedWords.length % 10 == 0) {
            _addToConsole('🗣️ Interim: ${result.recognizedWords}');
          }
          
          // Check if new speech has been detected
          if (result.recognizedWords != _lastRecognizedText && 
              result.recognizedWords.isNotEmpty) {
            _lastRecognizedText = result.recognizedWords;
            _resetSpeechDetectionTimer();
          }
        }
      },
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  void _startSpeechDetectionTimer() {
    _speechDetectionTimer = Timer(const Duration(seconds: 3), () {
      if (_isListening && _recognizedText.isNotEmpty) {
        _addToConsole('⏰ No new speech detected for 3 seconds, stopping...');
        _stopListening();
      }
    });
  }

  void _resetSpeechDetectionTimer() {
    _speechDetectionTimer?.cancel();
    _startSpeechDetectionTimer();
  }

  void _stopListening() {
    _speechDetectionTimer?.cancel();
    _speechDetectionTimer = null;
    
    _speech.stop();
    setState(() {
      _isListening = false;
    });
    _addToConsole('⏹️ Stopped listening');

    // Auto-send to AI if we have text
    if (_recognizedText.isNotEmpty) {
      _sendToAI(_recognizedText);
    }
  }

  Future<void> _vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      if (await Vibration.hasAmplitudeControl() ?? false) {
        // Short, gentle vibration for start
        Vibration.vibrate(duration: 100, amplitude: 50);
      } else {
        Vibration.vibrate(duration: 100);
      }
    }
  }

  Future<void> _sendToAI(String text) async {
    if (text.trim().isEmpty) {
      _addToConsole('❌ No text to send to AI');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _addToConsole('🚀 Sending to AI: "$text"');

    try {
      final response = await _callOpenAIApi(text);
      _addToConsole('🤖 AI Response: $response');
      setState(() {
        _aiResponse = response;
      });
      await _tts.speakInBatches(response);
    } catch (e) {
      _addToConsole('❌ AI Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _callOpenAIApi(String text) async {
    // Load the API key from .env
    final apiKey = dotenv.env['OPENROUTER_API'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENROUTER_API key is not set in .env file');
    }

    const baseUrl = "https://openrouter.ai/api/v1";

    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'http://localhost:3000',
        'X-Title': 'Flutter Speech AI App',
      },
      body: jsonEncode({
        'model': 'x-ai/grok-4-fast:free',
        'messages': [
          {'role': 'user', 'content': text},
        ],
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }

  void _addToConsole(String message) {
    setState(() {
      _consoleOutput.add('${DateTime.now().toString().split(' ')[1]} - $message');
    });
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Also print to debug console
    print(message);
  }

  void _clearConsole() {
    setState(() {
      _consoleOutput.clear();
    });
    _addToConsole('Console cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speech AI Console'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.clear_all), onPressed: _clearConsole, tooltip: 'Clear Console')],
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            // Controls Section
            Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Status indicators
                  Row(
                    children: [
                      _buildStatusIndicator('Mic', _isListening ? Colors.green : Colors.red),
                      const SizedBox(width: 10),
                      _buildStatusIndicator('AI', _isLoading ? Colors.orange : Colors.green),
                      const SizedBox(width: 10),
                      _buildStatusIndicator('Speech', _speech.isAvailable ? Colors.green : Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Control buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isListening ? null : _startListening,
                          icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                          label: Text(_isListening ? 'Listening...' : 'Start Listening'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isListening ? Colors.green : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isListening ? _stopListening : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Manual send button
                  ElevatedButton.icon(
                    onPressed: _recognizedText.isNotEmpty && !_isLoading ? () => _sendToAI(_recognizedText) : null,
                    icon: const Icon(Icons.send),
                    label: const Text('Send to AI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),

            // Current recognized text
            if (_recognizedText.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.blueGrey[800],
                child: Text(
                  'Current Text: $_recognizedText',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),

            // Console output
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _consoleOutput.length,
                  itemBuilder: (context, index) {
                    final message = _consoleOutput[index];
                    Color textColor = Colors.white;

                    // Color code different types of messages
                    if (message.contains('🎤'))
                      textColor = Colors.green;
                    else if (message.contains('🤖'))
                      textColor = Colors.cyan;
                    else if (message.contains('❌'))
                      textColor = Colors.red;
                    else if (message.contains('🚀'))
                      textColor = Colors.orange;
                    else if (message.contains('⏹️'))
                      textColor = Colors.yellow;
                    else if (message.contains('🗣️'))
                      textColor = Colors.lightGreen;
                    else if (message.contains('⏰'))
                      textColor = Colors.amber;

                    return Text(
                      message,
                      style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Monospace'),
                    );
                  },
                ),
              ),
            ),

            // Loading indicator at bottom
            if (_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange[800],
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text('AI is thinking...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  @override
  void dispose() {
    _speechDetectionTimer?.cancel();
    _speech.stop();
    _scrollController.dispose();
    _tts.dispose();
    super.dispose();
  }
}