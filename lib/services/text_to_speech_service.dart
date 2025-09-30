import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _cancelled = false;

  TextToSpeechService() {
    _initTTS();
  }

  void _initTTS() {
    _flutterTts.setLanguage("en-US");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> speakInBatches(
    String text, {
    int batchSize = 10,
    Duration pause = const Duration(milliseconds: 300),
  }) async {
    _cancelled = false;
    List<String> lines = _splitIntoLines(text);
    List<List<String>> batches = [];

    for (var i = 0; i < lines.length; i += batchSize) {
      batches.add(lines.sublist(i, (i + batchSize > lines.length) ? lines.length : i + batchSize));
    }

    for (final batch in batches) {
      if (_cancelled) break;

      String batchText = batch.join(' ');
      await _speak(batchText);
      await Future.delayed(pause); // Slight pause between batches
    }
  }

  List<String> _splitIntoLines(String text) {
    // Splits based on line breaks or punctuation
    final regex = RegExp(r'(?<=[.!?])\s+'); // Sentence-based split
    return text.split(regex).map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
  }

  Future<void> _speak(String text) async {
    _isSpeaking = true;
    await _flutterTts.speak(text);
    _isSpeaking = false;
  }

  Future<void> stop() async {
    _cancelled = true;
    await _flutterTts.stop();
  }

  void dispose() {
    _flutterTts.stop();
  }
}
