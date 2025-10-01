// ignore_for_file: unused_field

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
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
  
  bool _showDashboard = false;
  bool _isLoadingDashboard = false;
  Map<String, dynamic>? _parsedResponse;
  bool _showTemplates = true;
  final TextEditingController _textEditingController = TextEditingController();
  int _currentStep = 0;
  bool _showConsole = false;


  final List<Map<String, dynamic>> _templates = [
    {
      'title': '🎓 Student Guide',
      'icon': Icons.school,
      'color': Color(0xFF4361EE),
      'gradient': [Color(0xFF4361EE), Color(0xFF3A56E0)],
      'content': '''I'm a final-year computer science student graduating in 6 months. I know Python, Java, and basic web development. I enjoy problem-solving and building applications. What software development roles should I target? Give me a 6-month preparation plan with specific skills and projects.''',
    },
    {
      'title': '🔄 Career Transition',
      'icon': Icons.change_circle,
      'color': Color(0xFF06D6A0),
      'gradient': [Color(0xFF06D6A0), Color(0xFF05C191)],
      'content': '''I'm 28 with 4 years in marketing/sales. I want to transition into tech roles. I have basic SQL and analytical skills. What tech roles suit my background? What should I learn in the next 8-12 months to make a successful career change?''',
    },
    {
      'title': '🚀 Tech Advancement',
      'icon': Icons.engineering,
      'color': Color(0xFFFF9E00),
      'gradient': [Color(0xFFFF9E00), Color(0xFFE68E00)],
      'content': '''I'm a frontend developer with 2 years of React experience. I want to advance to senior level and learn backend technologies. What's the recommended career path, skills, and technologies I should focus on?''',
    },
    {
      'title': '📊 Data & AI Path',
      'icon': Icons.analytics,
      'color': Color(0xFF7209B7),
      'gradient': [Color(0xFF7209B7), Color(0xFF6308A0)],
      'content': '''I'm interested in data science and AI. I have a mathematics/statistics background and know Python basics. What entry-level roles exist in data field? Provide a comprehensive 12-month learning roadmap with project suggestions.''',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _addToConsole('🚀 Career Guide AI initialized');
    _addToConsole('💡 Choose a template or start speaking');
  }

  void _initSpeech() async {
    await Permission.microphone.request();
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && _isListening) {
          _stopListening();
        }
      },
      onError: (error) {
        _addToConsole('❌ Speech error: $error');
        _stopListening();
      },
    );

    if (available) {
      _addToConsole('🎤 Speech recognition ready');
    } else {
      _addToConsole('❌ Speech recognition not available');
    }
  }

  void _startListening() async {
    if (!await _speech.isAvailable) {
      _addToConsole('❌ Speech recognition not available');
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _showDashboard = false;
    });

    _addToConsole('🎤 Listening... Speak now about your career goals');

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
          _textEditingController.text = result.recognizedWords;
        });

        if (result.finalResult) {
          _addToConsole('💬 Speech captured: ${result.recognizedWords}');
        }
      },
      listenFor: const Duration(minutes: 3),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
    _addToConsole('⏹️ Stopped listening');

    if (_recognizedText.isNotEmpty) {
      _sendToAI(_recognizedText);
    }
  }

  void _useTemplate(String template) {
    setState(() {
      _recognizedText = template;
      _textEditingController.text = template;
      _showTemplates = false;
    });
    _addToConsole('📝 Template applied - Ready to analyze');
  }

  void _manualSend() {
    final text = _textEditingController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _recognizedText = text;
      });
      _sendToAI(text);
    } else {
      _addToConsole('❌ Please enter some text first');
    }
  }

  Future<void> _sendToAI(String text) async {
    if (text.trim().isEmpty) {
      _addToConsole('❌ Please provide some input first');
      return;
    }

    setState(() {
      _isLoading = true;
      _showDashboard = false;
      _currentStep = 1;
    });

    _addToConsole('🚀 Analyzing your career profile...');

    try {
      final response = await _callOpenAIApi(text);
      _addToConsole('✅ Analysis complete');
      setState(() {
        _aiResponse = response;
        _parsedResponse = _parseAIResponse(response);
        _currentStep = 2;
        _isLoading = false;
      });
    } catch (e) {
      _addToConsole('❌ Analysis failed: $e');
      setState(() {
        _isLoading = false;
        _currentStep = 0;
      });
    }
  }

  Future<String> _callOpenAIApi(String text) async {
    final apiKey = dotenv.env['OPENROUTER_API'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OPENROUTER_API key not configured');
    }

    const baseUrl = "https://openrouter.ai/api/v1";

    final enhancedPrompt = """
As a career guidance expert, analyze this career query and provide structured guidance:

INPUT: $text

Please structure your response EXACTLY as follows:

Career Field: [Main career field with brief description]
Recommended Roles: [3-5 specific job titles with brief descriptions]
Required Skills: [6-8 essential technical and soft skills]
Learning Path: [Step-by-step 6-12 month learning journey]
Resources: [Specific courses, platforms, books - max 5]
Timeline: [Realistic timeline with milestones]
Market Outlook: [Job market trends, salary ranges, demand]

Be specific, practical, and actionable. Focus on immediate next steps.
""";

    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'http://localhost:3000',
        'X-Title': 'Career Guide AI',
      },
      body: jsonEncode({
        'model': 'x-ai/grok-4-fast:free',
        'messages': [
          {'role': 'user', 'content': enhancedPrompt},
        ],
        'stream': false,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('API Error: ${response.statusCode}');
    }
  }

  Map<String, dynamic> _parseAIResponse(String response) {
    final Map<String, dynamic> parsed = {};
    final lines = response.split('\n');
    
    String currentSection = '';
    for (final line in lines) {
      if (line.contains(':')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          currentSection = parts[0].trim();
          parsed[currentSection] = parts.sublist(1).join(':').trim();
        }
      } else if (currentSection.isNotEmpty && line.trim().isNotEmpty) {
        parsed[currentSection] = '${parsed[currentSection]}\n${line.trim()}';
      }
    }
    
    // Ensure all sections exist
    final sections = [
      'Career Field', 'Recommended Roles', 'Required Skills', 
      'Learning Path', 'Resources', 'Timeline', 'Market Outlook'
    ];
    
    for (final section in sections) {
      parsed.putIfAbsent(section, () => 'Information not available');
    }
    
    return parsed;
  }

  void _addToConsole(String message) {
    setState(() {
      _consoleOutput.add(
        '${DateTime.now().toString().split(' ')[1].substring(0, 8)} - $message',
      );
    });
  }

  void _clearConsole() {
    setState(() {
      _consoleOutput.clear();
    });
    _addToConsole('Console cleared');
  }

  void _navigateToDashboard() async {
    setState(() {
      _isLoadingDashboard = true;
      _currentStep = 3;
    });

    _addToConsole('🎨 Building your personalized dashboard...');

    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _isLoadingDashboard = false;
      _showDashboard = true;
      _currentStep = 4;
    });

    _addToConsole('✅ Dashboard ready!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isLoadingDashboard)
            _buildLoadingScreen()
          else if (_showDashboard && _parsedResponse != null)
            _buildDashboard()
          else
            _buildMainScreen(),
          
          // Console Dialog
          if (_showConsole) _buildConsoleDialog(),
        ],
      ),
    );
  }

  Widget _buildMainScreen() {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      floatingActionButton: _consoleOutput.isNotEmpty ? _buildFloatingConsoleButton() : null,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Progress Steps
            _buildProgressSteps(),
            
            // Main Content
            Expanded(
              child: _showTemplates ? _buildTemplatesView() : _buildInputView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: Color(0xFF06D6A0), size: 28),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Career Guide AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Your Personal Career Assistant',
                style: TextStyle(
                  color: Colors.blueGrey[300],
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Spacer(),
          if (_consoleOutput.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueGrey[800],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_consoleOutput.length}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    final steps = ['Input', 'Analysis', 'Ready', 'Dashboard'];
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(
          bottom: BorderSide(color: Colors.blueGrey[800]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isActive = index <= _currentStep;
          
          return Container(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? Color(0xFF4361EE) : Colors.blueGrey[600],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isActive 
                      ? Icon(Icons.check, color: Colors.white, size: 14)
                      : Text('${index + 1}', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  step,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.blueGrey[400],
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTemplatesView() {
    return Column(
      children: [
        // Header
        Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Choose Your Starting Point',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Select a template that matches your situation or create your own',
                style: TextStyle(
                  color: Colors.blueGrey[300],
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        // Templates Grid
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final template = _templates[index];
                return _buildTemplateCard(template);
              },
            ),
          ),
        ),
        
        // Custom Input Button
        Container(
          padding: EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showTemplates = false;
              });
            },
            icon: Icon(Icons.create, size: 18),
            label: Text('Create Custom Input'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blueGrey[600]!),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: template['gradient'] as List<Color>,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _useTemplate(template['content']),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(template['icon'] as IconData, 
                      color: Colors.white, size: 28),
                  SizedBox(height: 10),
                  Text(
                    template['title'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      template['content'],
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Use This',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputView() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Describe Your Career Goals',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // Text Input Area
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _textEditingController,
                            maxLines: null,
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Tell me about your background, skills, interests, and career aspirations...\n\nExamples:\n• "I\'m a student looking for my first tech job"\n• "I want to transition from marketing to tech"\n• "I\'m a developer wanting to advance my career"',
                              hintStyle: TextStyle(color: Colors.blueGrey[400], fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Voice Controls
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isListening ? null : _startListening,
                                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 18),
                                label: Text(_isListening ? 'Listening...' : 'Start Voice Input'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isListening ? Colors.green : Color(0xFF4361EE),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isListening ? _stopListening : null,
                                icon: Icon(Icons.stop, size: 18),
                                label: Text('Stop'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      // Action Buttons
                      Column(
                        children: [
                          // Analyze Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _manualSend,
                              icon: _isLoading 
                                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : Icon(Icons.analytics, size: 18),
                              label: _isLoading ? Text('Analyzing...') : Text('Analyze Career Path'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isLoading ? Colors.blueGrey : Color(0xFF06D6A0),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 8),
                          
                          // Dashboard Button (conditionally shown)
                          if (_aiResponse.isNotEmpty && !_isLoading)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _navigateToDashboard,
                                icon: Icon(Icons.dashboard, size: 18),
                                label: Text('View Dashboard'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF7209B7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          
                          SizedBox(height: 8),
                          
                          // Back to Templates
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _showTemplates = true;
                              });
                            },
                            icon: Icon(Icons.arrow_back, size: 16),
                            label: Text('Back to Templates'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blueGrey[300],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingConsoleButton() {
    return FloatingActionButton(
      onPressed: () {
        setState(() {
          _showConsole = true;
        });
      },
      backgroundColor: Color(0xFF4361EE),
      foregroundColor: Colors.white,
      child: Stack(
        children: [
          Icon(Icons.terminal, size: 24),
          if (_consoleOutput.isNotEmpty)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_consoleOutput.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConsoleDialog() {
    return Dialog(
      backgroundColor: Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.terminal, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Activity Log',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.clear, color: Colors.white, size: 20),
                  onPressed: () {
                    setState(() {
                      _showConsole = false;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Clear Button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _clearConsole,
                icon: Icon(Icons.clear_all, size: 16),
                label: Text('Clear Log'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blueGrey[300],
                ),
              ),
            ),
            
            // Console Content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _consoleOutput.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.info, color: Colors.blueGrey[600], size: 40),
                            SizedBox(height: 8),
                            Text(
                              'No activity yet',
                              style: TextStyle(
                                color: Colors.blueGrey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _consoleOutput.length,
                        itemBuilder: (context, index) {
                          final message = _consoleOutput[index];
                          Color textColor = Colors.white;
                          IconData? icon;
                          
                          if (message.contains('🎤')) {
                            textColor = Colors.green;
                            icon = Icons.mic;
                          } else if (message.contains('🤖')) {
                            textColor = Colors.cyan;
                            icon = Icons.psychology;
                          } else if (message.contains('❌')) {
                            textColor = Colors.red;
                            icon = Icons.error;
                          } else if (message.contains('🚀')) {
                            textColor = Colors.orange;
                            icon = Icons.rocket_launch;
                          } else if (message.contains('⏹️')) {
                            textColor = Colors.yellow;
                            icon = Icons.stop;
                          } else if (message.contains('💬')) {
                            textColor = Colors.lightGreen;
                            icon = Icons.message;
                          } else if (message.contains('📝')) {
                            textColor = Colors.lightBlue;
                            icon = Icons.assignment;
                          } else if (message.contains('✅')) {
                            textColor = Colors.lightGreen;
                            icon = Icons.check_circle;
                          } else if (message.contains('🎨')) {
                            textColor = Colors.purple;
                            icon = Icons.dashboard;
                          } else if (message.contains('💡')) {
                            textColor = Colors.amber;
                            icon = Icons.lightbulb;
                          }
                          
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.blueGrey[800]!),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (icon != null) ...[
                                  Icon(icon, color: textColor, size: 16),
                                  SizedBox(width: 8),
                                ],
                                Expanded(
                                  child: Text(
                                    message,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontFamily: 'JetBrains Mono',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon
            Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 60,
            ),
            SizedBox(height: 20),
            
            // Progress Indicator
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4361EE)),
              ),
            ),
            SizedBox(height: 20),
            
            // Text
            Column(
              children: [
                Text(
                  'Building Your Career Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Creating personalized recommendations...',
                  style: TextStyle(
                    color: Colors.blueGrey[300],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // Progress Bar
            SizedBox(
              width: 250,
              child: LinearProgressIndicator(
                backgroundColor: Colors.blueGrey[700],
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF06D6A0)),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium, color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Your Career Dashboard',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.refresh, color: Colors.white, size: 20),
                        onPressed: () {
                          setState(() {
                            _showDashboard = false;
                            _currentStep = 0;
                          });
                        },
                        tooltip: 'New Analysis',
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Personalized career path based on your profile',
                    style: TextStyle(
                      color: Colors.blueGrey[300],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            
            // Dashboard Content
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  _buildDashboardCard(
                    icon: Icons.work_outline,
                    title: 'Career Field',
                    content: _parsedResponse!['Career Field'],
                    gradient: [Color(0xFF4361EE), Color(0xFF3A56E0)],
                  ),
                  _buildDashboardCard(
                    icon: Icons.business_center,
                    title: 'Recommended Roles',
                    content: _parsedResponse!['Recommended Roles'],
                    gradient: [Color(0xFF06D6A0), Color(0xFF05C191)],
                  ),
                  _buildDashboardCard(
                    icon: Icons.build,
                    title: 'Required Skills',
                    content: _parsedResponse!['Required Skills'],
                    gradient: [Color(0xFFFF9E00), Color(0xFFE68E00)],
                  ),
                  _buildDashboardCard(
                    icon: Icons.timeline,
                    title: 'Learning Path',
                    content: _parsedResponse!['Learning Path'],
                    gradient: [Color(0xFF7209B7), Color(0xFF6308A0)],
                  ),
                  _buildDashboardCard(
                    icon: Icons.library_books,
                    title: 'Learning Resources',
                    content: _parsedResponse!['Resources'],
                    gradient: [Color(0xFFEF476F), Color(0xFFD63E62)],
                  ),
                  _buildDashboardCard(
                    icon: Icons.schedule,
                    title: 'Timeline',
                    content: _parsedResponse!['Timeline'],
                    gradient: [Color(0xFF118AB2), Color(0xFF0F7A9E)],
                  ),
                  _buildDashboardCard(
                    icon: Icons.trending_up,
                    title: 'Market Outlook',
                    content: _parsedResponse!['Market Outlook'],
                    gradient: [Color(0xFF073B4C), Color(0xFF052E3B)],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required IconData icon,
    required String title,
    required String content,
    required List<Color> gradient,
  }) {
    return Card(
      elevation: 6,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _textEditingController.dispose();
    super.dispose();
  }
}