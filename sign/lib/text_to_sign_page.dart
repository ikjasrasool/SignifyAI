import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;

class TextToSignPage extends StatefulWidget {
  @override
  _TextToSignPageState createState() => _TextToSignPageState();
}

class _TextToSignPageState extends State<TextToSignPage> {
  TextEditingController _textController = TextEditingController();
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  String? _videoPath;

  // Speech-to-text
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  // Start/stop listening
  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          print('Status: $val');
          if (val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          print('Error: $val');
          setState(() => _isListening = false);
        },
      );

      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: "en_US",
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
            });
            if (val.finalResult) {
              _speech.stop();
              setState(() => _isListening = false);
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // Generate video from text (via backend)
  Future<void> _generateVideo() async {
    // Close keyboard
    FocusScope.of(context).unfocus();

    String text = _textController.text.trim();
    if (text.isEmpty) {
      _showAlert(
          "Please Enter Text", "Add some text or use mic to generate sign language");
      return;
    }

    setState(() {
      _isLoading = true;
      _videoController?.pause();
      _videoController?.dispose();
      _videoPath = null;
    });

    try {
      var response = await http.post(
        Uri.parse(
            'https://alberto-unlocal-clerkly.ngrok-free.dev/generate_video'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text}),
      );

      if (response.statusCode == 200) {
        Directory dir = await getApplicationDocumentsDirectory();
        String path = "${dir.path}/generated.mp4";

        File file = File(path);
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          _videoPath = path;
          _videoController = VideoPlayerController.file(File(_videoPath!))
            ..initialize().then((_) {
              _videoController?.setLooping(true);
              _videoController?.play();
              setState(() {});
            });
        });
      } else {
        _showAlert("Generation Failed", "Unable to create sign language video");
      }
    } catch (e) {
      print("Video Error: $e");
      _showAlert("Error", "Something went wrong while generating video");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Color(0xFF1a1a2e),
        title: Text(title, style: TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Color(0xFFa0a0b2))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: Color(0xFF4facfe))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _textController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0a0a0f),
      appBar: AppBar(
        backgroundColor: Color(0xFF1a1a2e),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Text to Sign Language',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Gradient
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.sign_language, size: 48, color: Color(0xFF4facfe)),
                  SizedBox(height: 12),
                  Text(
                    "AI-Powered Sign Language Translation",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Breaking communication barriers with technology",
                    style: TextStyle(fontSize: 13, color: Color(0xFFa0a0b2)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  children: [
                    // Input Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit, color: Color(0xFF4facfe), size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Enter your message",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF1a1a2e),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Color(0xFF2a2a3e)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _textController,
                            maxLines: 4,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.all(20),
                              hintText: "Type your message or use the microphone...",
                              hintStyle: TextStyle(color: Color(0xFF7c7c8a)),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (value) {
                              FocusScope.of(context).unfocus();
                              _generateVideo();
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _isLoading ? null : _generateVideo,
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: _isLoading
                                    ? LinearGradient(
                                    colors: [Color(0xFF7c7c8a), Color(0xFF5c5c6a)])
                                    : LinearGradient(
                                    colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF4facfe).withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Generating...",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                                    : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      "Generate Sign Language",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            gradient: _isListening
                                ? LinearGradient(colors: [Colors.redAccent, Colors.red])
                                : LinearGradient(
                                colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? Colors.red : Color(0xFF4facfe))
                                    .withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: FloatingActionButton(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            onPressed: _listen,
                            child: Icon(
                              _isListening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    // AI Avatar Display (Larger Square video without black bars)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 0), // Remove extra padding
                      child: AspectRatio(
                        aspectRatio: 1, // Square aspect ratio
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF1a1a2e),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Color(0xFF2a2a3e), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: _videoPath != null &&
                                _videoController != null &&
                                _videoController!.value.isInitialized
                                ? Stack(
                              children: [
                                // Video Player (centered and cropped to fill square)
                                Positioned.fill(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _videoController!.value.size.width,
                                      height: _videoController!.value.size.height,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                  ),
                                ),
                                // Gradient overlay at bottom
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.7),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // AI Avatar Badge
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF4facfe),
                                          Color(0xFF00f2fe)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(0xFF4facfe).withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "AI Avatar",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Live indicator
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.play_circle_filled,
                                          color: Colors.greenAccent,
                                          size: 16,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          "SIGNING",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                                : Container(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF4facfe).withOpacity(0.3),
                                            Color(0xFF00f2fe).withOpacity(0.3),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: Color(0xFF4facfe).withOpacity(0.5),
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Color(0xFF7c7c8a),
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      "AI Avatar Ready",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      "Your sign language avatar\nwill appear here",
                                      style: TextStyle(
                                        color: Color(0xFF7c7c8a),
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Info cards
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFF1a1a2e),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF2a2a3e)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.speed, color: Color(0xFF4facfe), size: 28),
                                SizedBox(height: 8),
                                Text(
                                  "Real-time",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Instant translation",
                                  style: TextStyle(
                                    color: Color(0xFF7c7c8a),
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFF1a1a2e),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF2a2a3e)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.verified, color: Color(0xFF4facfe), size: 28),
                                SizedBox(height: 8),
                                Text(
                                  "Accurate",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "AI-powered signs",
                                  style: TextStyle(
                                    color: Color(0xFF7c7c8a),
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Color(0xFF1a1a2e),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF2a2a3e)),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.all_inclusive, color: Color(0xFF4facfe), size: 28),
                                SizedBox(height: 8),
                                Text(
                                  "Inclusive",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Bridge gaps",
                                  style: TextStyle(
                                    color: Color(0xFF7c7c8a),
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
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
}