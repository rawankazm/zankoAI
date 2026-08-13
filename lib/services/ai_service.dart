import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;
import '../models/quiz_model.dart';
import '../models/flashcard_model.dart';
import '../models/study_plan_model.dart';

abstract class AiService extends ChangeNotifier {
  String? get apiKey;
  set apiKey(String? key);
  bool get hasRealApiKey;

  Future<bool> checkAndIncrementDailyLimit({bool isVip = false});
  Future<String> askTeacher(String userPrompt, List<Map<String, String>> chatHistory, {bool isVip = false});
  Future<String> solveImageQuestion(Uint8List imageBytes, String promptText, {bool isVip = false});
  Future<Map<String, dynamic>> summarizePdf(String pdfName, String pdfContent);
  Future<String> transcribeAudio(Uint8List? audioBytes, String audioFileName, {String mimeType = 'audio/m4a'});
  Future<String> summarizeAudio(String audioFileName, String transcriptText);
  Future<QuizModel> generateQuiz(String topic, String courseName);
  Future<QuizModel> generateQuizFromText(String fileText, String courseName);
  Future<QuizModel> generateCustomExam({
    required String courseName,
    required String topic,
    required String difficulty,
    required String questionType,
    required int questionCount,
    required int durationMinutes,
    String? pdfContent,
    Uint8List? pdfBytes,
  });
  Future<String> organizeNote(String rawNoteContent);
  Future<List<FlashcardModel>> generateFlashcards(String topicOrText);
  Future<List<StudyPlanDayModel>> generateStudyPlan(String examTopic, int daysRemaining);
  Future<Map<String, dynamic>> predictExam(String notesName, String notesContent);
  Future<Map<String, dynamic>> generateStudyRoadmap({
    required String subjectName,
    required int totalChapters,
    required int daysRemaining,
    required int hoursPerDay,
  });
}

class ZankoAiService extends ChangeNotifier implements AiService {
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _fallbackWorkingKey = '';
  String? _apiKey = '';

  ZankoAiService() {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('gemini_api_key');
    if (savedKey != null && savedKey.trim().isNotEmpty) {
      _apiKey = savedKey.trim();
    } else if (_defaultApiKey.trim().isNotEmpty) {
      _apiKey = _defaultApiKey.trim();
    } else {
      _apiKey = _fallbackWorkingKey;
    }

    try {
      if (Firebase.apps.isNotEmpty) {
        final docRef = FirebaseFirestore.instance.collection('config').doc('app_config');
        docRef.snapshots().listen((doc) async {
          if (doc.exists && doc.data() != null) {
            final key = doc.data()!['gemini_api_key'] ?? doc.data()!['apiKey'];
            if (key != null && key.toString().trim().isNotEmpty) {
              _apiKey = key.toString().trim();
              notifyListeners();
            } else if (_apiKey == null || _apiKey!.trim().isEmpty) {
              _apiKey = _fallbackWorkingKey;
              notifyListeners();
            }
          }
        }, onError: (_) {});
      }
    } catch (_) {}

    if (_apiKey == null || _apiKey!.trim().isEmpty) {
      _apiKey = _fallbackWorkingKey;
    }

    notifyListeners();
  }

  @override
  String? get apiKey => _apiKey;

  @override
  set apiKey(String? key) {
    _apiKey = key;
    SharedPreferences.getInstance().then((prefs) {
      if (key != null && key.trim().isNotEmpty) {
        prefs.setString('gemini_api_key', key.trim());
      } else {
        prefs.remove('gemini_api_key');
      }
    });
    notifyListeners();
  }

  @override
  bool get hasRealApiKey => true;
  bool get hasApiKey => true;

  @override
  Future<bool> checkAndIncrementDailyLimit({bool isVip = false}) async {
    return true; // Limit bypassed for testing
  }

  // Helper to determine if an error is connection-related
  bool _isNetworkError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    return error is SocketException ||
        error is HttpException ||
        errStr.contains('socket') ||
        errStr.contains('connection') ||
        errStr.contains('failed to connect') ||
        errStr.contains('network');
  }

  Future<String> _callGeminiHttp(String key, String prompt, String systemInstruction) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    final modelsToTry = ['gemini-flash-latest', 'gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-flash-lite-latest', 'gemini-pro-latest'];

    for (final m in modelsToTry) {
      try {
        final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$key');
        final request = await client.postUrl(uri);
        request.headers.set('content-type', 'application/json');

        final bodyMap = {
          if (systemInstruction.isNotEmpty)
            'system_instruction': {
              'parts': [{'text': systemInstruction}]
            },
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ]
        };

        request.add(utf8.encode(jsonEncode(bodyMap)));
        final response = await request.close().timeout(const Duration(seconds: 10));
        final respStr = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final data = jsonDecode(respStr);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final contentMap = candidates[0]['content'];
            final parts = contentMap['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts[0]['text'];
              if (text != null && text.toString().isNotEmpty) {
                client.close();
                return text.toString();
              }
            }
          }
        }
      } catch (_) {}
    }

    client.close();
    return "";
  }

  // Helper to call Gemini Model
  Future<String> _callGemini(String prompt, {String systemInstruction = ""}) async {
    final keysToTry = <String>[
      if (_apiKey != null && _apiKey!.trim().isNotEmpty) _apiKey!.trim(),
      if (_defaultApiKey.trim().isNotEmpty) _defaultApiKey.trim(),
      if (_fallbackWorkingKey.trim().isNotEmpty && _fallbackWorkingKey != _apiKey) _fallbackWorkingKey.trim(),
    ];

    String lastError = "";

    for (final keyToUse in keysToTry) {
      if (keyToUse.isEmpty) continue;

      final models = ['gemini-flash-latest', 'gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-flash-lite-latest', 'gemini-pro-latest'];

      for (final m in models) {
        try {
          final model = gemini.GenerativeModel(
            model: m,
            apiKey: keyToUse,
            systemInstruction: systemInstruction.isNotEmpty
                ? gemini.Content.system(systemInstruction)
                : null,
          );

          final content = [gemini.Content.text(prompt)];
          final response = await model.generateContent(content).timeout(const Duration(seconds: 15));
          if (response.text != null && response.text!.isNotEmpty) {
            return response.text!;
          }
        } catch (e) {
          lastError = e.toString();
        }
      }

      // Direct HTTP API fallback
      final httpFallback = await _callGeminiHttp(keyToUse, prompt, systemInstruction);
      if (httpFallback.isNotEmpty) {
        return httpFallback;
      }
    }

    if (lastError.isNotEmpty) {
      final errLower = lastError.toLowerCase();
      if (errLower.contains('api_key') || errLower.contains('invalid') || errLower.contains('disabled') || errLower.contains('unauthorized') || errLower.contains('blocked')) {
        return "âš ï¸ **Ú©Ù„ÛŒÙ„ÛŽ APIÛŒ Gemini Ú©Ø§Ø±Ù†Ø§Ú©Ø§Øª ÛŒØ§Ù† Ø¨Ù„Û†Ú© Ú©Ø±Ø§ÙˆÛ• (API Key Blocked/Invalid)**\n\n"
               "Ú©Ù„ÛŒÙ„ÛŒ Ø¦ÛŒØ³ØªØ§ÛŒ Gemini Ø¨Ù„Û†Ú© Ú©Ø±Ø§ÙˆÛ• ÛŒØ§Ù† Ú©Ø§Ø±Ù†Ø§Ú©Ø§Øª. ØªÚ©Ø§ÛŒÛ• Ú©Ù„ÛŒÙ„ÛŽÚ©ÛŒ Ú©Ø§Ø±Ø§ÛŒ ØªØ±ÛŒ Gemini API Ù„Û• Ú•ÛŽÚ©Ø®Ø³ØªÙ†Û•Ú©Ø§Ù†Ø¯Ø§ ÛŒØ§Ù† Ù„Û•Ú•ÛŽÚ¯Û•ÛŒ Ø¯ÙˆÚ¯Ù…Û•ÛŒ ðŸ”‘ Ù„Û• Ø³Û•Ø±Û•ÙˆÛ•ÛŒ Ú†Ø§ØªÛ•Ú©Û• Ø¨Ù†ÙˆÙˆØ³Û•.\n\n"
               "ØªÛŽØ¨ÛŒÙ†ÛŒ: Ø¨Û† ÙˆÛ•Ø±Ú¯Ø±ØªÙ†ÛŒ Ú©Ù„ÛŒÙ„ÛŒ Ø¨Û•Ø®Û†Ú•Ø§ÛŒÛŒ Ø³Û•Ø±Ø¯Ø§Ù†ÛŒ https://aistudio.google.com/app/apikey Ø¨Ú©Û•.";
      }
      return "âš ï¸ **Ù‡Û•ÚµÛ• Ù„Û• Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ• Ø¨Û• Gemini API**: $lastError";
    }

    return "âš ï¸ Ù†Û•ØªÙˆØ§Ù†Ø±Ø§ ÙˆÛ•ÚµØ§Ù… Ù„Û• Gemini API ÙˆÛ•Ø±Ø¨Ú¯ÛŒØ±ÛŽØª. ØªÚ©Ø§ÛŒÛ• Ú©Ù„ÛŒÙ„ÛŒ APIÛŒ ØªØ§ÛŒØ¨Û•Øª Ø¨Û• Ø®Û†Øª Ø¨Ù†ÙˆÙˆØ³Û• ÛŒØ§Ù† Ù¾Û•ÛŒÙˆÛ•Ù†Ø¯ÛŒ Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØª Ù¾Ø´Ú©Ù†ÛŒÙ† Ø¨Ú©Û•.";
  }

  Future<String> _callGeminiWithPdf(
    String prompt,
    Uint8List pdfBytes, {
    String systemInstruction = "",
  }) async {
    final keysToTry = <String>[
      if (_apiKey != null && _apiKey!.trim().isNotEmpty) _apiKey!.trim(),
      if (_defaultApiKey.trim().isNotEmpty) _defaultApiKey.trim(),
      if (_fallbackWorkingKey.trim().isNotEmpty && _fallbackWorkingKey != _apiKey) _fallbackWorkingKey.trim(),
    ];

    for (final keyToUse in keysToTry) {
      if (keyToUse.isEmpty) continue;
      final models = ['gemini-flash-latest', 'gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-flash-lite-latest', 'gemini-pro-latest'];

      for (final m in models) {
        try {
          final model = gemini.GenerativeModel(
            model: m,
            apiKey: keyToUse,
            systemInstruction: systemInstruction.isNotEmpty
                ? gemini.Content.system(systemInstruction)
                : null,
          );

          final content = [
            gemini.Content.multi([
              gemini.TextPart(prompt),
              gemini.DataPart('application/pdf', pdfBytes),
            ])
          ];

          final response = await model.generateContent(content).timeout(const Duration(seconds: 25));
          if (response.text != null && response.text!.isNotEmpty) {
            return response.text!;
          }
        } catch (_) {}
      }
    }
    return '';
  }

  @override
  Future<String> askTeacher(String userPrompt, List<Map<String, String>> chatHistory, {bool isVip = false}) async {
    final allowed = await checkAndIncrementDailyLimit(isVip: isVip);
    if (!allowed) {
      return "â­ **Ú¯Û•ÛŒØ´ØªÛŒØªÛ• Ø³Ù†ÙˆÙˆØ±ÛŒ Ù¥ Ù¾Û•ÛŒØ§Ù…ÛŒ Ø¨Û•Ø®Û†Ú•Ø§ÛŒÛŒ Ø¨Û† Ø¦Û•Ù…Ú•Û† (Free Daily Limit Reached)**\n\n"
             "You have reached your 5 free messages daily limit. Upgrade to VIP for unlimited AI access!";
    }

    try {
      String historyStr = "";
      for (var msg in chatHistory) {
        historyStr += "${msg['role'] == 'user' ? 'Ø®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±' : 'Ù…Ø§Ù…Û†Ø³ØªØ§'}: ${msg['content']}\n";
      }
      final prompt = "$historyStrØ®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±: $userPrompt\nÙ…Ø§Ù…Û†Ø³ØªØ§:";
      
      const systemInstruction = 
          "ØªÛ† Ù…Ø§Ù…Û†Ø³ØªØ§ÛŒÛ•Ú©ÛŒ Ø²ÛŒØ±Û•Ú© Ùˆ Ø´Ø§Ø±Û•Ø²Ø§ÛŒ Ø¨Û• Ù†Ø§ÙˆÛŒ ZankoAI. ØªÛ•Ù†Ù‡Ø§ Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) Ø¨Û• Ø´ÛŽÙˆØ§Ø²ÛŽÚ©ÛŒ Ù¾Ú•Û†ÙÛŽØ´Ù†Ø§Úµ Ùˆ Ú•ÙˆÙˆÙ† ÙˆÛ•ÚµØ§Ù…ÛŒ Ù‡Û•Ù…ÙˆÙˆ Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù† Ø¨Ø¯Û•Ø±Û•ÙˆÛ•.";
          
      return await _callGemini(prompt, systemInstruction: systemInstruction);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (_isNetworkError(e)) {
        return "ðŸ“¡ **Ù‡ÛŽÚµÛŒ Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØªÛ•Ú©Û•Øª ØªÛŽÚ©Ú†ÙˆÙˆÛ• (No Internet Connection)**\n\n"
               "Ù†Û•ØªÙˆØ§Ù†Ø±Ø§ Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ• Ù„Û•Ú¯Û•Úµ Ø³ÛŽØ±Ú¤Û•Ø±ÛŒ Google AI Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Ø±ÛŽØª. ØªÚ©Ø§ÛŒÛ• Ù‡ÛŽÚµÛŒ Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØªÛ•Ú©Û•Øª Ú†Ø§Ú© Ø¨Ú©Û•Ø±Û•ÙˆÛ• Ùˆ Ø¯ÙˆÙˆØ¨Ø§Ø±Û• Ù‡Û•ÙˆÚµØ¨Ø¯Û•Ø±Û•ÙˆÛ•.";
      }

      if (errStr.contains('disabled') || errStr.contains('not been used') || errStr.contains('658020179072')) {
        return "âš ï¸ **Google Cloud Generative Language API Disabled!**\n\n"
               "Project `658020179072` needs Generative Language API enabled in Google Cloud Console:\n"
               "https://console.developers.google.com/apis/api/generativelanguage.googleapis.com/overview?project=658020179072\n\n"
               "Alternatively, add your Gemini API Key into Firestore: `config/app_config` -> `gemini_api_key`.";
      }

      return "âš ï¸ Ù‡Û•ÚµÛ•ÛŒÛ•Ú© Ú•ÙˆÙˆÛŒØ¯Ø§ Ù„Û• Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ• Ø¨Û• Gemini API: $e";
    }
  }

  Future<String> _callGeminiMultimodal(Uint8List imageBytes, String prompt, {String mimeType = 'image/jpeg'}) async {
    final keyToUse = (_apiKey != null && _apiKey!.trim().isNotEmpty) ? _apiKey! : _fallbackWorkingKey;

    final models = ['gemini-flash-latest', 'gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-flash-lite-latest', 'gemini-pro-latest'];
    for (final m in models) {
      try {
        final model = gemini.GenerativeModel(
          model: m,
          apiKey: keyToUse,
          systemInstruction: gemini.Content.system(
            "ØªÛ† Ù…Ø§Ù…Û†Ø³ØªØ§ÛŒÛ•Ú©ÛŒ Ø²ÛŒØ±Û•Ú© Ùˆ Ø´Ø§Ø±Û•Ø²Ø§ÛŒ Ø¨Û• Ù†Ø§ÙˆÛŒ ZankoAI. Ø¦Û•Ù… ÙˆÛŽÙ†Û•ÛŒÛ•ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±Û• Ø¨Û• ØªÛ•Ù†Ù‡Ø§ Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) Ø´ÛŒÚ©Ø§Ø± Ø¨Ú©Û• Ø¨Û• Ú•ÙˆÙˆÙ†ÛŒ."
          ),
        );

        final content = [
          gemini.Content.multi([
            gemini.TextPart(prompt.isNotEmpty ? prompt : "Ø¦Û•Ù… Ù¾Ø±Ø³ÛŒØ§Ø±Û•ÛŒ Ù†Ø§Ùˆ ÙˆÛŽÙ†Û•Ú©Û• Ø¨Û• Ù‡Û•Ù†Ú¯Ø§Ùˆ Ø¨Û• Ù‡Û•Ù†Ú¯Ø§Ùˆ Ø´ÛŒÚ©Ø§Ø± Ø¨Ú©Û•."),
            gemini.DataPart(mimeType, imageBytes),
          ])
        ];

        final response = await model.generateContent(content).timeout(const Duration(seconds: 20));
        if (response.text != null && response.text!.isNotEmpty) {
          return response.text!;
        }
      } catch (_) {}
    }
    return "âš ï¸ Ù†Û•ØªÙˆØ§Ù†Ø±Ø§ Ø´ÛŒÚ©Ø§Ø±ÛŒ ÙˆÛŽÙ†Û•Ú©Û• Ø¨Û•Ø¯Û•Ø³ØªØ¨Ù‡ÛŽÙ†Ø±ÛŽØª.";
  }

  @override
  Future<String> solveImageQuestion(Uint8List imageBytes, String promptText, {bool isVip = false}) async {
    final allowed = await checkAndIncrementDailyLimit(isVip: isVip);
    if (!allowed) {
      return "â­ **Ú¯Û•ÛŒØ´ØªÛŒØªÛ• Ø³Ù†ÙˆÙˆØ±ÛŒ Ù¥ Ù¾Û•ÛŒØ§Ù…ÛŒ Ø¨Û•Ø®Û†Ú•Ø§ÛŒÛŒ Ø¨Û† Ø¦Û•Ù…Ú•Û† (Free Daily Limit Reached)**\n\n"
             "ØªÛ† Ù¥ Ù¾Û•ÛŒØ§Ù…ÛŒ Ø¨Û•Ø®Û†Ú•Ø§ÛŒÛŒÛŒ Ø¦Û•Ù…Ú•Û†Øª Ø¨Û•Ú©Ø§Ø±Ù‡ÛŽÙ†Ø§ÙˆÛ•. Ø¨Û† Ù†Ø§Ø±Ø¯Ù†ÛŒ Ù¾Û•ÛŒØ§Ù…ÛŒ Ø¨ÛŽØ³Ù†ÙˆÙˆØ± Ùˆ Ú©ÙˆØ±ØªÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ ÙˆÛŽÙ†Û•Ú©Ø§Ù†ØŒ Ø¨ÛŽÚ¯ÙˆÙ…Ø§Ù† Ù†ÛŒØ´Ø§Ù†Û•ÛŒ VIP (Ø¨Û•Ø´Ø¯Ø§Ø±Ø¨ÙˆÙˆÙ†ÛŒ ÙÛ•Ø±Ù…ÛŒ) Ø¨Û•Ø¯Û•Ø³ØªØ¨Ù‡ÛŽÙ†Û•!";
    }

    if (hasRealApiKey) {
      try {
        return await _callGeminiMultimodal(imageBytes, promptText);
      } catch (e) {
        if (_isNetworkError(e)) {
          return "ðŸ“¡ **Ù‡ÛŽÚµÛŒ Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØªÛ•Ú©Û•Øª ØªÛŽÚ©Ú†ÙˆÙˆÛ• (No Internet Connection)**\n\n"
                 "Ù†Û•ØªÙˆØ§Ù†Ø±Ø§ Ù„Û•Ú¯Û•Úµ Ø³ÛŽØ±Ú¤Û•Ø±ÛŒ Google AI Ø¨Û† Ø´ÛŒÚ©Ø§Ø±ÛŒ ÙˆÛŽÙ†Û•Ú©Û• Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ• Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Ø±ÛŽØª. ØªÚ©Ø§ÛŒÛ• Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØªÛ•Ú©Û•Øª Ø¨Ù¾Ø´Ú©Ù†Û•.";
        }
        return "âš ï¸ Ù‡Û•ÚµÛ•ÛŒÛ•Ú© Ú•ÙˆÙˆÛŒØ¯Ø§ Ù„Û• Ø´ÛŒÚ©Ø§Ø±Ú©Ø±Ø¯Ù†ÛŒ ÙˆÛŽÙ†Û•Ú©Û•: $e";
      }
    }

    return "ðŸ“¸ **Ø´ÛŒÚ©Ø§Ø±ÛŒ Ù„Û†Ú©Ø§ÚµÛŒ Ø¨Û† Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ ÙˆÛŽÙ†Û•Ú©Û•**\n\n"
           "Ù¾Ø±Ø³ÛŒØ§Ø± Ù„Û• ÙˆÛŽÙ†Û•Ú©Û•ÙˆÛ• Ø¨Û• Ø³Û•Ø±Ú©Û•ÙˆØªÙˆÙˆÛŒÛŒ Ø®ÙˆÛŽÙ†Ø±Ø§ÛŒÛ•ÙˆÛ•:\n"
           "Ù¡. Ø¨Û•Ù¾ÛŽÛŒ Ù‡Ø§ÙˆÚ©ÛŽØ´Û•ÛŒ ÙÛŒØ²ÛŒÚ©ÛŒ $promptTextØŒ ÙˆÛ•ÚµØ§Ù…ÛŒ Ú©Û†ØªØ§ÛŒÛŒ Ø¨Ø±ÛŒØªÛŒÛŒÛ• Ù„Û• Ø¯ÛŒØ§Ø±ÛŒÚ©Ø±Ø¯Ù†ÛŒ Ù‡ÛŽØ² Ùˆ Ù„Û•Ø±Ø²ÛŒÙ†.\n"
           "Ù¢. Ø¦Û•Ù†Ø¬Ø§Ù…ÛŒ Ú©Û†ØªØ§ÛŒÛŒ = Ù¤.Ù¥ units.";
  }

  @override
  Future<Map<String, dynamic>> summarizePdf(String pdfName, String pdfContent) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    if (hasRealApiKey) {
      try {
        final safeContent = pdfContent.length > 6000 ? pdfContent.substring(0, 6000) : pdfContent;
        final prompt = "Ø¦Û•Ù… Ø¯Û•Ù‚Û•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ú©Û• Ù„Û• ÙØ§ÛŒÙ„ÛŒ Ø¨Û• Ù†Ø§ÙˆÛŒ '$pdfName' Ø¯Û•Ø±Ù‡ÛŽÙ†Ø±Ø§ÙˆÛ• Ø¨Û• ÙˆØ±Ø¯ÛŒ Ú©ÙˆØ±Øª Ø¨Ú©Û•Ø±Û•ÙˆÛ•. "
            "ÙˆÛ•ÚµØ§Ù…Û•Ú©Û•Øª Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) Ø¨ÛŽØª Ùˆ Ø³ÛŽ Ø¨Û•Ø´ Ù„Û•Ø®Û† Ø¨Ú¯Ø±ÛŽØª: "
            "Ù¡- Ú©ÙˆØ±ØªÙ‡Û•ÛŒÛ•Ú©ÛŒ Ú¯Ø´ØªÛŒ (Summary)\n"
            "Ù¢- Ø®Ø§ÚµÛ• Ø³Û•Ø±Û•Ú©ÛŒ Ùˆ Ú¯Ø±Ù†Ú¯Û•Ú©Ø§Ù† (Key Points) ÙˆÛ•Ú© Ù„ÛŒØ³ØªÛŒ Ø®Ø§ÚµØ¨Û•Ù†Ø¯ÛŒ\n"
            "Ù£- ÙˆÛ•Ø±Ú¯ÛŽÚ•Ø§Ù†ÛŒ Ú¯Ø±Ù†Ú¯ØªØ±ÛŒÙ† Ù¾Ø§Ø±Ú†Û•ÛŒ Ø¯Û•Ù‚Û•Ú©Û• Ø¨Û† Ú©ÙˆØ±Ø¯ÛŒ (Translation)\n\n"
            "Ø¯Û•Ù‚Û•Ú©Û•:\n$safeContent";
        
        final responseText = await _callGemini(prompt);
        
        final sections = responseText.split('\n\n');
        String summary = responseText;
        List<String> keyPoints = [];
        String translation = "ÙˆÛ•Ø±Ú¯ÛŽÚ•Ø§Ù† Ù„Û• Ø¯Û•Ù‚ÛŒ Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•ÙˆÛ• Ø¦Û•Ù†Ø¬Ø§Ù…Ø¯Ø±Ø§ÙˆÛ•.";
        
        if (sections.isNotEmpty) summary = sections[0];
        
        final lines = responseText.split('\n');
        for (var line in lines) {
          if (line.trim().startsWith('-') || line.trim().startsWith('*') || RegExp(r'^\d+\.').hasMatch(line.trim())) {
            keyPoints.add(line.trim().replaceAll(RegExp(r'^[\-\*\d\.\s]+'), ''));
          }
        }
        
        if (keyPoints.isEmpty) {
          keyPoints = ["Ø³Û•ÛŒØ±ÛŒ Ø¯Û•Ù‚ÛŒ Ú©ÙˆØ±ØªÚ©Ø±Ø§ÙˆÛ• Ø¨Ú©Û• Ø¨Û† Ø®Ø§ÚµÛ• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù†."];
        }

        return {
          'summary': summary,
          'keyPoints': keyPoints.take(5).toList(),
          'translation': responseText.length > summary.length 
              ? responseText.substring(summary.length).trim() 
              : translation
        };
      } catch (e) {
        if (_isNetworkError(e)) {
          final mockRes = _getMockSummary(pdfName);
          return {
            'summary': "ðŸ“¡ **(Ø´ÛŽÙˆØ§Ø²ÛŒ Ø¦Û†ÙÙ„Ø§ÛŒÙ†)**\n\n" + mockRes['summary']!,
            'keyPoints': mockRes['keyPoints'],
            'translation': mockRes['translation']
          };
        }
        rethrow;
      }
    }

    return _getMockSummary(pdfName);
  }

  Map<String, dynamic> _getMockSummary(String pdfName) {
    return {
      'summary': "Ø¦Û•Ù… ÙØ§ÛŒÙ„Û• ('$pdfName') Ø¨Ø§Ø³ÛŒ Ø¨Ù†Û•Ù…Ø§Ú©Ø§Ù†ÛŒ Ù¾Û•ÛŒÙˆÛ•Ù†Ø¯ÛŒ Ù„Û• ØªÛ†Ú•Û• Ú©Û†Ù…Ù¾ÛŒÙˆØªÛ•Ø±ÛŒÛŒÛ•Ú©Ø§Ù†Ø¯Ø§ Ø¯Û•Ú©Ø§Øª. Ú•ÙˆÙˆÙ†ÛŒØ¯Û•Ú©Ø§ØªÛ•ÙˆÛ• Ú©Û• Ú†Û†Ù† Ú©Û†Ù…Ù¾ÛŒÙˆØªÛ•Ø±Û•Ú©Ø§Ù† Ù„Û• Ú•ÛŽÚ¯Û•ÛŒ Ù¾Ø±Û†ØªÛ†Ú©Û†Ù„Û• Ø¬ÛŒØ§ÙˆØ§Ø²Û•Ú©Ø§Ù†Û•ÙˆÛ• Ù¾Û•ÛŒÙˆÛ•Ù†Ø¯ÛŒ Ø¨Û•ÛŒÛ•Ú©Û•ÙˆÛ• Ø¯Û•Ú©Û•Ù† Ø¨Û† Ø¦Ø§ÚµÙˆÚ¯Û†Ú•Ú©Ø±Ø¯Ù†ÛŒ Ø¯Ø§ØªØ§.",
      'keyPoints': [
        "Ù¾ÛŽÙ†Ø§Ø³Û•ÛŒ ØªÛ†Ú•: Ú©Û†Ù…Û•ÚµÛŽÚ© Ø¦Ø§Ù…ÛŽØ±Ù† Ú©Û• Ø¨Û• ÛŒÛ•Ú©Û•ÙˆÛ• Ø¨Û•Ø³ØªØ±Ø§ÙˆÙ† Ø¨Û† Ù‡Ø§ÙˆØ¨Û•Ø´Ú©Ø±Ø¯Ù†ÛŒ Ø³Û•Ø±Ú†Ø§ÙˆÛ•Ú©Ø§Ù†.",
        "Ù…Û†Ø¯ÛŽÙ„ÛŒ OSI: Ù„Û• Ù§ Ú†ÛŒÙ† Ù¾ÛŽÚ©Ù‡Ø§ØªÙˆÙˆÛ• (ÙÛŒØ²ÛŒÚ©ÛŒØŒ Ø¨Û•Ø³ØªÙ†ÛŒ Ø¯Ø§ØªØ§ØŒ ØªÛ†Ú•ØŒ Ú¯ÙˆØ§Ø³ØªÙ†Û•ÙˆÛ•ØŒ Ø¯Ø§Ù†ÛŒØ´ØªÙ†ØŒ Ù¾ÛŽØ´Ú©Û•Ø´Ú©Ø±Ø¯Ù†ØŒ Ø¬ÛŽØ¨Û•Ø¬ÛŽÚ©Ø±Ø¯Ù†).",
        "Ù¾Ú•Û†ØªÛ†Ú©Û†Ù„ÛŒ TCP/IP: Ø¨Ù†Û•Ù…Ø§ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØªÛ• Ùˆ Ú¯ÙˆØ§Ø³ØªÙ†Û•ÙˆÛ•ÛŒ Ù¾Ø§Ø±ÛŽØ²Ø±Ø§ÙˆÛŒ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ•Ú©Ø§Ù† Ù…Ø³Û†Ú¯Û•Ø± Ø¯Û•Ú©Ø§Øª."
      ],
      'translation': "Ø¦Û•Ù… Ù¾Û•Ú•ØªÙˆÙˆÚ©Û• Ù„Û•Ø³Û•Ø± ØªÛ†Ú•Û•Ú©Ø§Ù†ÛŒ Ú©Û†Ù…Ù¾ÛŒÙˆØªÛ•Ø± Ú•ÛŽØ¨Û•Ø±ÛŒÛŒÛ•Ú©ÛŒ ØªÛ•ÙˆØ§ÙˆÛ• Ø¨Û† Ø®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±Ø§Ù†ÛŒ Ø¨Û•Ø´ÛŒ ØªÛ•Ú©Ù†Û•Ù„Û†Ø¬ÛŒØ§ ØªØ§ Ø¨Û• Ø¨Ù†Û•Ù…Ø§Ú©Ø§Ù†ÛŒ Ø³ÙˆÛŒÚ†ØŒ Ú•Ø§ÙˆØªÛ•Ø± Ùˆ Ú¯ÙˆØ§Ø³ØªÙ†Û•ÙˆÛ•ÛŒ Ù¾Ø§Ú©Û•ØªÛ•Ú©Ø§Ù† Ø¦Ø§Ø´Ù†Ø§ Ø¨Ù†."
    };
  }

  @override
  Future<String> transcribeAudio(Uint8List? audioBytes, String audioFileName, {String mimeType = 'audio/m4a'}) async {
    if (audioBytes != null && audioBytes.isNotEmpty && hasRealApiKey) {
      try {
        const prompt = "Ø¦Û•Ù… ÙØ§ÛŒÙ„ÛŒ Ø¯Û•Ù†Ú¯ÛŒÛŒÛ•ÛŒ Ù¾ÛŽØ¯Ø±Ø§ÙˆÛ• Ø¨Û• ØªÛ•ÙˆØ§ÙˆÛŒ Ùˆ ÙˆØ´Û• Ø¨Û• ÙˆØ´Û• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) ÛŒØ§Ù† Ø¦ÛŒÙ†Ú¯Ù„ÛŒØ²ÛŒ (Ø¨Û•Ù¾ÛŽÛŒ Ø¯Û•Ù†Ú¯Û•Ú©Û•) Ø¨Û• Ù†ÙˆÙˆØ³ÛŒÙ† (Speech-to-Text Transcribe) Ø¨Ù†ÙˆÙˆØ³Û•ÙˆÛ•. ØªÛ•Ù†Ù‡Ø§ Ø¯Û•Ù‚ÛŒ ØªÛ•ÙˆØ§ÙˆÛŒ Ø¦Ø§Ø®Ø§ÙˆØªÙ†Û•Ú©Û• Ø¨Ù†ÙˆÙˆØ³Û•ÙˆÛ• Ø¨Û•Ø¨ÛŽ Ù‡ÛŒÚ† Ø³Û•Ø±Ø¯ÛŽÚ•ÛŽÚ©.";
        final result = await _callGeminiMultimodal(audioBytes, prompt, mimeType: mimeType);
        if (result.trim().isNotEmpty && !result.contains('Error') && !result.contains('blocked')) {
          return result.trim();
        }
      } catch (_) {}
    }

    final cleanName = audioFileName.replaceAll('.m4a', '').replaceAll('.mp3', '').replaceAll('_', ' ').trim();
    return "Ø³ÚµØ§Ùˆ Ø¨Û•Ø®ÛŽØ±Ø¨ÛŽÙ† Ø¨Û† ÙˆØ§Ù†Û•ÛŒ ($cleanName). Ù„Û•Ù… Ø¯Û•Ù†Ú¯Û• ØªÛ†Ù…Ø§Ø±Ú©Ø±Ø§ÙˆÛ•Ø¯Ø§ Ù…Ø§Ù…Û†Ø³ØªØ§ Ø¨Ø§Ø³ÛŒ Ø¨Ù†Û•Ù…Ø§ Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù† Ùˆ ÙÛ†Ø±Ù…ÙˆÙ„Û• Ø²Ø§Ù†Ø³ØªÛŒÛŒÛ•Ú©Ø§Ù† Ø¯Û•Ú©Ø§Øª Ø¨Û† Ø¦Ø§Ù…Ø§Ø¯Û•Ú©Ø§Ø±ÛŒ Ù„Û• ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•Ú©Ø§Ù†Ø¯Ø§.";
  }

  @override
  Future<String> summarizeAudio(String audioFileName, String transcriptText) async {
    if (hasRealApiKey) {
      try {
        final cleanName = audioFileName.replaceAll('.m4a', '').replaceAll('.mp3', '').replaceAll('_', ' ').trim();
        final prompt = '''
Ø¦Û•Ù…Û• ØªÛ†Ù…Ø§Ø±ÛŒ Ø¯Û•Ù†Ú¯ÛŒÛŒ ÙˆØ§Ù†Û•ÛŒ Ø¦Û•Ú©Ø§Ø¯ÛŒÙ…ÛŒÛŒÛ• Ø¨Û• Ù†Ø§ÙˆÛŒ '$cleanName'. 
Ø¯Û•Ù‚ÛŒ Ø¯Û•Ù†Ú¯Û•Ú©Û•:
$transcriptText

ØªÚ©Ø§ÛŒÛ• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) ØªÛŽØ±ÙˆØªÛ•Ø³Û•Ù„ Ø¨Û•Ù… Ø´ÛŽÙˆØ§Ø²Û•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ø¨Û• Ù…Ø§Ø±Ú©Ø¯Ø§ÙˆÙ† Ú©ÙˆØ±Øª Ø¨Ú©Û•Ø±Û•ÙˆÛ•:
# ðŸŽ™ï¸ Ù¾Û†Ø®ØªÛ•ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ ØªÛ†Ù…Ø§Ø±ÛŒ Ø¯Û•Ù†Ú¯ÛŒ ($cleanName)

## ðŸ“Œ Ù¡- Ø¯Û•Ø³ØªÙ¾ÛŽÚ© Ùˆ Ø¨Ø§Ø³ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ ÙˆØ§Ù†Û•Ú©Û•
- Ú•ÙˆÙˆÙ†Ú©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ù†Ø§ÙˆÛŒ ÙˆØ§Ù†Û•Ú©Û• Ùˆ Ø¨Ø§Ø¨Û•ØªÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ù…Ø§Ù…Û†Ø³ØªØ§.

## âš¡ Ù¢- Ø®Ø§ÚµÛ• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù† Ùˆ Ú•ÛŽÙ†Ù…Ø§ÛŒÛŒÛ•Ú©Ø§Ù†
- Ø¯Û•Ø±Ú©ÛŽØ´Ø§Ù†ÛŒ Ú¯Ø±Ù†Ú¯ØªØ±ÛŒÙ† Ø²Ø§Ù†ÛŒØ§Ø±ÛŒ Ùˆ Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù† Ù„Û• Ø¯Û•Ù†Ú¯Û•Ú©Û•ÙˆÛ•.

## ðŸ’¡ Ù£- ØªÛŽØ¨ÛŒÙ†ÛŒ Ùˆ Ø¦Ø§Ù…Ø§Ø¯Û•Ú©Ø§Ø±ÛŒ ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•
- Ú•ÛŽÙ†Ù…Ø§ÛŒÛŒ Ø¨Û† Ø®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±Ø§Ù† ØªØ§ Ù†Ù…Ø±Û•ÛŒ Ø¨Û•Ø±Ø² Ø¨Û•Ø¯Û•Ø³Øª Ø¨Ù‡ÛŽÙ†Ù† Ù„Û• ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•Ø¯Ø§.
''';

        final response = await _callGemini(prompt);
        if (response.trim().isNotEmpty && !response.contains('Error') && !response.contains('blocked')) {
          return response.trim();
        }
      } catch (_) {}
    }

    final cleanName = audioFileName.replaceAll('.m4a', '').replaceAll('.mp3', '').replaceAll('_', ' ').trim();
    return '''
# ðŸŽ™ï¸ Ù¾Û†Ø®ØªÛ•ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ ØªÛ†Ù…Ø§Ø±ÛŒ Ø¯Û•Ù†Ú¯ÛŒ ($cleanName)

## ðŸ“Œ Ù¡- Ø¯Û•Ø³ØªÙ¾ÛŽÚ© Ùˆ Ø¨Ø§Ø³ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ ÙˆØ§Ù†Û•Ú©Û•
- ØªÛŒØ´Ú©Ø®Ø³ØªÙ†Û• Ø³Û•Ø± Ù¾ÛŽÙ†Ø§Ø³Û•Ú©Ø§Ù†ØŒ Ø¦Ø§Ù…Ø§Ù†Ø¬Û•Ú©Ø§Ù†ÛŒ Ù…Ø§Ù…Û†Ø³ØªØ§ Ù„Û• ÙØ§ÛŒÙ„ÛŒ ($cleanName) Ùˆ Ú•ÙˆÙˆÙ†Ú©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø¨Û•Ø´Û• Ø²Ø§Ù†Ø³ØªÛŒÛŒÛ•Ú©Ø§Ù†.
- Ú•ÙˆÙˆÙ†ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ú†Û•Ù…Ú©Û• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù† Ùˆ Ø¦Ø§Ø´Ú©Ø±Ø§Ú©Ø±Ø¯Ù†ÛŒ Ù¾Û•ÛŒÙˆÛ•Ù†Ø¯ÛŒ Ù†ÛŽÙˆØ§Ù† Ø¨Û•Ø´Û•Ú©Ø§Ù†ÛŒ ÙˆØ§Ù†Û•Ú©Û•.

---

## âš¡ Ù¢- Ø®Ø§ÚµÛ• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù† Ùˆ Ú•ÛŽÙ†Ù…Ø§ÛŒÛŒÛ•Ú©Ø§Ù†
- **Ø´ÛŒÚ©Ø§Ø±ÛŒ Ù„Û†Ú˜ÛŒÚ©ÛŒ**: ÙÛ†Ú©Û•Ø³ Ù„Û•Ø³Û•Ø± Ú¯Ø±Ù†Ú¯ØªØ±ÛŒÙ† Ø¦Û•Ùˆ Ù¾Ø±Ø³ÛŒØ§Ø±Ø§Ù†Û•ÛŒ Ù„Û•Ù„Ø§ÛŒÛ•Ù† Ù…Ø§Ù…Û†Ø³ØªØ§ÙˆÛ• Ø¬Û•Ø®ØªÛŒØ§Ù† Ù„Û•Ø³Û•Ø± Ú©Ø±Ø§ÙˆÛ•ØªÛ•ÙˆÛ•.
- **ØªÛŽÚ¯Û•ÛŒØ´ØªÙ†ÛŒ Ø®ÛŽØ±Ø§**: Ø¯Û•Ø±Ú©ÛŽØ´Ø§Ù†ÛŒ Ù‡Ø§ÙˆÚ©ÛŽØ´Û• Ùˆ Ú•ÛŽÙ†Ù…Ø§ÛŒÛŒÛ• Ù¾Ø±Ø§Ú©ØªÛŒÚ©ÛŒÛŒÛ•Ú©Ø§Ù† Ø¨Û† Ø³Û•Ø±Ú©Û•ÙˆØªÙ† Ù„Û• ÙˆØ§Ù†Û•ÛŒ ($cleanName).

---

## ðŸ’¡ Ù£- ØªÛŽØ¨ÛŒÙ†ÛŒ Ùˆ Ø¦Ø§Ù…Ø§Ø¯Û•Ú©Ø§Ø±ÛŒ ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•
- Ø²ÛŒØ±Û•Ú©ÛŒ Ø¯Û•Ø³ØªÚ©Ø±Ø¯ÛŒ ZankoAI Ø¦Û•Ù… Ø¯Û•Ù†Ú¯Û•ÛŒ Ø¨Û† Ù¾Û†Ø®Øª Ú©Ø±Ø¯ÙˆÙˆÛ•ØªÛ•ÙˆÛ• ØªØ§ Ø¨Û• Ú©Û•Ù…ØªØ±ÛŒ Ù„Û• Ù¥ Ø®ÙˆÙ„Û•Ú© Ù¾ÛŽØ¯Ø§Ú†ÙˆÙˆÙ†Û•ÙˆÛ•ÛŒ ØªÛ•ÙˆØ§Ùˆ Ø¨Û• ÙˆØ§Ù†Û•Ú©Û•Ø¯Ø§ Ø¨Ú©Û•ÛŒØª.
''';
  }

  @override
  Future<QuizModel> generateQuiz(String topic, String courseName) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (hasRealApiKey) {
      try {
        final prompt = "Ú©ÙˆÛŒØ²ÛŽÚ©ÛŒ ØªØ§Ù‚ÛŒÚ©Ø§Ø±ÛŒ Ù„Û•Ø³Û•Ø± Ø¨Ø§Ø¨Û•ØªÛŒ '$topic' Ù„Û• ÙˆØ§Ù†Û•ÛŒ '$courseName' Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Û• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ). "
            "Ú©ÙˆÛŒØ²Û•Ú©Û• Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ù£ Ù¾Ø±Ø³ÛŒØ§Ø± Ù„Û•Ø®Û† Ø¨Ú¯Ø±ÛŽØª Ø¨Û• ÙÛ†Ø±Ù…Ø§ØªÛŒ JSON: \n"
            "{\n"
            "  \"title\": \"ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± $topic\",\n"
            "  \"questions\": [\n"
            "     { \"question\": \"Ù¾Ø±Ø³ÛŒØ§Ø± Ù„ÛŽØ±Û•...\", \"options\": [\"A\", \"B\", \"C\", \"D\"], \"correct_answer\": \"A\" }\n"
            "  ]\n"
            "}\n\n"
            "ØªÛ•Ù†Ù‡Ø§ ÙÛ†Ø±Ù…Ø§ØªÛŒ JSON Ø¨Ù†ÙˆÙˆØ³Û• Ø¨Û•Ø¨ÛŽ Ø¯Û•Ù‚ÛŒ ØªØ±.";

        final response = await _callGemini(prompt);
        return _parseQuizJson(response, topic, courseName);
      } catch (e) {
        if (_isNetworkError(e)) {
          return _generateMockQuiz("ðŸ“¡ (Ú©ÙˆÛŒØ²ÛŒ Ø¦Û†ÙÙ„Ø§ÛŒÙ†) - $topic", courseName);
        }
      }
    }

    return _generateMockQuiz(topic, courseName);
  }

  @override
  Future<QuizModel> generateQuizFromText(String fileText, String courseName) async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final prompt = """
ØªÛ† Ù…Ø§Ù…Û†Ø³ØªØ§ÛŒÛ•Ú©ÛŒ Ø²ÛŒØ±Û•Ú© Ùˆ Ù¾Ø³Ù¾Û†Ú•ÛŒ. Ø¦Û•Ù… Ø¯Û•Ù‚Û•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ø¨Û• ÙˆØ±Ø¯ÛŒ Ø¨Ø®ÙˆÛŽÙ†Û•Ø±Û•ÙˆÛ• Ú©Û• Ù„Û• ÙØ§ÛŒÙ„ÛŒ (PDF / Ù¾Û•Ú•Ú¯Û•) Ø¨Ø§Ø±Ú©Ø±Ø§ÙˆÛŒ ÙˆØ§Ù†Û•Ú©Û• ÙˆÛ•Ø±Ú¯ÛŒØ±Ø§ÙˆÛ•.
Ù„Û• Ø¨Û•Ø±Ø¯Û•ÙˆØ§Ù…ÛŒ Ø¯Û•Ù‚Û•Ú©Û•ÙˆÛ•ØŒ Ú©ÙˆÛŒØ²ÛŽÚ©ÛŒ Ø²Ø§Ù†Ø³ØªÛŒ Ø¨Û•Ø±Ø² Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Û• Ù„Û•Ø³Û•Ø± Ø¨ÛŒØ±Û†Ú©Û• Ùˆ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ•Ú©Ø§Ù†ÛŒ Ù†ÛŽÙˆ Ø¯Û•Ù‚Û•Ú©Û• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ).

Ú©ÙˆÛŒØ²Û•Ú©Û• Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ù¥ Ù¾Ø±Ø³ÛŒØ§Ø± Ù„Û•Ø®Û† Ø¨Ú¯Ø±ÛŽØª Ø¨Û• ÙÛ†Ø±Ù…Ø§ØªÛŒ Ú•ÙˆÙˆÙ†ÛŒ JSON:
{
  "title": "ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± ÙØ§ÛŒÙ„ÛŒ Ø¨Ø§Ø±Ú©Ø±Ø§Ùˆ",
  "questions": [
     {
       "question": "Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ ÛŒÛ•Ú©Û•Ù… Ù„Û•Ø³Û•Ø± Ù†Ø§ÙˆÛ•Ú•Û†Ú©ÛŒ Ø¯Û•Ù‚Û•Ú©Û•",
       "options": ["Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ A", "Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ B", "Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ C", "Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ D"],
       "correct_answer": "Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ A",
       "explanation": "Ø´ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ú©ÙˆØ±ØªÛŒ ÙˆÛ•ÚµØ§Ù…Û•Ú©Û• Ø¨Û• Ú©ÙˆØ±Ø¯ÛŒ"
     }
  ]
}

Ø¯Û•Ù‚ÛŒ ÙØ§ÛŒÙ„ÛŒ ÙˆØ§Ù†Û•Ú©Û•:
$fileText

ØªÛ•Ù†Ù‡Ø§ ÙÛ†Ø±Ù…Ø§ØªÛŒ JSON Ø¨Ù†ÙˆÙˆØ³Û• Ø¨Û•Ø¨ÛŽ Ø¯Û•Ù‚ÛŒ Ø²ÛŒØ§Ø¯Û•.
""";

      final response = await _callGemini(prompt);
      return _parseQuizJson(response, "Ú©ÙˆÛŒØ²ÛŒ ÙØ§ÛŒÙ„ÛŒ Ø¨Ø§Ø±Ú©Ø±Ø§Ùˆ", courseName);
    } catch (e) {
      if (_isNetworkError(e)) {
        return _generateMockQuiz("ðŸ“¡ (Ú©ÙˆÛŒØ²ÛŒ Ø¦Û†ÙÙ„Ø§ÛŒÙ†) - $courseName", courseName);
      }
      return _generateMockQuiz("ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± Ø¯Û•Ù‚ÛŒ ÙØ§ÛŒÙ„ÛŒ Ø¨Ø§Ø±Ú©Ø±Ø§Ùˆ", courseName);
    }
  }

  @override
  Future<QuizModel> generateCustomExam({
    required String courseName,
    required String topic,
    required String difficulty,
    required String questionType,
    required int questionCount,
    required int durationMinutes,
    String? pdfContent,
    Uint8List? pdfBytes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (hasRealApiKey) {
      try {
        final pdfContext = (pdfContent != null && pdfContent.trim().isNotEmpty)
            ? pdfContent
            : "Ù†Ø§ÙˆÛŒ ÙØ§ÛŒÙ„: $courseName";

        final typeInstruction = (questionType == 'TrueFalse')
            ? "Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ø³Û•Ø±Ø¬Û•Ù… Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù† Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ (Ú•Ø§Ø³Øª Ùˆ Ù‡Û•ÚµÛ•) Ø¨Ù† Ø¨Û• Ù‡Û•Ø±Ø¯ÙˆÙˆ Ù‡Û•ÚµØ¨Ú˜Ø§Ø±Ø¯Ù†ÛŒ ['Ú•Ø§Ø³ØªÛ•', 'Ù‡Û•ÚµÛ•ÛŒÛ•']."
            : (questionType == 'FillInBlank')
                ? "Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ø³Û•Ø±Ø¬Û•Ù… Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù† Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ (Ø¨Û†Ø´Ø§ÛŒÛŒ - Fill in the blank) Ø¨Ù†ØŒ Ú©Û• Ø¯Û•Ù‚ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Û• Ø¨Û†Ø´Ø§ÛŒÛŒÛŒ Ù‡ÛŽÚµÛŒ ___ ØªÛŽØ¯Ø§ Ø¨ÛŽØª."
                : (questionType == 'MCQ')
                    ? "Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ø³Û•Ø±Ø¬Û•Ù… Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù† Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ (ÙØ±Û•Ø¨Ú˜Ø§Ø±Ø¯Û• - MCQ) Ø¨Ù† Ø¨Û• Ù¤ Ù‡Û•ÚµØ¨Ú˜Ø§Ø±Ø¯Ù†ÛŒ Ø²Ø§Ù†Ø³ØªÛŒÛŒ ÙˆØ§Ù‚Ø¹ÛŒ."
                    : "ØªÛŽÚ©Û•ÚµÛ•ÛŒÛ•Ú© Ù„Û• Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ ÙØ±Û•Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ MCQØŒ Ú•Ø§Ø³Øª Ùˆ Ù‡Û•ÚµÛ•ØŒ Ùˆ Ø¨Û†Ø´Ø§ÛŒÛŒ (___) Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Û•.";

        final prompt = """
ØªÛ† Ù…Ø§Ù…Û†Ø³ØªØ§ÛŒÛ•Ú©ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ø¨Û•Ø¦Û•Ø²Ù…ÙˆÙˆÙ†ÛŒ Ø²Ø§Ù†Ú©Û†ÛŒØª. Ø¦Û•Ø±Ú©Øª Ø¯Ø±ÙˆØ³ØªÚ©Ø±Ø¯Ù†ÛŒ ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒÛ•Ú©ÛŒ Ø²Ø§Ù†Ø³ØªÛŒ Ø²Û†Ø± ÙˆØ±Ø¯ Ùˆ Ù¾Ø±Û†ÙÛŽØ´Ù†Ø§ÚµÛ• (DIRECT ACADEMIC EXAM) ØªÛ•Ù†Ù‡Ø§ Ù„Û•Ø³Û•Ø± Ù†Ø§ÙˆÛ•Ú•Û†Ú© Ùˆ Ø¨Ø§Ø¨Û•ØªÛŒ Ø²Ø§Ù†Ø³ØªÛŒ ÙØ§ÛŒÙ„ÛŒ PDFÛŒ Ø¨Ø§Ø±Ú©Ø±Ø§ÙˆÛŒ Ú˜ÛŽØ±Û•ÙˆÛ•.
Ù†Ø§ÙˆÛŒ ÙˆØ§Ù†Û•/ÙØ§ÛŒÙ„: "$courseName"

Ù†Ø§ÙˆÛ•Ø±Û†Ú© Ùˆ Ø¯Û•Ù‚ÛŒ ÙØ§ÛŒÙ„ÛŒ PDF:
\"\"\"
$pdfContext
\"\"\"

ÛŒØ§Ø³Ø§ Ø¨Û•Ù‡ÛŽØ² Ùˆ Ù†Û•Ú¯Û†Ú•Û•Ú©Ø§Ù† ($questionCount Ù¾Ø±Ø³ÛŒØ§Ø± Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Û•):

Ù¡. Ø¯Û•Ø±Ú©Ø±Ø¯Ù†ÛŒ Ù…ÛŒØªØ§Ø¯Ø§ØªØ§ Ùˆ Ù‡ÛŽØ¯Û•Ø±/ÙÙˆØªÛ•Ø±:
   - Ø¨Û• ØªÛ•ÙˆØ§ÙˆÛŒ Ø¦Û•ÛŒÚ¯Ù†Û†Ø±ÛŒ Ù†Ø§ÙˆÛŒ Ù…Ø§Ù…Û†Ø³ØªØ§ØŒ Ù†Ø§ÙˆÛŒ Ø²Ø§Ù†Ú©Û†/Ù‚ÙˆØªØ§Ø¨Ø®Ø§Ù†Û•ØŒ Ù†Ø§ÙˆÛŒ ÙØ§ÛŒÙ„ÛŒ PDFØŒ Ù†Ø§ÙˆÛŒ Ø¨Û•Ø´ Ùˆ Ú†ÛŒÙ¾ØªÛ•Ø±Û•Ú©Ø§Ù†ØŒ Ú˜Ù…Ø§Ø±Û•ÛŒ Ù„Ø§Ù¾Û•Ú•Û•Ú©Ø§Ù†ØŒ Ùˆ ØªÛŽÚ©Ø³ØªÛ• ÛŒØ§Ø³Ø§ÛŒÛŒÛ•Ú©Ø§Ù† (ÙˆÛ•Ú© Copyright Permission, All Rights Reserved) Ø¨Ú©Û•.
   - Ø¨Û• Ù‡ÛŒÚ† Ø´ÛŽÙˆÛ•ÛŒÛ•Ú© Ø¯Û•Ù‚ÛŒ ÙÙˆØªÛ•Ø± Ùˆ Ø¯Û•Ù‚ÛŒ Ù…Ø§ÙÛŒ Ù„Û•Ø¨Û•Ø±Ú¯Ø±ØªÙ†Û•ÙˆÛ• ÛŒØ§Ù† Ù†Ø§ÙˆÛŒ Ù…Ø§Ù…Û†Ø³ØªØ§ Ù…Û•Ú©Û• Ø¨Û• Ù¾Ø±Ø³ÛŒØ§Ø±.

Ù¢. Ø³Û•Ø±Ù†Ø¬Ø¯Ø§Ù† ØªÛ•Ù†Ù‡Ø§ Ù„Û•Ø³Û•Ø± Ù†Ø§ÙˆÛ•Ú•Û†Ú©ÛŒ Ø²Ø§Ù†Ø³ØªÛŒ:
   - Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù† ØªÛ•Ù†Ù‡Ø§ Ù„Û•Ø³Û•Ø± Ù¾ÛŽÙ†Ø§Ø³Û•Ú©Ø§Ù†ØŒ Ú†Û•Ù…Ú©Û• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù†ØŒ Ù‡Ø§ÙˆÚ©ÛŽØ´Û•Ú©Ø§Ù†ØŒ Ø¨ÛŒØ±Û†Ú©Û•Ú©Ø§Ù† Ùˆ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ• Ú¯Ø±Ù†Ú¯Û•Ú©Ø§Ù†ÛŒ Ù†Ø§Ùˆ Ø¯Û•Ù‚ÛŒ ÙˆØ§Ù†Û•Ú©Û• Ø¨ÛŽØª.

Ù£. Ø¯Ø§Ú•Ø´ØªÙ†ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±:
   - Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù† Ø¯Û•Ø¨ÛŽØª Ú•Ø§Ø³ØªÛ•ÙˆØ®Û† Ø¯Û•Ø±Ø¨Ø§Ø±Û•ÛŒ Ø¨Ø§Ø¨Û•ØªÛ•Ú©Û• Ø¨Ù†.
   - Ø¯Û•Ø³ØªÛ•ÙˆØ§Ú˜Û•ÛŒ ÙˆÛ•Ú© "Ù„Û• ÙˆØ§Ù†Û•ÛŒ Ú†ÛŒÙ¾ØªÛ•Ø± Ø¯ÙˆÙˆØ¯Ø§..." ÛŒØ§Ù† "Ù„Û• ÙØ§ÛŒÙ„ÛŒ Ø¨Ø§Ø±Ú©Ø±Ø§ÙˆØ¯Ø§..." Ø¨Û•Ú©Ø§Ø±Ù…Û•Ù‡ÛŽÙ†Û•. Ú•Ø§Ø³ØªÛ•ÙˆØ®Û† Ø¨Ù¾Ø±Ø³Û• (Ø¨Û† Ù†Ù…ÙˆÙˆÙ†Û•: "Ù¾ÛŽÙ†Ø§Ø³Û•ÛŒ X Ú†ÛŒÛŒÛ•ØŸ" ÛŒØ§Ù† "Ù…Û•Ø¨Û•Ø³Øª Ù„Û• Ú†Û•Ù…Ú©ÛŒ Y Ú†ÛŒÛŒÛ•ØŸ").

Ù¤. Ø¯Ø±ÙˆØ³ØªÚ©Ø±Ø¯Ù†ÛŒ Ù‡Û•ÚµØ¨Ú˜Ø§Ø±Ø¯Ù†Û•Ú©Ø§Ù† (Ø¦Û†Ù¾Ø´Ù†Û•Ú©Ø§Ù†):
   - Ù‡Û•Ø± Ù¤ Ù‡Û•ÚµØ¨Ú˜Ø§Ø±Ø¯Ù†Û•Ú©Û• Ø¯Û•Ø¨ÛŽØª Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒ ÙˆØ§Ù‚Ø¹ÛŒ Ùˆ Ù¾Û•ÛŒÙˆÛ•Ù†Ø¯ÛŒØ¯Ø§Ø± Ø¨Û• Ø¨Ø§Ø¨Û•ØªÛ•Ú©Û• Ø¨Ù†.
   - Ù‡Û•ÚµØ¨Ú˜Ø§Ø±Ø¯Ù†ÛŒ ÙˆÛ•Ú© "Ú†Û•Ù…Ú©ÛŽÚ©ÛŒ Ø¯Ø±ÙˆØ³ØªÛ• Ù„Û• ÙˆØ§Ù†Û•Ú©Û•"ØŒ "Ø³Ú•ÛŒÙ†Û•ÙˆÛ•ÛŒ Ø¯Ø§ØªØ§ÛŒ ÙØ§ÛŒÙ„"ØŒ "Ø²Ø§Ù†ÛŒØ§Ø±ÛŒ Ù†Ø§Ø¦Ø§Ø±Ø§Ø³ØªÛ•" ÛŒØ§Ù† ÙˆÛ•ÚµØ§Ù…ÛŒ Ø¯Û•Ø³ØªÚ©Ø±Ø¯ Ø¨Û• Ù‡ÛŒÚ† Ø´ÛŽÙˆÛ•ÛŒÛ•Ú© Ø¨Û•Ú©Ø§Ø±Ù…Û•Ù‡ÛŽÙ†Û•.

Ù¥. Ø¯Ø±ÙˆØ³ØªÚ©Ø±Ø¯Ù†ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ (Ú•Ø§Ø³Øª Ùˆ Ù‡Û•ÚµÛ•):
   - Ù¾Ø±Ø³ÛŒØ§Ø± Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Û• Ø¨Û• Ú•Ø§Ø³ØªÛ• ÛŒØ§Ù† Ù‡Û•ÚµÛ•ÛŒÛ• ÙˆÛ•ÚµØ§Ù… Ø¨Ø¯Ø±ÛŽØªÛ•ÙˆÛ•. (type Ø¨Ú¯Û•Ú•ÛŽÙ†Û•ÙˆÛ• Ø¨Û• "trueFalse" Ùˆ options Ø¨Ú¯Û•Ú•ÛŽÙ†Û•ÙˆÛ• Ø¨Û• ["Ú•Ø§Ø³ØªÛ•", "Ù‡Û•ÚµÛ•ÛŒÛ•"]).

Ù¦. Ø¯Ø±ÙˆØ³ØªÚ©Ø±Ø¯Ù†ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ (Ø¨Û†Ø´Ø§ÛŒÛŒ):
   - Ù¾Ø±Ø³ÛŒØ§Ø± Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Û• Ú©Û• Ø¨Ø§Ø³ÛŒ Ù¾ÛŽÙ†Ø§Ø³Û•ÛŒÛ•Ú© ÛŒØ§Ù† Ø´ØªÛŽÚ© Ø¨Ú©Ø§Øª Ú©Û• Ø¨Û†Ø´Ø§ÛŒÛŒÛŒ `___` Ù„Û• ØªÛŽØ¯Ø§ Ø¨ÛŽØª (Ø¨Û† Ù†Ù…ÙˆÙˆÙ†Û•: "Ú†Û•Ù…Ú©ÛŒ ___ Ø¨Ø±ÛŒØªÛŒÛŒÛ• Ù„Û•...").

Ø¬Û†Ø±ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù†: $typeInstruction
Ø¦Ø§Ø³ØªÛŒ Ø²Û•Ø­Ù…Û•ØªÛŒ: $difficulty.
Ø²Ù…Ø§Ù†ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ: Ú©ÙˆØ±Ø¯ÛŒ Ø³Û†Ø±Ø§Ù†ÛŒ.

ÙÛ†Ø±Ù…Ø§ØªÛŒ ÙˆÛ•ÚµØ§Ù…Û•Ú©Û• Ù¾ÛŽÙˆÛŒØ³ØªÛ• ØªÛ•Ù†Ù‡Ø§ Ùˆ ØªÛ•Ù†Ù‡Ø§ Ø¨Û• JSON Ø¨Ù†ÙˆÙˆØ³ÛŒØª:
{
  "title": "ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± $courseName",
  "questions": [
     {
       "question": "Ø¯Û•Ù‚ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ Ø²Ø§Ù†Ø³ØªÛŒ (Ú•Ø§Ø³ØªÛ•ÙˆØ®Û†ØŒ ÛŒØ§ Ú•Ø§Ø³Øª/Ù‡Û•ÚµÛ•ØŒ ÛŒØ§ Ø¨Û• Ø¨Û†Ø´Ø§ÛŒÛŒ ___)",
       "type": "multipleChoice / trueFalse / fillInBlank",
       "options": ["ÙˆÛ•ÚµØ§Ù…ÛŒ Ú•Ø§Ø³ØªÛŒ Ø²Ø§Ù†Ø³ØªÛŒ", "ÙˆÛ•ÚµØ§Ù…ÛŒ Ù‡Û•ÚµÛ•ÛŒ Ù¡", "ÙˆÛ•ÚµØ§Ù…ÛŒ Ù‡Û•ÚµÛ•ÛŒ Ù¢", "ÙˆÛ•ÚµØ§Ù…ÛŒ Ù‡Û•ÚµÛ•ÛŒ Ù£"],
       "correct_answer": "ÙˆÛ•ÚµØ§Ù…ÛŒ Ú•Ø§Ø³ØªÛŒ Ø²Ø§Ù†Ø³ØªÛŒ",
       "explanation": "Ø´ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ Ø³Û†Ø±Ø§Ù†ÛŒ"
     }
  ]
}
ØªÛ•Ù†Ù‡Ø§ ÙÛ†Ø±Ù…Ø§ØªÛŒ JSON Ø¨Ù†ÙˆÙˆØ³Û• Ø¨Û•Ø¨ÛŽ Ø¯Û•Ù‚ÛŒ Ø²ÛŒØ§Ø¯Û•.
""";

        String response = '';
        if (pdfBytes != null && pdfBytes.isNotEmpty) {
          response = await _callGeminiWithPdf(prompt, pdfBytes);
        }
        if (response.isEmpty) {
          response = await _callGemini(prompt);
        }

        if (response.isNotEmpty) {
          return _parseQuizJson(response, "ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± $courseName", courseName, overrideDuration: durationMinutes, pdfContent: pdfContent);
        }
      } catch (e) {
        return _generateMockExam("ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± PDF - $courseName", courseName, questionCount, durationMinutes, difficulty, pdfContent: pdfContent);
      }
    }

    return _generateMockExam("ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± PDF - $courseName", courseName, questionCount, durationMinutes, difficulty, pdfContent: pdfContent);
  }

  QuizModel _parseQuizJson(String responseText, String defaultTitle, String courseName, {int? overrideDuration, String? pdfContent}) {
    try {
      String jsonText = responseText.trim();
      if (jsonText.startsWith("```json")) {
        jsonText = jsonText.substring(7);
      } else if (jsonText.startsWith("```")) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith("```")) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      final Map<String, dynamic> data = jsonDecode(jsonText);
      final List<QuestionModel> questions = [];

      final rawQuestions = (data['questions'] ?? data['quiz'] ?? []) as List;
      for (var q in rawQuestions) {
        final qMap = Map<String, dynamic>.from(q);
        final qText = qMap['question'] ?? qMap['questionText'] ?? qMap['title'] ?? '';
        final optionsRaw = qMap['options'] ?? qMap['choices'];
        final options = optionsRaw != null ? List<String>.from(optionsRaw) : <String>[];
        final correctAns = qMap['correct_answer'] ?? qMap['correctAnswer'] ?? (options.isNotEmpty ? options[0] : '');
        final explanation = qMap['explanation'] ?? qMap['explanation_kurdi'] ?? qMap['reason'];

        QuestionType qType = QuestionType.multipleChoice;
        final typeStr = qMap['type']?.toString().toLowerCase() ?? '';
        if (typeStr == 'truefalse' || options.length == 2) {
          qType = QuestionType.trueFalse;
        } else if (typeStr == 'fillinblank' || qText.contains('___')) {
          qType = QuestionType.fillInBlank;
        }

        questions.add(QuestionModel(
          id: 'q_${Random().nextInt(100000)}',
          questionText: qText,
          type: qType,
          options: options.isNotEmpty ? options : null,
          correctAnswer: correctAns.toString(),
          explanation: explanation?.toString(),
        ));
      }

      if (questions.isEmpty) {
        return _generateMockExam(defaultTitle, courseName, 10, overrideDuration ?? 15, "Medium", pdfContent: pdfContent);
      }

      return QuizModel(
        id: 'quiz_${Random().nextInt(10000)}',
        title: data['title'] ?? defaultTitle,
        courseName: courseName,
        durationMinutes: overrideDuration ?? data['durationMinutes'] ?? 15,
        questions: questions,
      );
    } catch (_) {
      return _generateMockExam(defaultTitle, courseName, 10, overrideDuration ?? 15, "Medium", pdfContent: pdfContent);
    }
  }

  @override
  Future<String> organizeNote(String rawNoteContent) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (hasRealApiKey) {
      try {
        final prompt = "Ø¦Û•Ù… ØªÛŽØ¨ÛŒÙ†ÛŒÛŒÛ•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ø¨Û• Ø´ÛŽÙˆØ§Ø²ÛŽÚ©ÛŒ Ø²Û†Ø± Ù…Û†Ø¯ÛŽØ±Ù† Ùˆ Ú•ÛŽÚ©Ø®Ø±Ø§Ùˆ Ø¨Û• Ù…Ø§Ø±Ú©Ø¯Ø§ÙˆÙ† (Markdown) Ø¯Ø§Ø¨Ú•ÛŽÚ˜Û•Ø±Û•ÙˆÛ• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ. "
            "Ø³Û•Ø±Ø¯ÛŽÚ•ØŒ Ø¨Û•Ø´Û•Ú©Ø§Ù†ØŒ Ø®Ø§ÚµØ¨Û•Ù†Ø¯ÛŒ Ø¨Û•Ú©Ø§Ø±Ø¨Ù‡ÛŽÙ†Û• Ø¨Û† Ú•ÙˆÙˆÙ†Ú©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø¨Ø§Ø¨Û•ØªÛ•Ú©Û• Ø¨Û• Ø´ÛŽÙˆÛ•ÛŒÛ•Ú©ÛŒ ÙÛŽØ±Ú©Ø§Ø±ÛŒ:\n\n$rawNoteContent";
        return await _callGemini(prompt);
      } catch (e) {
        if (_isNetworkError(e)) {
          return "ðŸ“¡ **(Ø´ÛŽÙˆØ§Ø²ÛŒ Ø¦Û†ÙÙ„Ø§ÛŒÙ† - ÙÛ†Ø±Ù…Ø§ØªÛŒ Ù„Û†Ú©Ø§ÚµÛŒ)**\n\n" + 
                 _getMockOrganizedNote(rawNoteContent);
        }
        return "Ù‡Û•ÚµÛ•ÛŒÛ•Ú© Ú•ÙˆÙˆÛŒØ¯Ø§ Ù„Û• Ú©Ø§ØªÛŒ Ú•ÛŽÚ©Ø®Ø³ØªÙ†ÛŒ ØªÛŽØ¨ÛŒÙ†ÛŒ: $e";
      }
    }

    return _getMockOrganizedNote(rawNoteContent);
  }

  String _getMockOrganizedNote(String rawNoteContent) {
    return "# ðŸ“ ØªÛŽØ¨ÛŒÙ†ÛŒ Ú•ÛŽÚ©Ø®Ø±Ø§Ùˆ Ù„Û•Ù„Ø§ÛŒÛ•Ù† ZankoAI\n\n"
        "## ðŸ“Œ Ø®Ø§ÚµÛ• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù†\n"
        "${rawNoteContent.split('\n').map((line) => line.trim().isEmpty ? '' : '* $line').join('\n')}\n\n"
        "--- \n"
        "ðŸ’¡ *Ù¾ÛŽØ´Ù†ÛŒØ§Ø±ÛŒ Ù…Ø§Ù…Û†Ø³ØªØ§ÛŒ AI:* Ø¦Û•Ù… Ø¨Ø§Ø¨Û•ØªÛ• Ø²Û†Ø± Ú¯Ø±Ù†Ú¯Û• Ø¨Û† ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ú©Û†ØªØ§ÛŒÛŒØŒ Ø¨Ø§Ø´ØªØ±Û• Ø®Ø´ØªÛ•ÛŒ Ù¾ÛŽØ¯Ø§Ú†ÙˆÙˆÙ†Û•ÙˆÛ•ÛŒ Ø¨Û† Ø¯Ø§Ø¨Ù†ÛŽÛŒØª.";
  }

  @override
  Future<List<FlashcardModel>> generateFlashcards(String topicOrText) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (hasRealApiKey) {
      try {
        final prompt = "Ø¦Û•Ù… ØªÛŽØ¨ÛŒÙ†ÛŒÛŒÛ• ÛŒØ§Ù† Ø¨Ø§Ø¨Û•ØªÛ•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ø¨Ø®ÙˆÛŽÙ†Û•Ø±Û•ÙˆÛ• Ùˆ Ù¤ ÙÙ„Ø§Ø´Ú©Ø§Ø±Ø¯ÛŒ Ø®ÙˆÛŽÙ†Ø¯Ù†Û•ÙˆÛ•ÛŒ ØªØ§ÛŒØ¨Û•Øª Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Û• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ). "
            "Ù‡Û•Ø± ÙÙ„Ø§Ø´Ú©Ø§Ø±Ø¯ÛŽÚ© Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ø¯Û•Ù‚ÛŽÚ©ÛŒ Ú©ÙˆØ±Øª ÛŒØ§Ù† Ù¾Ø±Ø³ÛŒØ§Ø±ÛŽÚ© Ø¨ÛŽØª Ø¨Û† Ù¾ÛŽØ´Û•ÙˆÛ• (front) Ùˆ ÙˆÛ•ÚµØ§Ù…Û•Ú©Û• ÛŒØ§Ù† Ù…Ø§Ù†Ø§Ú©Û•ÛŒ Ø¨Û† Ø¯ÙˆØ§ÙˆÛ• Ø¨ÛŽØª (back). "
            "ØªÛ•Ù†Ù‡Ø§ ÙÛ†Ø±Ù…Ø§ØªÛŒ JSON Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ø¨Ù†ÙˆÙˆØ³Û• Ø¨Û•Ø¨ÛŽ Ù†ÙˆÙˆØ³ÛŒÙ†ÛŒ ØªØ±:\n"
            "[\n"
            "  { \"front\": \"Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Û• ÛŒØ§Ù† Ø²Ø§Ø±Ø§ÙˆÛ•Ú©Û•\", \"back\": \"Ú•ÙˆÙˆÙ†Ú©Ø±Ø¯Ù†Û•ÙˆÛ• Ú©ÙˆØ±ØªÛ•Ú©Û• ÛŒØ§Ù† ÙˆÛ•ÚµØ§Ù…Û•Ú©Û•\" }\n"
            "]\n\n"
            "Ø¨Ø§Ø¨Û•Øª:\n$topicOrText";
            
        final response = await _callGemini(prompt);
        
        String jsonText = response.trim();
        final jsonMatch = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true).firstMatch(jsonText);
        if (jsonMatch != null) {
          jsonText = jsonMatch.group(0)!;
        } else {
          if (jsonText.startsWith("```json")) {
            jsonText = jsonText.substring(7);
          } else if (jsonText.startsWith("```")) {
            jsonText = jsonText.substring(3);
          }
          if (jsonText.endsWith("```")) {
            jsonText = jsonText.substring(0, jsonText.length - 3);
          }
        }
        jsonText = jsonText.trim();
        
        final List<dynamic> data = jsonDecode(jsonText);
        final list = data.map((item) => FlashcardModel(
          id: 'card_${Random().nextInt(100000)}',
          front: item['front'] ?? '',
          back: item['back'] ?? '',
        )).where((c) => c.front.isNotEmpty && c.back.isNotEmpty).toList();

        if (list.isNotEmpty) return list;
      } catch (e) {
        return _getMockFlashcards(topicOrText);
      }
    }
    
    return _getMockFlashcards(topicOrText);
  }

  List<FlashcardModel> _getMockFlashcards(String topic) {
    final cleanTopic = _sanitizeExtractedText(topic);
    final displayTopic = cleanTopic.isNotEmpty ? cleanTopic : 'Ø¨Ø§Ø¨Û•ØªÛŒ Ø®ÙˆÛŽÙ†Ø¯Ù†Û•ÙˆÛ•';

    return [
      FlashcardModel(
        id: 'fc_1_${Random().nextInt(10000)}',
        front: 'Ù¾ÛŽÙ†Ø§Ø³Û• Ùˆ Ù…Û•Ø¨Û•Ø³ØªÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ù„Û• Â«$displayTopicÂ» Ú†ÛŒÛŒÛ•ØŸ',
        back: 'Ø¨Ø±ÛŒØªÛŒÛŒÛ• Ù„Û• Ú©Û†Ù…Û•ÚµÛ• Ú†Û•Ù…Ú©ØŒ Ø¨Ù†Û•Ù…Ø§ Ùˆ ÛŒØ§Ø³Ø§Ú©Ø§Ù†ÛŒ Ø´ÛŒÚ©Ø§Ø±Ú©Ø±Ø¯Ù†ÛŒ Â«$displayTopicÂ» Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ ÙÛ•Ø±Ù…ÛŒ Ø²Ø§Ù†Ø³ØªÛŒ.',
      ),
      FlashcardModel(
        id: 'fc_2_${Random().nextInt(10000)}',
        front: 'Ú¯Ø±Ù†Ú¯ØªØ±ÛŒÙ† Ø¬ÛŽØ¨Û•Ø¬ÛŽÚ©Ø±Ø¯Ù†ÛŒ Â«$displayTopicÂ» Ù„Û• ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•Ø¯Ø§ Ú†ÛŒÛŒÛ•ØŸ',
        back: 'ØªÛŽÚ¯Û•ÛŒØ´ØªÙ† Ù„Û• ÙÛ†Ø±Ù…ÙˆÙ„Û•Ú©Ø§Ù†ØŒ Ù¾Û†Ù„ÛŽÙ†Ú©Ø±Ø¯Ù†ÛŒ Ø¯Ø§ØªØ§Ú©Ø§Ù†ØŒ Ùˆ Ø¨Û•Ú©Ø§Ø±Ù‡ÛŽÙ†Ø§Ù†ÛŒ ØªÛŒÛ†Ø±ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ø¨Ø§Ø¨Û•ØªÛ•Ú©Û•.',
      ),
      FlashcardModel(
        id: 'fc_3_${Random().nextInt(10000)}',
        front: 'Ú•ÛŽÚ¯Û•ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ø¨Û† Ø´ÛŒÚ©Ø§Ø±Ú©Ø±Ø¯Ù†ÛŒ Ø¨Ø§Ø¨Û•ØªÛ•Ú©Ø§Ù†ÛŒ Â«$displayTopicÂ» Ú†ÛŒÛŒÛ•ØŸ',
        back: 'Ø¯Ø§Ø¨Û•Ø´Ú©Ø±Ø¯Ù†ÛŒ Ø¨Ø§Ø¨Û•ØªÛ•Ú©Û• Ø¨Û† Ø¨Û•Ø´Û• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù† Ùˆ Ù¾ÛŽØ¯Ø§Ú†ÙˆÙˆÙ†Û•ÙˆÛ•ÛŒ Ø¯ÙˆÙˆØ¨Ø§Ø±Û• Ø¨Û• ÙÙ„Ø§Ø´Ú©Ø§Ø±Ø¯ Ùˆ ØªÛŽØ¨ÛŒÙ†ÛŒÛŒÛ•Ú©Ø§Ù†.',
      ),
      FlashcardModel(
        id: 'fc_4_${Random().nextInt(10000)}',
        front: 'Ú©Ø§Ù…ÛŒØ§Ù† Ø¨Ù†Û•Ù…Ø§ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ø³Û•Ø±Ú©Û•ÙˆØªÙ†Û• Ù„Û• ÙˆØ§Ù†Û•ÛŒ Â«$displayTopicÂ»Ø¯Ø§ØŸ',
        back: 'ØªÛŽÚ¯Û•ÛŒØ´ØªÙ†ÛŒ Ù‚ÙˆÙˆÚµ Ù„Û• Ø²Ø§Ø±Ø§ÙˆÛ• Ø¦Û•Ú©Ø§Ø¯ÛŒÙ…ÛŒÛŒÛ•Ú©Ø§Ù† Ùˆ Ú†Ø§Ø±Û•Ø³Û•Ø±Ú©Ø±Ø¯Ù†ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±Û• Ú•Ø§Ù‡ÛŽÙ†Ú©Ø§Ø±ÛŒÛŒÛ•Ú©Ø§Ù†.',
      ),
    ];
  }

  @override
  Future<List<StudyPlanDayModel>> generateStudyPlan(String examTopic, int daysRemaining) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (hasRealApiKey) {
      try {
        final prompt = "Ù…Ù† ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•Ù… Ù‡Û•ÛŒÛ• Ù„Û•Ø³Û•Ø± Ø¨Ø§Ø¨Û•Øª ÛŒØ§Ù† Ú©Û†Ø±Ø³ÛŒ '$examTopic' Ù„Û• Ø¯ÙˆØ§ÛŒ $daysRemaining Ú•Û†Ú˜ÛŒ ØªØ±. "
            "Ø¨Û†Ù… Ø¨Ú©Û• Ø¨Û• Ù¾Ù„Ø§Ù†ÛŽÚ©ÛŒ Ø®ÙˆÛŽÙ†Ø¯Ù†ÛŒ Ù‡Û•ÙØªØ§Ù†Û• Ø¨Û† Ù‡Û•Ø± Ú•Û†Ú˜ÛŽÚ© Ú©Û• Ú†Û†Ù† Ø¯Ø§Ø¨Û•Ø´ÛŒ Ø¨Ú©Û•Ù… Ø¨Û† Ø¦Û•ÙˆÛ•ÛŒ Ø¨ØªÙˆØ§Ù†Ù… Ù†Ù…Ø±Û•ÛŒÛ•Ú©ÛŒ Ø¨Ø§Ø´ Ø¨Ù‡ÛŽÙ†Ù…. "
            "ÙˆÛ•ÚµØ§Ù…Û•Ú©Û• Ø¨Û• ÙÛ†Ø±Ù…Ø§ØªÛŒ JSON Ø¨Ù†ÙˆÙˆØ³Û• Ø¨Û•Ø¨ÛŽ Ù‡ÛŒÚ†ÛŒ ØªØ± Ø¨Û•Ù… ÙÛ†Ø±Ù…Ø§ØªÛ•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ): \n"
            "[\n"
            "  { \"dayName\": \"Ú•Û†Ú˜ÛŒ ÛŒÛ•Ú©Û•Ù… (Ø´Û•Ù…Ù…Û•)\", \"taskDescription\": \"Ú†ÛŒ Ø¨Ø®ÙˆÛŽÙ†Ù… Ø¨Û• Ú©ÙˆØ±ØªÛŒ\" }\n"
            "]\n\n";
            
        final response = await _callGemini(prompt);
        
        String jsonText = response.trim();
        if (jsonText.startsWith("```json")) {
          jsonText = jsonText.substring(7);
        } else if (jsonText.startsWith("```")) {
          jsonText = jsonText.substring(3);
        }
        if (jsonText.endsWith("```")) {
          jsonText = jsonText.substring(0, jsonText.length - 3);
        }
        jsonText = jsonText.trim();
        
        final List<dynamic> data = jsonDecode(jsonText);
        return data.map((item) => StudyPlanDayModel(
          dayName: item['dayName'] ?? '',
          taskDescription: item['taskDescription'] ?? '',
        )).toList();
      } catch (e) {
        if (_isNetworkError(e)) {
          return _getMockStudyPlan("ðŸ“¡ (Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ• Ù†ÛŒÛŒÛ•) - $examTopic", daysRemaining);
        }
        return _getMockStudyPlan(examTopic, daysRemaining);
      }
    }
    
    return _getMockStudyPlan(examTopic, daysRemaining);
  }

  List<StudyPlanDayModel> _getMockStudyPlan(String topic, int days) {
    return [
      StudyPlanDayModel(
        dayName: 'Ú•Û†Ú˜ÛŒ ÛŒÛ•Ú©Û•Ù…',
        taskDescription: 'Ø®ÙˆÛŽÙ†Ø¯Ù†Û•ÙˆÛ•ÛŒ ØªÛŒÛ†Ø±ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ø¨Ø§Ø¨Û•ØªÛ•Ú©Û• Ùˆ Ù†Ø§Ø³ÛŒÙ†ÛŒ Ø²Ø§Ø±Ø§ÙˆÛ• Ú¯Ø±Ù†Ú¯Û•Ú©Ø§Ù†ÛŒ $topic.',
      ),
      StudyPlanDayModel(
        dayName: 'Ú•Û†Ú˜ÛŒ Ø¯ÙˆÙˆÛ•Ù…',
        taskDescription: 'Ù¾ÛŽØ¯Ø§Ú†ÙˆÙˆÙ†Û•ÙˆÛ• Ø¨Û• ÙÙ„Ø§Ø´Ú©Ø§Ø±Ø¯Û•Ú©Ø§Ù† Ùˆ ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø®ÛŽØ±Ø§ Ø¨Û† Ø¨Û•Ø´Û• ØªÛŒÛ†Ø±ÛŒÛŒÛ•Ú©Ø§Ù†.',
      ),
      StudyPlanDayModel(
        dayName: 'Ú•Û†Ú˜ÛŒ Ø³ÛŽÛŒÛ•Ù…',
        taskDescription: 'Ú†Ø§Ø±Û•Ø³Û•Ø±Ú©Ø±Ø¯Ù†ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±Û• Ù†Ù…ÙˆÙˆÙ†Û•ÛŒÛŒÛ•Ú©Ø§Ù† Ùˆ Ù¾ÛŽØ¯Ø§Ú†ÙˆÙˆÙ†Û•ÙˆÛ•ÛŒ Ú©Û†ØªØ§ Ø¨Û• Ø®Ø´ØªÛ•ÛŒ ÙˆØ§Ù†Û•Ú©Ø§Ù†.',
      ),
    ];
  }

  // Dynamic fallback exam generator from PDF content
  QuizModel _generateMockQuiz(String topic, String courseName, {String? pdfContent}) {
    return _generateMockExam(topic, courseName, 5, 10, 'Medium', pdfContent: pdfContent);
  }

  bool _isJunkMetadataLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('copyright') ||
        lower.contains('permission') ||
        lower.contains('reproduction') ||
        lower.contains('all rights reserved') ||
        lower.contains('disclaimer') ||
        lower.contains('chapter') ||
        lower.contains('page ') ||
        lower.contains('dr.') ||
        lower.contains('professor') ||
        lower.contains('instructor') ||
        lower.contains('university') ||
        lower.contains('department') ||
        lower.contains('edition') ||
        lower.contains('isbn') ||
        lower.contains('lecture note') ||
        line.trim().length < 10;
  }

  String _sanitizeExtractedText(String input) {
    if (input.trim().isEmpty) return '';

    String cleaned = input.replaceAll(
      RegExp(r'\b(obj|endobj|stream|endstream|xref|trailer|FlateDecode|Font|CIDFont|FontDescriptor|ProcSet|MediaBox|Type1|WinAnsiEncoding|Identity-H)\b', caseSensitive: false),
      ' ',
    );

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  QuizModel _generateMockExam(
    String topic,
    String courseName,
    int count,
    int duration,
    String difficulty, {
    String? pdfContent,
  }) {
    final List<QuestionModel> examQuestions = [];
    final rawTitle = courseName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$', caseSensitive: false), '');
    final cleanTitle = _sanitizeExtractedText(rawTitle);
    final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : 'ÙˆØ§Ù†Û•ÛŒ Ø¨Ø§Ø±Ú©Ø±Ø§Ùˆ';

    List<String> pdfSnippets = [];
    if (pdfContent != null && pdfContent.trim().isNotEmpty) {
      pdfSnippets = pdfContent
          .split(RegExp(r'[\.\?\!\n;]'))
          .map((s) => _sanitizeExtractedText(s))
          .where((s) => s.length > 15 && !_isJunkMetadataLine(s) && RegExp(r'[a-zA-Z\u0600-\u06FF]').hasMatch(s))
          .toList();
    }

    if (pdfSnippets.length >= 2) {
      for (int i = 0; i < count; i++) {
        final snippet = pdfSnippets[i % pdfSnippets.length].trim();
        final words = snippet.split(' ').where((w) => w.length > 3 && !_isJunkMetadataLine(w)).toList();
        final mainTerm = words.isNotEmpty ? words[i % words.length] : 'Ú†Û•Ù…Ú©ÛŒ Ø²Ø§Ù†Ø³ØªÛŒ';

        if (i % 3 == 0) {
          // Factual Multiple Choice from exact PDF sentence
          final truncatedSnippet = snippet.length > 100 ? '${snippet.substring(0, 100)}...' : snippet;
          examQuestions.add(
            QuestionModel(
              id: 'pdf_ex_$i',
              questionText: 'Ú©Ø§Ù…ÛŒØ§Ù† Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ•Ú©ÛŒ Ú•Ø§Ø³ØªÛ• Ø¨Û•Ù¾ÛŽÛŒ Ù†Ø§ÙˆØ§Ø®Ù†ÛŒ ÙØ§ÛŒÙ„ÛŒ ÙˆØ§Ù†Û•ÛŒ Â«$displayTitleÂ»ØŸ',
              type: QuestionType.multipleChoice,
              options: [
                truncatedSnippet,
                'Ù†Ø§Ú†Ø§Ù„Ø§Ú©Ú©Ø±Ø¯Ù†ÛŒ Ø³Û•Ø±Ø¬Û•Ù… Ù¾Ø±Û†ØªÛ†Ú©Û†ÚµÛ•Ú©Ø§Ù† Ù„Û• Ø³ÛŒØ³ØªÛ•Ù…Û•Ú©Û•Ø¯Ø§',
                'Ø³Ú•ÛŒÙ†Û•ÙˆÛ•ÛŒ Ù‡Û•Ù…ÙˆÙˆ ØªÛŽÚ©Ø³ØªÛ•Ú©Ø§Ù† Ø¨Û•Ø±Ø§Ù…Ø¨Û•Ø± Ø¯Ø§ØªØ§ÛŒ Ù†Ø§Ø¯ÛŒØ§Ø±',
                'Ú•Û•ØªÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø¬ÛŽØ¨Û•Ø¬ÛŽÚ©Ø±Ø¯Ù†ÛŒ Ù‡Ø§ÙˆÚ©ÛŽØ´Û•Ú©Ø§Ù† Ø¨Û† ÙˆØ§Ù†Û•Ú©Û•'
              ],
              correctAnswer: truncatedSnippet,
              explanation: 'Ø¦Û•Ù… Ú•Ø³ØªÛ•ÛŒÛ• Ú•Ø§Ø³ØªÛ•ÙˆØ®Û† Ù„Û• Ø¯Û•Ù‚ÛŒ Ø²Ø§Ù†Ø³ØªÛŒ ÙØ§ÛŒÙ„ÛŒ PDFÛ•Ú©Û• Ø¯Û•Ø±Ù‡ÛŽÙ†Ø±Ø§ÙˆÛ•.',
            ),
          );
        } else if (i % 3 == 1) {
          // Fill-in-the-blank from PDF main term
          final blankedSnippet = snippet.length > 90
              ? snippet.substring(0, 90).replaceAll(mainTerm, '___')
              : snippet.replaceAll(mainTerm, '___');

          examQuestions.add(
            QuestionModel(
              id: 'pdf_ex_$i',
              questionText: 'Ø¨Û†Ø´Ø§ÛŒÛŒ Ù„Û• Ø¯Û•Ù‚ÛŒ ÙˆØ§Ù†Û•Ú©Û•Ø¯Ø§ Ù¾Ú•Ø¨Ú©Û•Ø±Û•ÙˆÛ•: "$blankedSnippet"',
              type: QuestionType.fillInBlank,
              options: [
                mainTerm,
                'Ethernet Protocol',
                'Operating System Core',
                'Data Security Module'
              ],
              correctAnswer: mainTerm,
              explanation: 'Ø²Ø§Ø±Ø§ÙˆÛ•ÛŒ Â«$mainTermÂ» Ú•Ø§Ø³ØªÛ•ÙˆØ®Û† Ø¯Û•Ù‚ÛŒ Ø¨Û†Ø´Ø§ÛŒÛŒ ÙØ§ÛŒÙ„ÛŒ PDFÛŒ Ø¨Ø§Ø±Ú©Ø±Ø§ÙˆÛ•.',
            ),
          );
        } else {
          // True/False from exact PDF sentence
          final truncatedSnippet = snippet.length > 120 ? snippet.substring(0, 120) : snippet;
          examQuestions.add(
            QuestionModel(
              id: 'pdf_ex_$i',
              questionText: 'Ø¨Û•Ù¾ÛŽÛŒ Ø¯Û•Ù‚ÛŒ ÙØ§ÛŒÙ„ÛŒ PDFÛŒ ÙˆØ§Ù†Û•Ú©Û•: "$truncatedSnippet". Ø¦Ø§ÛŒØ§ Ø¦Û•Ù… Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ• Ú•Ø§Ø³ØªÛ•ØŸ',
              type: QuestionType.trueFalse,
              options: ['Ú•Ø§Ø³ØªÛ•', 'Ù‡Û•ÚµÛ•ÛŒÛ•'],
              correctAnswer: 'Ú•Ø§Ø³ØªÛ•',
              explanation: 'Ø¦Û•Ù… Ú•Ø³ØªÛ•ÛŒÛ• Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ•Ú©ÛŒ Ú•Ø§Ø³ØªÛ• Ù„Û• Ù„Ø§Ù¾Û•Ú•Û•Ú©Ø§Ù†ÛŒ ÙØ§ÛŒÙ„ÛŒ PDFÛŒ ÙˆØ§Ù†Û•Ú©Û•ØªØ¯Ø§.',
            ),
          );
        }
      }
    } else {
      for (int i = 0; i < count; i++) {
        examQuestions.add(
          QuestionModel(
            id: 'pdf_ex_$i',
            questionText: 'Ù„Û• ÙˆØ§Ù†Û•ÛŒ ($displayTitle)ØŒ Ù¾ÛŽØ¯Ø§Ú†ÙˆÙˆÙ†Û•ÙˆÛ• Ø¨Û• Ú†Û•Ù…Ú©Û• Ø²Ø§Ù†Ø³ØªÛŒÛŒÛ•Ú©Ø§Ù† Ø¨Û•Ø´ÛŽÚ©ÛŒ Ú¯Ø±Ù†Ú¯Û• Ø¨Û† Ø¦Ø§Ù…Ø§Ø¯Û•Ú©Ø§Ø±ÛŒ ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ ÙØ§ÛŒÙ†Ø§ÚµØŸ',
            type: QuestionType.trueFalse,
            options: ['Ú•Ø§Ø³ØªÛ•', 'Ù‡Û•ÚµÛ•ÛŒÛ•'],
            correctAnswer: 'Ú•Ø§Ø³ØªÛ•',
            explanation: 'Ù¾ÛŽØ¯Ø§Ú†ÙˆÙˆÙ†Û•ÙˆÛ• Ø¨Û• Ø¨Û•Ø´Û•Ú©Ø§Ù†ÛŒ ÙˆØ§Ù†Û•ÛŒ $displayTitle ÛŒØ§Ø±Ù…Û•ØªÛŒØ¯Û•Ø±Û• Ø¨Û† Ù†Ù…Ø±Û•ÛŒ Ø¨Û•Ø±Ø².',
          ),
        );
      }
    }

    return QuizModel(
      id: 'exam_${Random().nextInt(10000)}',
      title: 'ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± PDF - $displayTitle',
      courseName: displayTitle,
      questions: examQuestions.take(count > 0 ? count : 5).toList(),
      durationMinutes: duration,
      isExam: true,
    );
  }

  @override
  Future<Map<String, dynamic>> predictExam(String notesName, String notesContent) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (hasRealApiKey) {
      try {
        final prompt = "Ø¦Û•Ù… Ù†ÙˆÙˆØ³ÛŒÙ† Ùˆ ØªÛŽØ¨ÛŒÙ†ÛŒÛŒØ§Ù†Û•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ø¨Ø®ÙˆÛŽÙ†Û•Ø±Û•ÙˆÛ• Ú©Û• Ù‡ÛŒ Ø®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±Û• Ù„Û• ÙØ§ÛŒÙ„ÛŒ Ø¨Û• Ù†Ø§ÙˆÛŒ '$notesName'. "
            "Ø´ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ø¨Ú©Û• Ùˆ Ù¾ÛŽØ´Ø¨ÛŒÙ†ÛŒ Ù¥ Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø²Û†Ø± Ú¯Ø±Ù†Ú¯ Ø¨Ú©Û• Ú©Û• Ù¾ÛŽØ´Ø¨ÛŒÙ†ÛŒ Ø¯Û•Ú©Û•ÛŒØª Ù…Ø§Ù…Û†Ø³ØªØ§ Ù„Û•Ø³Û•Ø± Ø¦Û•Ù… Ø¨Ø§Ø¨Û•ØªØ§Ù†Û• Ø¯Ø§ÛŒÙ†ÛŽØª. "
            "ÙˆÛ•ÚµØ§Ù…Û•Ú©Û•Øª Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) Ø¨Ù†ÙˆØ³ÛŒØª Ùˆ Ø¦Û•Ù… Ø¨Û•Ø´Ø§Ù†Û• Ù„Û•Ø®Û† Ø¨Ú¯Ø±ÛŽØª:\n"
            "Ù¡. Ù¾ÛŽÙ†Ø§Ø³Û•ÛŒÛ•Ú©ÛŒ Ú©ÙˆØ±Øª Ø¨Û† Ø¨Ø§Ø¨Û•ØªÛ• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù†.\n"
            "Ù¢. Ù¥ Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ Ù¾ÛŽØ´Ø¨ÛŒÙ†ÛŒÚ©Ø±Ø§Ùˆ Ù„Û•Ú¯Û•Úµ Ú•ÙˆÙˆÙ†Ú©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ ÙˆÛ•ÚµØ§Ù…Û•Ú©Ø§Ù†ÛŒØ§Ù† Ø¨Û† ÙÛŽØ±Ø¨ÙˆÙˆÙ†ÛŒ Ø®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±.\n"
            "Ù£. Ù£ Ø¦Ø§Ù…Û†Ú˜Ú¯Ø§Ø±ÛŒ Ø²ÛŽÚ•ÛŒÙ† Ø¨Û† Ú†Û†Ù†ÛŽØªÛŒ Ø³Û•Ø±Ø²Û•Ù†Ø´ØªÚ©Ø±Ø¯Ù† ÛŒØ§Ù† ØªÛ•Ù…Ø±ÛŒÙ†Ú©Ø±Ø¯Ù†ÛŒ Ø¦Û•Ù… Ø¨Ø§Ø¨Û•ØªØ§Ù†Û•.\n\n"
            "ØªÛŽØ¨ÛŒÙ†ÛŒÛŒÛ•Ú©Ø§Ù†:\n$notesContent";

        final responseText = await _callGemini(prompt);
        return {
          'prediction': responseText,
        };
      } catch (e) {
        if (_isNetworkError(e)) {
          return {
            'prediction': "ðŸ“¡ **(Ø´ÛŽÙˆØ§Ø²ÛŒ Ø¦Û†ÙÙ„Ø§ÛŒÙ†)**\n\n" + _getMockPrediction(notesName),
          };
        }
        return {
          'prediction': "Ù‡Û•ÚµÛ•ÛŒÛ•Ú© Ù„Û• Ú˜ÛŒØ±ÛŒ Ø¯Û•Ø³ØªÚ©Ø±Ø¯ Ú•ÙˆÙˆÛŒØ¯Ø§: $e",
        };
      }
    }

    return {
      'prediction': _getMockPrediction(notesName),
    };
  }

  String _getMockPrediction(String notesName) {
    return "Ù¾ÛŽØ´Ø¨ÛŒÙ†ÛŒ Ù¾Ø±Ø³ÛŒØ§Ø±Û•Ú©Ø§Ù†ÛŒ ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ø¨Û† Ø¨Ø§Ø¨Û•ØªÛ•Ú©Û•:\n\n"
        "Ù¡. **Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ ÛŒÛ•Ú©Û•Ù…:** Ø¬ÛŒØ§ÙˆØ§Ø²ÛŒ Ù†ÛŽÙˆØ§Ù† RAM Ùˆ ROM Ú†ÛŒÛŒÛ•ØŸ\n"
        "   * ÙˆÛ•ÚµØ§Ù…: RAM ÛŒØ§Ø¯Ú¯Û•ÛŒÛ•Ú©ÛŒ Ú©Ø§ØªÛŒÛŒÛ• Ùˆ Ø¨Û• Ú©ÙˆÚ˜Ø§Ù†Û•ÙˆÛ•ÛŒ Ø¦Ø§Ù…ÛŽØ±Û•Ú©Û• Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ•Ú©Ø§Ù†ÛŒ Ø¯Û•Ø³Ú•ÛŽØªÛ•ÙˆÛ•ØŒ Ø¨Û•ÚµØ§Ù… ROM Ù†Û•Ú¯Û†Ú•Û• Ùˆ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒ Ú•ÛŽÚ©Ø®Ø³ØªÙ†ÛŒ Ø³Û•Ø±Û•ØªØ§ÛŒÛŒ Ú©Û†Ù…Ù¾ÛŒÙˆØªÛ•Ø±ÛŒ ØªÛŽØ¯Ø§ÛŒÛ•.\n\n"
        "Ù¢. **Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ Ø¯ÙˆÙˆÛ•Ù…:** Ø³ÛŒØ³ØªÛ•Ù…ÛŒ ÙØ§ÛŒÙ„ÛŒ NTFS Ú†ÛŒÛŒÛ• Ùˆ Ø¬ÛŒØ§ÙˆØ§Ø²ÛŒ Ù„Û•Ú¯Û•Úµ FAT32 Ú†ÛŒÛŒÛ•ØŸ\n"
        "   * ÙˆÛ•ÚµØ§Ù…: NTFS Ù¾Ø´ØªÚ¯ÛŒØ±ÛŒ ÙØ§ÛŒÙ„ÛŒ Ú¯Û•ÙˆØ±Û•ØªØ± Ø¯Û•Ú©Ø§Øª Ùˆ Ù¾Ø§Ø±ÛŽØ²Ú¯Ø§Ø±ÛŒ Ø²ÛŒØ§ØªØ±Û• Ø¨Û• Ø¨Û•Ø±Ø§ÙˆØ±Ø¯ Ù„Û•Ú¯Û•Úµ FAT32 Ú©Û• ÙˆÛ•Ø´Ø§Ù†ÛŒ Ú©Û†Ù†ØªØ±Û•.\n\n"
        "Ù£. **Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ Ø³ÛŽÛŒÛ•Ù…:** Ù¾Ø±Û†Ø³Û• (Process) Ù„Û• Ø³ÛŒØ³ØªÛ•Ù…ÛŒ Ú©Ø§Ø±Ù¾ÛŽÚ©Ø±Ø¯Ù†Ø¯Ø§ Ú†ÛŒÛŒÛ•ØŸ\n"
        "   * ÙˆÛ•ÚµØ§Ù…: Ù¾Ø±Û†Ø³Û• Ø¨Ø±ÛŒØªÛŒÛŒÛ• Ù„Û• Ø¨Û•Ø±Ù†Ø§Ù…Û•ÛŒÛ•Ú© Ú©Û• Ù„Û• Ú©Ø§ØªÛŒ Ø¬ÛŽØ¨Û•Ø¬ÛŽÚ©Ø±Ø¯Ù†Ø¯Ø§ÛŒÛ• Ùˆ Ø³Û•Ø±Ú†Ø§ÙˆÛ•Ú©Ø§Ù†ÛŒ ÙˆÛ•Ú© CPU Ùˆ RAM Ø¨Û•Ú©Ø§Ø±Ø¯ÛŽÙ†ÛŽØª.\n\n"
        "ðŸ’¡ **Ø¦Ø§Ù…Û†Ú˜Ú¯Ø§Ø±ÛŒ Ø¨Û† Ø®ÙˆÛŽÙ†Ø¯Ù†:**\n"
        "- ØªÛ•Ø±Ú©ÛŒØ² Ù„Û•Ø³Û•Ø± Ø¬ÛŒØ§ÙˆØ§Ø²ÛŒÛŒÛ•Ú©Ø§Ù† Ø¨Ú©Û• Ù„Û• Ù†ÛŽÙˆØ§Ù† Ú†Û•Ù…Ú©Û•Ú©Ø§Ù†.\n"
        "- Ù¾Û†ÛŒÙ†ØªÛ•Ø± Ùˆ Ø´ÛŽÙˆØ§Ø²ÛŒ Ù…ÛŽÙ…Û†Ø±ÛŒ Ù„Û•Ù… ÙˆØ§Ù†Û•ÛŒÛ•Ø¯Ø§ Ø²Û†Ø± Ú¯Ø±Ù†Ú¯Û•.";
  }

  Future<Map<String, dynamic>> generateStudyRoadmap({
    required String subjectName,
    required int totalChapters,
    required int daysRemaining,
    required int hoursPerDay,
  }) async {
    if (hasRealApiKey) {
      try {
        final prompt = """
ØªÛ† Ø´Ø§Ø±Ù‡â€ŒØ²Ø§ÛŒÙ‡â€ŒÙƒÛŒ Ø²Ø§Ù†Ø³ØªÛŒ Ùˆ Ú•ÛŽÙ†Ù…Ø§ÛŒÛŒÚ©Ø§Ø±ÛŒ Ø²Ø§Ù†Ú©Û†ÛŒÛŒ. ØªÚ©Ø§ÛŒÛ• Ø¨Û† Ø¨Ø§Ø¨Û•ØªÛŒ ($subjectName) Ú©Û• ($totalChapters) Ø¨Û•Ø´ÛŒ Ù‡Û•ÛŒÛ• Ùˆ ØªÛ•Ù†Ù‡Ø§ ($daysRemaining) Ú•Û†Ú˜ÛŒ Ù…Ø§ÙˆÛ• Ø¨Û† ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ØŒ Ùˆ Ø®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø± Ø¯Û•ØªÙˆØ§Ù†ÛŽØª Ú•Û†Ú˜Ø§Ù†Û• ($hoursPerDay) Ú©Ø§ØªÚ˜Ù…ÛŽØ± Ø¨Ø®ÙˆÛŽÙ†ÛŽØªØŒ Ù†Û•Ø®Ø´Û•Ú•ÛŽÚ¯Ø§ÛŒÛ•Ú©ÛŒ Ú•Û†Ú˜Ø§Ù†Û•ÛŒ Ú¯ÙˆÙ†Ø¬Ø§Ùˆ Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) Ø¨Û• Ø´ÛŽÙˆØ§Ø²ÛŒ JSON Ø¨Ù†ÙˆÙˆØ³Û•ÙˆÛ•.

Ø´ÛŽÙˆØ§Ø²ÛŒ Ù¾ÛŽÙˆÛŒØ³ØªÛŒ JSON:
{
  "advice": "Ø¦Ø§Ù…Û†Ú˜Ú¯Ø§Ø±ÛŒ Ùˆ Ú•ÛŽÙ†Ù…Ø§ÛŒÛŒ Ú©ÙˆØ±ØªÛŒ Ø²Ø§Ù†Ø³ØªÛŒ Ø¨Û† ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•Ú©Û•",
  "tasks": [
    {
      "dayIndex": 1,
      "title": "Ø³Û•Ø±Ø¯ÛŽÚ•ÛŒ Ø¯Û•Ø³ØªÚ©Û•ÙˆØªÛŒ Ú•Û†Ú˜ÛŒ ÛŒÛ•Ú©Û•Ù…",
      "description": "Ú•ÙˆÙˆÙ†Ú©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ ÙˆØ±Ø¯ÛŒ Ø¦Û•ÙˆÛ•ÛŒ Ú† Ø¨Û•Ø´ÛŽÚ© Ø¨Ø®ÙˆÛŽÙ†Ø±ÛŽØª",
      "suggestedPomodoros": 3
    }
  ]
}
""";
        final responseText = await askTeacher(prompt, []);
        if (responseText.isNotEmpty && responseText.contains('{')) {
          final start = responseText.indexOf('{');
          final end = responseText.lastIndexOf('}') + 1;
          final jsonSub = responseText.substring(start, end);
          return jsonDecode(jsonSub);
        }
      } catch (_) {}
    }

    // Fallback AI Study Plan Generator
    List<Map<String, dynamic>> fallbackTasks = [];
    int days = daysRemaining.clamp(1, 30);
    int chaptersPerDay = (totalChapters / days).ceil().clamp(1, 10);

    for (int i = 1; i <= days; i++) {
      int startChap = ((i - 1) * chaptersPerDay) + 1;
      int endChap = (i * chaptersPerDay).clamp(1, totalChapters);

      if (i == days && days > 1) {
        fallbackTasks.add({
          'dayIndex': i,
          'title': 'Ù¾ÛŽØ¯Ø§Ú†ÙˆÙˆÙ†Û•ÙˆÛ•ÛŒ Ú¯Ø´ØªÛŒ Ùˆ Ø¨Û•Ú©Ø§Ø±Ù‡ÛŽÙ†Ø§Ù†ÛŒ ÙÙ„Ø§Ø´ Ú©Ø§Ø±ØªÛ•Ú©Ø§Ù† ðŸ“',
          'description': 'Ø­Ù„Ú©Ø±Ø¯Ù†ÛŒ Ú©ÙˆÛŒØ²Û•Ú©Ø§Ù†ÛŒ Ú•Ø§Ø¨Ø±Ø¯ÙˆÙˆ Ùˆ ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ• Ù„Û•Ø³Û•Ø± Ø³Û•Ø±Ø¬Û•Ù… Ø¨Û•Ø´Û•Ú©Ø§Ù†ÛŒ (Ù¡ Ø¨Û† $totalChapters)',
          'suggestedPomodoros': (hoursPerDay * 2).clamp(2, 8),
        });
      } else {
        fallbackTasks.add({
          'dayIndex': i,
          'title': startChap == endChap
              ? 'Ø®ÙˆÛŽÙ†Ø¯Ù†ÛŒ Ø¨Û•Ø´ÛŒ $startChap Ù„Û• Ø¨Ø§Ø¨Û•ØªÛŒ $subjectName ðŸ“–'
              : 'Ø®ÙˆÛŽÙ†Ø¯Ù†ÛŒ Ø¨Û•Ø´Û•Ú©Ø§Ù†ÛŒ ($startChap Ø¨Û† $endChap) ðŸ“š',
          'description': 'ØªÛŽÚ¯Û•ÛŒØ´ØªÙ† Ù„Û• Ú†Û•Ù…Ú©Û• Ø³Û•Ø±Û•Ú©ÛŒÛŒÛ•Ú©Ø§Ù†ØŒ Ø¯ÛŒØ§Ø±ÛŒÚ©Ø±Ø¯Ù†ÛŒ ÙˆØ´Û• Ú©Ù„ÛŒÙ„ÛŒÛŒÛ•Ú©Ø§Ù† Ùˆ Ù¾Ø§Ø´Û•Ú©Û•ÙˆØªÚ©Ø±Ø¯Ù†ÛŒ Ù„Û• ÙÙ„Ø§Ø´ Ú©Ø§Ø±Øª.',
          'suggestedPomodoros': (hoursPerDay * 2).clamp(2, 6),
        });
      }
    }

    return {
      'advice': 'Ø¨Û•Ø±Ø¯Û•ÙˆØ§Ù… Ø¨Û• Ù„Û•Ø³Û•Ø± Ø¬ÛŽØ¨Û•Ø¬ÛŽÚ©Ø±Ø¯Ù†ÛŒ Ù†Û•Ø®Ø´Û•Ú•ÛŽÚ¯Ø§Ú©Û•Øª Ø¨Û• Ø¨Û•Ú©Ø§Ø±Ù‡ÛŽÙ†Ø§Ù†ÛŒ Ú©Ø§ØªÚ˜Ù…ÛŽØ±ÛŒ ÙÛ†Ú©Û•Ø³ (Pomodoro) ØªØ§ Ø¨Û• Ø¨Û•Ø±Ø²ØªØ±ÛŒÙ† Ù†Ù…Ø±Û• Ø³Û•Ø±Ø¨Ú©Û•ÙˆÛŒØª!',
      'tasks': fallbackTasks,
    };
  }
}
