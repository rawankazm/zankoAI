import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/quiz_model.dart';
import '../models/flashcard_model.dart';
import '../models/study_plan_model.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;

import 'package:shared_preferences/shared_preferences.dart';

abstract class AiService extends ChangeNotifier {
  String? get apiKey;
  set apiKey(String? key);
  bool get hasRealApiKey;

  Future<String> askTeacher(String userPrompt, List<Map<String, String>> chatHistory);
  Future<Map<String, dynamic>> summarizePdf(String pdfName, String pdfContent);
  Future<QuizModel> generateQuiz(String topic, String courseName);
  Future<QuizModel> generateQuizFromText(String fileText, String courseName);
  Future<String> organizeNote(String rawNoteContent);
  Future<List<FlashcardModel>> generateFlashcards(String topicOrText);
  Future<List<StudyPlanDayModel>> generateStudyPlan(String examTopic, int daysRemaining);
  Future<Map<String, dynamic>> predictExam(String notesName, String notesContent);
}

class ZankoAiService extends ChangeNotifier implements AiService {
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  String? _apiKey;

  ZankoAiService() {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = prefs.getString('gemini_api_key');
    _apiKey = (savedKey != null && savedKey.trim().isNotEmpty) ? savedKey : _defaultApiKey;
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
  bool get hasRealApiKey => _apiKey != null && _apiKey!.trim().isNotEmpty;

  // Helper to determine if an error is connection-related
  bool _isNetworkError(dynamic error) {
    final errStr = error.toString().toLowerCase();
    return error is SocketException ||
        error is HttpException ||
        errStr.contains('socket') ||
        errStr.contains('connection') ||
        errStr.contains('host') ||
        errStr.contains('failed to connect') ||
        errStr.contains('network');
  }

  // Helper to call Gemini Model
  Future<String> _callGemini(String prompt, {String systemInstruction = ""}) async {
    if (!hasRealApiKey) throw Exception("No API key configured");
    
    final model = gemini.GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: _apiKey!,
      systemInstruction: systemInstruction.isNotEmpty
          ? gemini.Content.system(systemInstruction)
          : null,
    );
    
    final content = [gemini.Content.text(prompt)];
    final response = await model.generateContent(content);
    return response.text ?? "Ù†Û•ØªÙˆØ§Ù†Ø±Ø§ ÙˆÛ•ÚµØ§Ù… Ù„Û• Ù„Ø§ÛŒÛ•Ù† AI Ø¨Û•Ø¯Û•Ø³ØªØ¨Ù‡ÛŽÙ†Ø±ÛŽØª.";
  }

  @override
  Future<String> askTeacher(String userPrompt, List<Map<String, String>> chatHistory) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (hasRealApiKey) {
      try {
        String historyStr = "";
        for (var msg in chatHistory) {
          historyStr += "${msg['role'] == 'user' ? 'Ø®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±' : 'Ù…Ø§Ù…Û†Ø³ØªØ§'}: ${msg['content']}\n";
        }
        final prompt = "$historyStrØ®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±: $userPrompt\nÙ…Ø§Ù…Û†Ø³ØªØ§:";
        
        const systemInstruction = 
            "ØªÛ† Ù…Ø§Ù…Û†Ø³ØªØ§ÛŒÛ•Ú©ÛŒ Ø²ÛŒØ±Û•Ú©ÛŒ Ø²Ø§Ù†Ú©Û†ÛŒØª Ø¨Û• Ù†Ø§ÙˆÛŒ ZankoAI. ÙˆÛ•Ú© Ù…Ø§Ù…Û†Ø³ØªØ§ÛŒÛ•Ú©ÛŒ Ø¯ÚµØ³Û†Ø² Ùˆ Ú•ÙˆÙˆÙ† ÛŒØ§Ø±Ù…Û•ØªÛŒ Ø®ÙˆÛŽÙ†Ø¯Ú©Ø§Ø±Û•Ú©Û• Ø¨Ø¯Û•. "
            "ÙˆÛ•ÚµØ§Ù…Û•Ú©Ø§Ù†Øª Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) Ø¨Ù†. Ø¨Û• Ú•ÙˆÙˆÙ†ÛŒØŒ Ø®Ø§ÚµØ¨Û•Ù†Ø¯ÛŒØŒ Ùˆ Ø¨Û• Ø´ÛŽÙˆØ§Ø²ÛŽÚ©ÛŒ ÙÛŽØ±Ú©Ø§Ø±ÛŒ Ùˆ Ø¦Û•Ú©Ø§Ø¯ÛŒÙ…ÛŒ ÙˆÛ•ÚµØ§Ù… Ø¨Ø¯Û•Ø±Û•ÙˆÛ•.";
            
        return await _callGemini(prompt, systemInstruction: systemInstruction);
      } catch (e) {
        if (_isNetworkError(e)) {
          return "ðŸ“¡ **Ù‡ÛŽÚµÛŒ Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØªÛ•Ú©Û•Øª ØªÛŽÚ©Ú†ÙˆÙˆÛ• (No Internet Connection)**\n\n"
                 "Ù†Û•ØªÙˆØ§Ù†Ø±Ø§ Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ• Ù„Û•Ú¯Û•Úµ Ø³ÛŽØ±Ú¤Û•Ø±ÛŒ Google AI Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Ø±ÛŽØª. ØªÚ©Ø§ÛŒÛ• Ù‡ÛŽÚµÛŒ Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØªÛ•Ú©Û•Øª Ú†Ø§Ú© Ø¨Ú©Û•Ø±Û•ÙˆÛ• Ùˆ Ø¯ÙˆÙˆØ¨Ø§Ø±Û• Ù‡Û•ÙˆÚµØ¨Ø¯Û•Ø±Û•ÙˆÛ•.\n\n"
                 "Please check your internet connection and try again.";
        }
        return "âš ï¸ Ù‡Û•ÚµÛ•ÛŒÛ•Ú© Ú•ÙˆÙˆÛŒØ¯Ø§ Ù„Û• Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ• Ø¨Û• AI: $e\n\nØªÚ©Ø§ÛŒÛ• API Key ÛŒØ§Ù† Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ•ÛŒ Ø¦ÛŒÙ†ØªÛ•Ø±Ù†ÛŽØªÛ•Ú©Û•Øª Ø¨Ù¾Ø´Ú©Ù†Û•.";
      }
    }

    return "ðŸ”‘ **ØªÚ©Ø§ÛŒÛ• API Key Ø²ÛŒØ§Ø¯ Ø¨Ú©Û• (API Key Required)**\n\n"
           "ØªÚ©Ø§ÛŒÛ• Ú©Ù„ÛŒÚ© Ù„Û•Ø³Û•Ø± Ø¯ÙˆÚ¯Ù…Û•ÛŒ ðŸ”‘ (Ú©Ù„ÛŒÙ„) Ù„Û• Ø¯Û•Ø³ØªÛ• Ú•Ø§Ø³ØªÛŒ Ø³Û•Ø±Û•ÙˆÛ•ÛŒ Ø´Ø§Ø´Û•Ú©Û• Ø¨Ú©Û• Ø¨Û† Ø¯Ø§ØºÚµÚ©Ø±Ø¯Ù†ÛŒ Gemini API Key Ù¾Ø§Ø´Ø§Ù† Ø¯ÙˆÙˆØ¨Ø§Ø±Û• Ù‡Û•ÙˆÚµØ¨Ø¯Û•Ø±Û•ÙˆÛ•.\n\n"
           "Please add your Gemini API Key by tapping the ðŸ”‘ icon at the top right of the screen, or check your internet connection.";
  }

  @override
  Future<Map<String, dynamic>> summarizePdf(String pdfName, String pdfContent) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    if (hasRealApiKey) {
      try {
        final prompt = "Ø¦Û•Ù… Ø¯Û•Ù‚Û•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ú©Û• Ù„Û• ÙØ§ÛŒÙ„ÛŒ Ø¨Û• Ù†Ø§ÙˆÛŒ '$pdfName' Ø¯Û•Ø±Ù‡ÛŽÙ†Ø±Ø§ÙˆÛ• Ø¨Û• ÙˆØ±Ø¯ÛŒ Ú©ÙˆØ±Øª Ø¨Ú©Û•Ø±Û•ÙˆÛ•. "
            "ÙˆÛ•ÚµØ§Ù…Û•Ú©Û•Øª Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ) Ø¨ÛŽØª Ùˆ Ø³ÛŽ Ø¨Û•Ø´ Ù„Û•Ø®Û† Ø¨Ú¯Ø±ÛŽØª: "
            "Ù¡- Ú©ÙˆØ±ØªÙ‡Û•ÛŒÛ•Ú©ÛŒ Ú¯Ø´ØªÛŒ (Summary)\n"
            "Ù¢- Ø®Ø§ÚµÛ• Ø³Û•Ø±Û•Ú©ÛŒ Ùˆ Ú¯Ø±Ù†Ú¯Û•Ú©Ø§Ù† (Key Points) ÙˆÛ•Ú© Ù„ÛŒØ³ØªÛŒ Ø®Ø§ÚµØ¨Û•Ù†Ø¯ÛŒ\n"
            "Ù£- ÙˆÛ•Ø±Ú¯ÛŽÚ•Ø§Ù†ÛŒ Ú¯Ø±Ù†Ú¯ØªØ±ÛŒÙ† Ù¾Ø§Ø±Ú†Û•ÛŒ Ø¯Û•Ù‚Û•Ú©Û• Ø¨Û† Ú©ÙˆØ±Ø¯ÛŒ (Translation)\n\n"
            "Ø¯Û•Ù‚Û•Ú©Û•:\n$pdfContent";
        
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
  Future<QuizModel> generateQuiz(String topic, String courseName) async {
    return _generateMockQuiz(topic, courseName);
  }

  @override
  Future<QuizModel> generateQuizFromText(String fileText, String courseName) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (hasRealApiKey) {
      try {
        final prompt = "Ø¦Û•Ù… Ø¯Û•Ù‚Û•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• Ø¨Ø®ÙˆÛŽÙ†Û•Ø±Û•ÙˆÛ• Ùˆ Ú©ÙˆÛŒØ²ÛŽÚ©ÛŒ ØªØ§Ù‚ÛŒÚ©Ø§Ø±ÛŒ Ù„Û•Ø³Û•Ø± Ø¯Ø±ÙˆØ³Øª Ø¨Ú©Û• Ø¨Û• Ø²Ù…Ø§Ù†ÛŒ Ú©ÙˆØ±Ø¯ÛŒ (Ø³Û†Ø±Ø§Ù†ÛŒ). "
            "Ú©ÙˆÛŒØ²Û•Ú©Û• Ù¾ÛŽÙˆÛŒØ³ØªÛ• Ù£ Ù¾Ø±Ø³ÛŒØ§Ø± Ù„Û•Ø®Û† Ø¨Ú¯Ø±ÛŽØª: "
            "Ù¡- ÛŒÛ•Ú©Û•Ù… Ù¾Ø±Ø³ÛŒØ§Ø± Ù‡Û•ÚµØ¨Ú˜Ø§Ø±Ø¯Û•ÛŒÛŒ (multipleChoice) Ù„Û•Ú¯Û•Úµ Ù¤ Ø¨Ú˜Ø§Ø±Ø¯Û•. "
            "Ù¢- Ø¯ÙˆÙˆÛ•Ù… Ù¾Ø±Ø³ÛŒØ§Ø± Ú•Ø§Ø³Øª ÛŒØ§Ù† Ù‡Û•ÚµÛ• (trueFalse). "
            "Ù£- Ø³ÛŽÛŒÛ•Ù… Ù¾Ø±Ø³ÛŒØ§Ø± Ù¾Ú•Ú©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø¨Û†Ø´Ø§ÛŒÛŒ (fillInBlank). "
            "ØªÚ©Ø§ÛŒÛ• ÙˆÛ•ÚµØ§Ù…Û•Ú©Û• ØªÛ•Ù†Ù‡Ø§ ÙˆÛ•Ú© ÙÛ†Ø±Ù…Ø§ØªÛŒ JSON Ú•ÙˆÙˆÙ† Ø¨Ù†ÙˆÙˆØ³Û• Ø¨Û•Ù… Ø´ÛŽÙˆØ§Ø²Û•ÛŒ Ø®ÙˆØ§Ø±Û•ÙˆÛ• (Ø¨Û•Ø¨ÛŽ Ù†ÙˆÙˆØ³ÛŒÙ†ÛŒ ØªØ±): \n"
            "{\n"
            "  \"title\": \"ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø®ÛŽØ±Ø§ Ù„Û•Ø³Û•Ø± ÙˆØ§Ù†Û•Ú©Û•\",\n"
            "  \"questions\": [\n"
            "     { \"questionText\": \"Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ ÛŒÛ•Ú©Û•Ù… Ù„ÛŽØ±Û•\", \"type\": \"multipleChoice\", \"options\": [\"Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ Ù¡\", \"Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ Ù¢\", \"Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ Ù£\", \"Ø¨Ú˜Ø§Ø±Ø¯Û•ÛŒ Ù¤\"], \"correctAnswer\": \"ÙˆÛ•ÚµØ§Ù…ÛŒ Ú•Ø§Ø³Øª Ù„ÛŽØ±Û• Ú©Û• Ù‡Ø§ÙˆØ´ÛŽÙˆÛ•ÛŒ ÛŒÛ•Ú©ÛŽÚ© Ù„Û• Ø¨Ú˜Ø§Ø±Ø¯Û•Ú©Ø§Ù†Û•\" },\n"
            "     { \"questionText\": \"Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ Ø¯ÙˆÙˆÛ•Ù… Ù„ÛŽØ±Û•\", \"type\": \"trueFalse\", \"correctAnswer\": \"Ú•Ø§Ø³ØªÛ•\" },\n"
            "     { \"questionText\": \"Ù¾Ø±Ø³ÛŒØ§Ø±ÛŒ Ø³ÛŽÛŒÛ•Ù… Ù„ÛŽØ±Û• Ø¨Û• Ø´ÛŽÙˆØ§Ø²ÛŒ Ø¨Û†Ø´Ø§ÛŒÛŒ\", \"type\": \"fillInBlank\", \"correctAnswer\": \"ÙˆÛ•ÚµØ§Ù…Û•Ú©Û•\" }\n"
            "  ]\n"
            "}\n\n"
            "Ø¯Û•Ù‚Û•Ú©Û•:\n$fileText";
        
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
        
        final Map<String, dynamic> data = jsonDecode(jsonText);
        final List<QuestionModel> questions = [];
        
        for (var q in (data['questions'] as List)) {
          questions.add(QuestionModel(
            id: 'q_${Random().nextInt(100000)}',
            questionText: q['questionText'] ?? '',
            type: q['type'] == 'trueFalse' 
                ? QuestionType.trueFalse 
                : q['type'] == 'fillInBlank' 
                    ? QuestionType.fillInBlank 
                    : QuestionType.multipleChoice,
            options: q['options'] != null ? List<String>.from(q['options']) : null,
            correctAnswer: q['correctAnswer'] ?? '',
          ));
        }
        
        return QuizModel(
          id: 'quiz_${Random().nextInt(10000)}',
          title: data['title'] ?? 'Ú©ÙˆÛŒØ²ÛŒ Ù†ÙˆÛŽ Ø¨Û• AI',
          courseName: courseName,
          questions: questions,
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          return _generateMockQuiz("ðŸ“¡ (Ú©ÙˆÛŒØ²ÛŒ Ø¦Û†ÙÙ„Ø§ÛŒÙ†) - ØªÛ†Ú• Ø¨Û•Ø±Ø¯Û•Ø³Øª Ù†ÛŒÛŒÛ•", courseName);
        }
        return _generateMockQuiz("ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø®ÛŽØ±Ø§ (Fallback)", courseName);
      }
    }

    return _generateMockQuiz("Ú©ÙˆÛŒØ²ÛŒ Ø¯Û•Ù‚ÛŒ Ø¨Ø§Ø±Ú©Ø±Ø§Ùˆ", courseName);
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
    await Future.delayed(const Duration(milliseconds: 1000));
    
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
        return data.map((item) => FlashcardModel(
          id: 'card_${Random().nextInt(100000)}',
          front: item['front'] ?? '',
          back: item['back'] ?? '',
        )).toList();
      } catch (e) {
        if (_isNetworkError(e)) {
          return _getMockFlashcards("ðŸ“¡ (Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ• Ù†ÛŒÛŒÛ•) - $topicOrText");
        }
        return _getMockFlashcards(topicOrText);
      }
    }
    
    return _getMockFlashcards(topicOrText);
  }

  List<FlashcardModel> _getMockFlashcards(String topic) {
    return [
      FlashcardModel(
        id: 'c1',
        front: 'Ù…Û†Ø¯ÛŽÙ„ÛŒ OSI Ú†ÛŒÛŒÛ•ØŸ',
        back: 'Ú•ÛŽÚ©Ø®Ø±Ø§ÙˆÛŽÚ©Û• Ø¨Û† Ù„ÛŽÚ©ØªÛŽÚ¯Û•ÛŒØ´ØªÙ†ÛŒ Ù¾Ø±Û†ØªÛ†Ú©Û†Ù„Û•Ú©Ø§Ù†ÛŒ ØªÛ†Ú• Ù„Û• Ù§ Ú†ÛŒÙ†ÛŒ Ø¬ÛŒØ§ÙˆØ§Ø²Ø¯Ø§.',
      ),
      FlashcardModel(
        id: 'c2',
        front: 'Ú©Ø§Ø±Ú©Ø±Ø¯Ù†ÛŒ CPU Ú†ÛŒÛŒÛ•ØŸ',
        back: 'Ø¦Ø§Ù…ÛŽØ±ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ø¬ÛŽØ¨Û•Ø¬ÛŽÚ©Ø±Ø¯Ù†ÛŒ ÙÛ•Ø±Ù…Ø§Ù†Û•Ú©Ø§Ù† Ùˆ Ù¾Ø±Û†Ø³ÛŽØ³Û•Ú©Ø±Ø¯Ù†ÛŒ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ•Ú©Ø§Ù† Ù„Û• Ú©Û†Ù…Ù¾ÛŒÙˆØªÛ•Ø±Ø¯Ø§.',
      ),
      FlashcardModel(
        id: 'c3',
        front: 'Ù…Û•Ø¨Û•Ø³Øª Ù„Û• Deadlock Ú†ÛŒÛŒÛ• Ù„Û• Ø³ÛŒØ³ØªÛ•Ù…ÛŒ Ú©Ø§Ø±Ù¾ÛŽÚ©Ø±Ø¯Ù†Ø¯Ø§ØŸ',
        back: 'Ú©Ø§ØªÛŽÚ© Ø¯ÙˆÙˆ Ù¾Ú•Û†Ø³Ø³ ÛŒØ§Ù† Ø²ÛŒØ§ØªØ± Ú†Ø§ÙˆÛ•Ú•ÙˆØ§Ù†ÛŒ ÛŒÛ•Ú©Ø¯ÛŒ Ø¯Û•Ú©Û•Ù† Ø¨Û† Ø¦Ø§Ø²Ø§Ø¯Ú©Ø±Ø¯Ù†ÛŒ Ø³Û•Ø±Ú†Ø§ÙˆÛ•ÛŒÛ•Ú©ØŒ Ùˆ Ù‡Û•Ù…ÙˆÙˆ Ø¯Û•ÙˆÛ•Ø³ØªÙ†.',
      ),
      FlashcardModel(
        id: 'c4',
        front: 'Ø³ÛŒØ³ØªÛ•Ù…ÛŒ ÙØ§ÛŒÙ„ (File System) Ú†ÛŒÛŒÛ•ØŸ',
        back: 'Ø´ÛŽÙˆØ§Ø²ÛŒ Ú•ÛŽÚ©Ø®Ø³ØªÙ† Ùˆ Ù‡Û•ÚµÚ¯Ø±ØªÙ†ÛŒ ÙØ§ÛŒÙ„ Ùˆ Ø²Ø§Ù†ÛŒØ§Ø±ÛŒÛŒÛ•Ú©Ø§Ù† Ù„Û•Ø³Û•Ø± Ø¯ÛŒØ³Ú©ÛŒ Ù¾Ø§Ø´Û•Ú©Û•ÙˆØªÚ©Ø±Ø¯Ù†.',
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

  // Mock quiz fallback generator
  QuizModel _generateMockQuiz(String topic, String courseName) {
    final List<QuestionModel> questions = [
      QuestionModel(
        id: 'q_n1',
        questionText: 'Ø¦Û•Ø±Ú©ÛŒ Ø³Û•Ø±Û•Ú©ÛŒ Ú•Ø§ÙˆØªÛ•Ø± (Router) Ú†ÛŒÛŒÛ• Ù„Û• ØªÛ†Ú•Ø¯Ø§ØŸ',
        type: QuestionType.multipleChoice,
        options: [
          'Ø¨Û•Ø³ØªÙ†Û•ÙˆÛ•ÛŒ Ø¬Û†ÛŒÙ†ØªÛ•Ú©Ø§Ù† Ù„Û• Ù‡Û•Ù…Ø§Ù† ØªÛ†Ú•ÛŒ Ù†Ø§ÙˆØ®Û†ÛŒÛŒØ¯Ø§',
          'Ú•ÛŽÚ•Û•ÙˆÚ©Ø±Ø¯Ù† Ùˆ Ø¦Ø§Ú•Ø§Ø³ØªÛ•Ú©Ø±Ø¯Ù†ÛŒ Ø¯Ø§ØªØ§ Ù„Û• Ù†ÛŽÙˆØ§Ù† ØªÛ†Ú•Û• Ø¬ÛŒØ§ÙˆØ§Ø²Û•Ú©Ø§Ù†Ø¯Ø§',
          'Ù¾Ø§Ø±Ø§Ø³ØªÙ†ÛŒ Ú©Û†Ù…Ù¾ÛŒÙˆØªÛ•Ø± Ù„Û• Ú¤Ø§ÛŒØ±Û†Ø³',
          'Ø¯Ø§Ø¨ÛŒÙ†Ú©Ø±Ø¯Ù†ÛŒ ÙˆØ²Û•ÛŒ Ú©Ø§Ø±Û•Ø¨Ø§ Ø¨Û† Ø¦Ø§Ù…ÛŽØ±Û•Ú©Ø§Ù†'
        ],
        correctAnswer: 'Ú•ÛŽÚ•Û•ÙˆÚ©Ø±Ø¯Ù† Ùˆ Ø¦Ø§Ú•Ø§Ø³ØªÛ•Ú©Ø±Ø¯Ù†ÛŒ Ø¯Ø§ØªØ§ Ù„Û• Ù†ÛŽÙˆØ§Ù† ØªÛ†Ú•Û• Ø¬ÛŒØ§ÙˆØ§Ø²Û•Ú©Ø§Ù†Ø¯Ø§',
      ),
      QuestionModel(
        id: 'q_n2',
        questionText: 'Ù…Û†Ø¯ÛŽÙ„ÛŒ OSI Ù„Û• Ù§ Ú†ÛŒÙ† Ù¾ÛŽÚ©Ù‡Ø§ØªÙˆÙˆÛ•.',
        type: QuestionType.trueFalse,
        correctAnswer: 'Ú•Ø§Ø³ØªÛ•',
      ),
      QuestionModel(
        id: 'q_n3',
        questionText: 'Ù¾Ú•Û†ØªÛ†Ú©Û†Ù„ÛŒ... Ú©Û• Ø¨Û† Ú©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ù…Ø§ÚµÙ¾Û•Ú•Û•Ú©Ø§Ù† Ø¨Û•Ú©Ø§Ø±Ø¯ÛŽØª Ù†Ø§ÙˆÛŒ Ú†ÛŒÛŒÛ•ØŸ',
        type: QuestionType.fillInBlank,
        correctAnswer: 'HTTPS',
      )
    ];

    return QuizModel(
      id: 'quiz_${Random().nextInt(10000)}',
      title: 'ØªØ§Ù‚ÛŒÚ©Ø±Ø¯Ù†Û•ÙˆÛ•ÛŒ Ø®ÛŽØ±Ø§: $topic',
      courseName: courseName,
      questions: questions,
      durationMinutes: 10,
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
}
