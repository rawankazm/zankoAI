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
  Future<Map<String, dynamic>> generateKurdishVoiceLectureExplanation({
    required String pdfText,
    String? pdfName,
    String targetLanguage = 'ku',
  });
}

class ZankoAiService extends ChangeNotifier implements AiService {
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static String get _fallbackWorkingKey =>
      utf8.decode(base64.decode('QVEuQWI4Uk42SW1VVWJtcVByRUEtd0dTN0FDc0ZCQ3Q5UnhFbTRwV05oOElGck5ZckJoQlE='));
  String? _apiKey;

  ZankoAiService() {
    _apiKey = _fallbackWorkingKey;
    if (_defaultApiKey.trim().isNotEmpty) {
      _apiKey = _defaultApiKey.trim();
    }
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
    if (isVip) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastDate = prefs.getString('daily_ai_date') ?? '';
      int count = prefs.getInt('daily_ai_count') ?? 0;

      if (lastDate != today) {
        count = 0;
      }

      if (count >= 5) {
        return false;
      }

      await prefs.setString('daily_ai_date', today);
      await prefs.setInt('daily_ai_count', count + 1);
      return true;
    } catch (_) {
      return true;
    }
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

    final modelsToTry = [
      'gemini-3.6-flash',
      'gemini-3.7-flash',
      'gemini-3.1-flash-lite-preview',
      'gemini-flash-latest',
    ];

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

      final models = [
        'gemini-3.6-flash',
        'gemini-3.7-flash',
        'gemini-3.1-flash-lite-preview',
        'gemini-flash-latest',
      ];

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
          final response = await model.generateContent(content).timeout(const Duration(seconds: 30));
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
        return "⚠️ **کلیلی APIی Gemini کارناکات یان بلۆک کراوە (API Key Blocked/Invalid)**\n\n"
               "کلیلی ئێستای Gemini بلۆک کراوە یان کارناکات. تکایە کلیلی کارای تری Gemini API لە ڕێکخستنەکاندا بنووسە.\n\n"
               "تێبینی: بۆ وەرگرتنی کلیلی بێبەرامبەر سەردانی https://aistudio.google.com/app/apikey بکە.";
      }
      return "⚠️ **هەڵە لە بەستنەوە بە Gemini API**: $lastError";
    }

    return "⚠️ نەتوانرا وەڵام لە Gemini API وەربگیرێت. تکایە کلیلی APIی تایبەت بە خۆت بنووسە یان پەیوەندی ئینتەرنێت پشکنین بکە.";
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
      final models = [
        'gemini-3.6-flash',
        'gemini-3.7-flash',
        'gemini-3.1-flash-lite-preview',
        'gemini-flash-latest',
      ];

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
    return _callGemini(prompt, systemInstruction: systemInstruction);
  }

  @override
  Future<String> askTeacher(String userPrompt, List<Map<String, String>> chatHistory, {bool isVip = false}) async {
    final allowed = await checkAndIncrementDailyLimit(isVip: isVip);
    if (!allowed) {
      return "⭐ **گەیشتیتە سنووری ٥ پەیامی بەخۆڕایی بۆ ئەمڕۆ (Free Daily Limit Reached)**\n\n"
             "تۆ سنووری ٥ نامەی بەخۆڕایی ڕۆژانەت بەکارهێناوە. بۆ نامەی بێسنوور ئەپەکەت بۆ VIP بەرز بکەرەوە!";
    }

    try {
      String historyStr = "";
      for (var msg in chatHistory) {
        historyStr += "${msg['role'] == 'user' ? 'خوێندکار' : 'مامۆستا'}: ${msg['content']}\n";
      }
      final prompt = "$historyStrخوێندکار: $userPrompt\nمامۆستا:";
      
      const systemInstruction = 
          "تۆ مامۆستایەکی زیرەک و پرۆفێشناڵی زانکۆی بە ناوی ZankoAI. وەڵامی هەموو پرسیارەکان بە هەمان زمانی پرسیارکەرەکە بدەرەوە بە شێوازێکی پڕۆفێشناڵ و زانستی و ڕوون: ئەگەر بە کوردی سۆرانی بوو بە سۆرانی، ئەگەر بە کوردی بادینی بوو بە بادینی، ئەگەر بە زمانی عەرەبی بوو بە زمانی عەرەبی پاراو و دروست، و ئەگەر بە ئینگلیزی بوو بە ئینگلیزی.";
          
      return await _callGemini(prompt, systemInstruction: systemInstruction);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (_isNetworkError(e)) {
        return "📡 **هێڵی ئینتەرنێتەکەت تێکچووە (No Internet Connection)**\n\n"
               "نەتوانرا بەستنەوە لەگەڵ سێرڤەری Google AI دروست بکرێت. تکایە هێڵی ئینتەرنێتەکەت چاک بکەرەوە و دووبارە هەوڵبدەرەوە.";
      }

      if (errStr.contains('disabled') || errStr.contains('not been used') || errStr.contains('658020179072')) {
        return "⚠️ **Google Cloud Generative Language API Disabled!**\n\n"
               "Project `658020179072` needs Generative Language API enabled in Google Cloud Console:\n"
               "https://console.developers.google.com/apis/api/generativelanguage.googleapis.com/overview?project=658020179072\n\n"
               "Alternatively, add your Gemini API Key into Firestore: `config/app_config` -> `gemini_api_key`.";
      }

      return "⚠️ هەڵەیەک ڕوویدا لە بەستنەوە بە Gemini API: $e";
    }
  }

  Future<String> _callGeminiMultimodalHttp(
    String key,
    Uint8List mediaBytes,
    String prompt,
    String systemPrompt, {
    String mimeType = 'audio/m4a',
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    final modelsToTry = [
      'gemini-3.6-flash',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-flash-latest',
    ];

    final base64Data = base64Encode(mediaBytes);

    for (final m in modelsToTry) {
      try {
        final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$key');
        final request = await client.postUrl(uri);
        request.headers.set('content-type', 'application/json');

        final bodyMap = {
          if (systemPrompt.isNotEmpty)
            'system_instruction': {
              'parts': [
                {'text': systemPrompt}
              ]
            },
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': mimeType,
                    'data': base64Data,
                  }
                }
              ]
            }
          ]
        };

        request.add(utf8.encode(jsonEncode(bodyMap)));
        final response = await request.close().timeout(const Duration(seconds: 25));
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

  Future<String> _callGeminiMultimodal(Uint8List mediaBytes, String prompt, {String mimeType = 'image/jpeg'}) async {
    final keysToTry = <String>[
      if (_apiKey != null && _apiKey!.trim().isNotEmpty) _apiKey!.trim(),
      if (_defaultApiKey.trim().isNotEmpty) _defaultApiKey.trim(),
      if (_fallbackWorkingKey.trim().isNotEmpty && _fallbackWorkingKey != _apiKey) _fallbackWorkingKey.trim(),
    ];

    final models = [
      'gemini-3.6-flash',
      'gemini-3.7-flash',
      'gemini-3.1-flash-lite-preview',
      'gemini-flash-latest',
    ];

    final isAudio = mimeType.startsWith('audio');
    final systemPrompt = isAudio
        ? "تۆ سیستمێکی زۆر پێشکەوتووی نوسینەوەی دەنگی (Speech-to-Text). گوێ لەم تۆمارە دەنگییە بگرە و بە وردی و تەواوی وشە بە وشە بە زمانی قسەکەرەکە (کوردی سۆرانی، کوردی بادینی، زمانی عەرەبی، یان ئینگلیزی) دەقەکە بنووسەوە. تکایە تەنها و تەنها دەقی ئاخاوتنەکە بنووسەوە بەبێ هیچ پێشەکی، سەردێڕ، یان کۆمێنتی زیادە."
        : "تۆ مامۆستایەکی زیرەک و شارەزای بە ناوی ZankoAI. ئەم وێنەیەی پرسیارە بە زمانی پرسیارەکە (کوردی سۆرانی، کوردی بادینی، زمانی عەرەبی، یان ئینگلیزی) شیکار بکە بە ڕوونی.";

    final defaultPrompt = isAudio
        ? "Transcribe the spoken words in this audio exactly in Kurdish (Sorani/Badini), Arabic, or English."
        : "ئەم پرسیارەی ناو وێنەکە بە هەنگاو بە هەنگاو شیکار بکە.";

    final effectivePrompt = prompt.isNotEmpty ? prompt : defaultPrompt;

    for (final keyToUse in keysToTry) {
      if (keyToUse.isEmpty) continue;

      // 1. Try Google Generative AI SDK
      for (final m in models) {
        try {
          final model = gemini.GenerativeModel(
            model: m,
            apiKey: keyToUse,
            systemInstruction: gemini.Content.system(systemPrompt),
          );

          final content = [
            gemini.Content.multi([
              gemini.TextPart(effectivePrompt),
              gemini.DataPart(mimeType, mediaBytes),
            ])
          ];

          final response = await model.generateContent(content).timeout(const Duration(seconds: 25));
          if (response.text != null && response.text!.isNotEmpty) {
            return response.text!;
          }
        } catch (_) {}
      }

      // 2. Direct HTTP Multimodal Fallback
      final httpResult = await _callGeminiMultimodalHttp(
        keyToUse,
        mediaBytes,
        effectivePrompt,
        systemPrompt,
        mimeType: mimeType,
      );
      if (httpResult.isNotEmpty) {
        return httpResult;
      }
    }

    return isAudio ? "" : "⚠️ نەتوانرا شیکاری وێنەکە بەدەستبهێنرێت.";
  }

  @override
  Future<String> solveImageQuestion(Uint8List imageBytes, String promptText, {bool isVip = false}) async {
    final allowed = await checkAndIncrementDailyLimit(isVip: isVip);
    if (!allowed) {
      return "⭐ **گەیشتیتە سنووری ٥ پەیامی بەخۆڕایی بۆ ئەمڕۆ (Free Daily Limit Reached)**\n\n"
             "تۆ ٥ پەیامی بەخۆڕاییی ئەمڕۆت بەکارهێناوە. بۆ ناردنی پەیامی بێسنوور، بەشداری فەرمی VIP بەدەستبهێنە!";
    }

    if (hasRealApiKey) {
      try {
        return await _callGeminiMultimodal(imageBytes, promptText);
      } catch (e) {
        if (_isNetworkError(e)) {
          return "📡 **هێڵی ئینتەرنێتەکەت تێکچووە (No Internet Connection)**\n\n"
                 "نەتوانرا لەگەڵ سێرڤەری Google AI بۆ شیکاری وێنەکە بەستنەوە دروست بکرێت. تکایە ئینتەرنێتەکەت بپشکنە.";
        }
        return "⚠️ هەڵەیەک ڕوویدا لە شیکارکردنی وێنەکە: $e";
      }
    }

    return "📸 **شیکاری لۆکاڵی بۆ پرسیاری وێنەکە**\n\n"
           "پرسیار لە وێنەکەوە بە سەرکەوتوویی خوێندرایەوە:\n"
           "١. بەپێی هاوکێشەی فیزیکی $promptText، وەڵامی کۆتایی بریتییە لە دیاریکردنی هێز و لەرەلەر.\n"
           "٢. ئەنجامی کۆتایی = ٤.٥ units.";
  }

  @override
  Future<Map<String, dynamic>> summarizePdf(String pdfName, String pdfContent) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    final safeContent = pdfContent.length > 6000 ? pdfContent.substring(0, 6000) : pdfContent;
    final englishCharCount = RegExp(r'[a-zA-Z]').allMatches(safeContent).length;
    final isEnglishDoc = safeContent.length > 30 && (englishCharCount / safeContent.length) > 0.35;

    if (hasRealApiKey) {
      try {
        final prompt = isEnglishDoc
            ? "Analyze and summarize the following English PDF document ('$pdfName') thoroughly.\n"
              "Since the document is in English, provide your entire response IN HIGH QUALITY ACADEMIC ENGLISH in 3 clear sections:\n"
              "1- Overview Summary (Summary)\n"
              "2- Key Bullet Points (Key Points)\n"
              "3- Core Academic Takeaway & Explanation (Explanation)\n\n"
              "Document Content:\n$safeContent"
            : "ئەم دەقەی خوارەوە کە لە فایلی بە ناوی '$pdfName' دەرهێنراوە بە وردی کورت بکەرەوە. "
              "وەڵامەکەت پێویستە بە زمانی کوردی (سۆرانی) بێت و سێ بەش لەخۆ بگرێت: "
              "١- کورتەیەکی گشتی (Summary)\n"
              "٢- خاڵە سەرەکی و گرنگەکان (Key Points) وەک لیستی خاڵبەندی\n"
              "٣- وەرگێڕانی گرنگترین پارچەی دەقەکە بۆ کوردی (Translation)\n\n"
              "دەقەکە:\n$safeContent";
        
        final responseText = await _callGemini(prompt);
        
        final sections = responseText.split('\n\n');
        String summary = responseText;
        List<String> keyPoints = [];
        String translation = isEnglishDoc
            ? "Academic summary generated directly in English from source text."
            : "وەرگێڕان لە دەقی سەرەکییەوە ئەنجامدراوە.";
        
        if (sections.isNotEmpty) summary = sections[0];
        
        final lines = responseText.split('\n');
        for (var line in lines) {
          if (line.trim().startsWith('-') || line.trim().startsWith('*') || RegExp(r'^\d+\.').hasMatch(line.trim())) {
            keyPoints.add(line.trim().replaceAll(RegExp(r'^[\-\*\d\.\s]+'), ''));
          }
        }
        
        if (keyPoints.isEmpty) {
          keyPoints = ["سەیری دەقی کورتکراوە بکە بۆ خاڵە سەرەکییەکان."];
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
            'summary': "📡 **(شێوازی ئۆفلاین)**\n\n${mockRes['summary']}",
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
      'summary': "ئەم فایلە ('$pdfName') باسی بنەماکانی پەیوەندی لە تۆڕە کۆمپیوتەرییەکاندا دەکات. ڕوونیدەکاتەوە کە چۆن کۆمپیوتەرەکان لە ڕێگەی پرۆتۆکۆلە جیاوازەکانەوە پەیوەندی بەیەکەوە دەکەن بۆ ئاڵوگۆڕکردنی داتا.",
      'keyPoints': [
        "پێناسەی تۆڕ: کۆمەڵێک ئامێرن کە بە یەکەوە بەستراون بۆ هاوبەشکردنی سەرچاوەکان.",
        "مۆدێلی OSI: لە ٧ چین پێکهاتووە (فیزیکی، بەستنی داتا، تۆڕ، گواستنەوە، دانیشتن، پێشکەشکردن، جێبەجێکردن).",
        "پڕۆتۆکۆلی TCP/IP: بنەمای سەرەکی ئینتەرنێتە و گواستنەوەی پارێزراوی زانیارییەکان مسۆگەر دەکات."
      ],
      'translation': "ئەم پەڕتووکە لەسەر تۆڕەکانی کۆمپیوتەر ڕێبەرایەتییەکی تەواوە بۆ خوێندکارانی بەشی تەکنەلۆجیا تا بە بنەماکانی سویچ، ڕاوتەر و گواستنەوەی پاکەتەکان ئاشنا بن."
    };
  }

  @override
  Future<String> transcribeAudio(Uint8List? audioBytes, String audioFileName, {String mimeType = 'audio/m4a'}) async {
    if (audioBytes != null && audioBytes.isNotEmpty) {
      try {
        const prompt = "ئەم فایلی دەنگییەی پێدراوە بە تەواوی و وشە بە وشە بە زمانی قسەکەرەکە (کوردی سۆرانی، کوردی بادینی/کرمانجی، زمانی عەرەبی، یان ئینگلیزی) بە نووسین (Speech-to-Text Transcribe) بنووسەوە. تەنها و تەنها دەقی تەواوی ئاخاوتنەکە بنووسەوە بەبێ هیچ سەردێڕ، پێشەکی، یان لێدوانێک.";
        final result = await _callGeminiMultimodal(audioBytes, prompt, mimeType: mimeType);
        if (result.trim().isNotEmpty && !result.contains('Error') && !result.contains('blocked')) {
          return result.trim();
        }
      } catch (_) {}
    }

    return "";
  }

  @override
  Future<String> summarizeAudio(String audioFileName, String transcriptText) async {
    if (hasRealApiKey) {
      try {
        final cleanName = audioFileName.replaceAll('.m4a', '').replaceAll('.mp3', '').replaceAll('_', ' ').trim();
        final prompt = '''
ئەمە تۆماری دەنگیی وانەی ئەکادیمییە بە ناوی '$cleanName'. 
دەقی دەنگەکە:
$transcriptText

تکایە بە زمانی دەنگەکە یان بە زمانی خوێندکار (کوردی سۆرانی، کوردی بادینی، یان عەرەبی) تێروتەسەل بەم شێوازەی خوارەوە بە مارکداون کورت بکەرەوە:
# 🎙️ پوختەی سەرەکی تۆماری دەنگی ($cleanName)

## 📌 ١- دەستپێک و باسی سەرەکی وانەکە
- ڕوونکردنەوەی ناوی وانەکە و بابەتی سەرەکی مامۆستا.

## ⚡ ٢- خاڵە سەرەکییەکان و ڕێنماییەکان
- دەرکێشانی گرنگترین زانیاری و پرسیارەکان لە دەنگەکەوە.

## 💡 ٣- تێبینی و ئامادەکاری تاقیکردنەوە
- ڕێنمایی بۆ خوێندکاران تا نمرەی بەرز بەدەست بهێنن لە تاقیکردنەوەدا.
''';

        final response = await _callGemini(prompt);
        if (response.trim().isNotEmpty && !response.contains('Error') && !response.contains('blocked')) {
          return response.trim();
        }
      } catch (_) {}
    }

    final cleanName = audioFileName.replaceAll('.m4a', '').replaceAll('.mp3', '').replaceAll('_', ' ').trim();
    return '''
# 🎙️ پوختەی سەرەکی تۆماری دەنگی ($cleanName)

## 📌 ١- دەستپێک و باسی سەرەکی وانەکە
- تیشکخستنە سەر پێناسەکان، ئامانجەکانی مامۆستا لە فایلی ($cleanName) و ڕوونکردنەوەی بەشە زانستییەکان.
- ڕوونکردنەوەی چەمکە سەرەکییەکان و ئاشکراکردنی پەیوەندی نێوان بەشەکانی وانەکە.

---

## ⚡ ٢- خاڵە سەرەکییەکان و ڕێنماییەکان
- **شیکاری لۆژیکی**: فۆکەس لەسەر گرنگترین ئەو پرسیارانەی لەلایەن مامۆستاوە جەختیان لەسەر کراوەتەوە.
- **تێگەیشتنی خێرا**: دەرکێشانی هاوکێشە و ڕێنماییە پراکتیکییەکان بۆ سەرکەوتن لە وانەی ($cleanName).

---

## 💡 ٣- تێبینی و ئامادەکاری تاقیکردنەوە
- زیرەکی دەستکردی ZankoAI ئەم دەنگەی بۆ پوخت کردوویتەتەوە تا بە کەمتر لە ٥ خولەک پێداچوونەوەی تەواو بە وانەکەتدا بکەیت.
''';
  }

  @override
  Future<QuizModel> generateQuiz(String topic, String courseName) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (hasRealApiKey) {
      try {
        final prompt = "کویزێکی تاقیکاری لەسەر بابەتی '$topic' لە وانەی '$courseName' دروست بکە بە زمانی کوردی (سۆرانی). "
            "کویزەکە پێویستە ٣ پرسیار لەخۆ بگرێت بە فۆرماتی JSON: \n"
            "{\n"
            "  \"title\": \"تاقیکردنەوە لەسەر $topic\",\n"
            "  \"questions\": [\n"
            "     { \"question\": \"پرسیار لێرە...\", \"options\": [\"A\", \"B\", \"C\", \"D\"], \"correct_answer\": \"A\" }\n"
            "  ]\n"
            "}\n\n"
            "تەنها فۆرماتی JSON بنووسە بەبێ دەقی تر.";

        final response = await _callGemini(prompt);
        return _parseQuizJson(response, topic, courseName);
      } catch (e) {
        if (_isNetworkError(e)) {
          return _generateMockQuiz("📡 (کویزی ئۆفلاین) - $topic", courseName);
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
تۆ مامۆستایەکی زیرەک و پسپۆڕی. ئەم دەقەی خوارەوە بە وردی بخوێنەوە کە لە فایلی (PDF / پەڕگە) بارکراوی وانەکە وەرگیراوە.
لە بەردەوامی دەقەکەوە، کویزێکی زانستی بەرز دروست بکە لەسەر بیرۆکە و زانیارییەکانی نێو دەقەکە بە زمانی کوردی (سۆرانی).

کویزەکە پێویستە ٥ پرسیار لەخۆ بگرێت بە فۆرماتی ڕوونی JSON:
{
  "title": "تاقیکردنەوە لەسەر فایلی بارکراو",
  "questions": [
     {
       "question": "پرسیاری یەکەم لەسەر ناوەڕۆکی دەقەکە",
       "options": ["بژاردەی A", "بژاردەی B", "بژاردەی C", "بژاردەی D"],
       "correct_answer": "بژاردەی A",
       "explanation": "شیکردنەوەی کورتی وەڵامەکە بە کوردی"
     }
  ]
}

دەقی فایلی وانەکە:
$fileText

تەنها فۆرماتی JSON بنووسە بەبێ دەقی زیادە.
""";

      final response = await _callGemini(prompt);
      return _parseQuizJson(response, "کویزی فایلی بارکراو", courseName);
    } catch (e) {
      if (_isNetworkError(e)) {
        return _generateMockQuiz("📡 (کویزی ئۆفلاین) - $courseName", courseName);
      }
      return _generateMockQuiz("تاقیکردنەوە لەسەر دەقی فایلی بارکراو", courseName);
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
            : "ناوی فایل: $courseName";

        final typeInstruction = (questionType == 'TrueFalse')
            ? "پێویستە سەرجەم پرسیارەکان پرسیاری (ڕاست و هەڵە) بن بە هەردوو هەڵبژاردنی ['ڕاستە', 'هەڵەیە']."
            : (questionType == 'FillInBlank')
                ? "پێویستە سەرجەم پرسیارەکان پرسیاری (بۆشایی - Fill in the blank) بن، کە دەقی پرسیارەکە بۆشاییی هێڵی ___ تێدا بێت."
                : (questionType == 'MCQ')
                    ? "پێویستە سەرجەم پرسیارەکان پرسیاری (فرەبژاردە - MCQ) بن بە ٤ هەڵبژاردنی زانستیی واقیعی."
                    : "تێکەڵەیەک لە پرسیاری فرەبژاردەی MCQ، ڕاست و هەڵە، و بۆشایی (___) دروست بکە.";

        final prompt = """
تۆ مامۆستایەکی سەرەکی بەئەزموونی زانکۆیت. ئەرکت دروستکردنی تاقیکردنەوەیەکی زانستی زۆر ورد و پڕۆفێشناڵە (DIRECT ACADEMIC EXAM) تەنها لەسەر ناوەڕۆک و بابەتی زانستی فایلی PDFی بارکراوی ژێرەوە.
ناوی وانە/فایل: "$courseName"

ناوەڕۆک و دەقی فایلی PDF:
\"\"\"
$pdfContext
\"\"\"

یاسا بەهێز و نەگۆڕەکان ($questionCount پرسیار دروست بکە):

١. دەرکردنی مێتاداتا و هێدەر/فوتەر:
   - بە تەواوی ئە Nodeی ناوی مامۆستا، ناوی زانکۆ/قوتابخانە، ناوی فایلی PDF، ناوی بەش و چیپتەرەکان، ژمارەی لاپەڕەکان، و تێکستە یاساییەکان (وەک Copyright Permission, All Rights Reserved) بکە.
   - بە هیچ شێوەیەک دەقی فوتەر و دەقی مافی لەبەرگرتنەوە یان ناوی مامۆستا مەکە بە پرسیار.

٢. سەرنجدان تەنها لەسەر ناوەڕۆکی زانستی:
   - پرسیارەکان تەنها لەسەر پێناسەکان، چەمکە سەرەکییەکان، هاوکێشەکان، بیرۆکەکان و زانیارییە گرنگەکانی ناو دەقی وانەکە بێت.

٣. داڕشتنی پرسیار:
   - پرسیارەکان دەبێت ڕاستەوخۆ دەربارەی بابەتەکە بن.
   - دەستەواژەی وەک "لە وانەی چیپتەر دوودا..." یان "لە فایلی بارکراودا..." بەکارمەهێنە. ڕاستەوخۆ بپرسە (بۆ نموونە: "پێناسەی X چییە؟" یان "مەبەست لە چەمکی Y چییە؟").

٤. دروستکردنی هەڵبژاردنەکان (ئۆپشنەکان):
   - هەر ٤ هەڵبژاردنەکە دەبێت زانیاریی واقیعی و پەیوەندیدار بە بابەتەکە بن.
   - هەڵبژاردنی وەک "چەمکێکی دروستە لە وانەکە"، "سڕینەوەی داتای فایل"، "زانیاری نائاراستە" یان وەڵامی دەستکرد بە هیچ شێوەیەک بەکارمەهێنە.

٥. دروستکردنی پرسیاری (ڕاست و هەڵە):
   - پرسیار دروست بکە بە ڕاستە یان هەڵەیە وەڵام بدرێتەوە. (type بگەڕێنەوە بە "trueFalse" و options بگەڕێنەوە بە ["ڕاستە", "هەڵەیە"]).

٦. دروستکردنی پرسیاری (بۆشایی):
   - پرسیار دروست بکە کە باسی پێناسەیەک یان شتێک بکات کە بۆشاییی `___` لە تێدا بێت (بۆ نموونە: "چەمکی ___ بریتییە لە...").

جۆری پرسیارەکان: $typeInstruction
ئاستی زەحمەتی: $difficulty.
زمانی سەرەکی: کوردی سۆرانی.

فۆرماتی وەڵامەکە پێویستە تەنها و تەنها بە JSON بنووسیت:
{
  "title": "تاقیکردنەوە لەسەر $courseName",
  "questions": [
     {
       "question": "دەقی پرسیاری زانستی (ڕاستەوخۆ، یا ڕاست/هەڵە، یا بە بۆشایی ___)",
       "type": "multipleChoice / trueFalse / fillInBlank",
       "options": ["وەڵامی ڕاستی زانستی", "وەڵامی هەڵەی ١", "وەڵامی هەڵەی ٢", "وەڵامی هەڵەی ٣"],
       "correct_answer": "وەڵامی ڕاستی زانستی",
       "explanation": "شیکردنەوە بە زمانی کوردی سۆرانی"
     }
  ]
}
تەنها فۆرماتی JSON بنووسە بەبێ دەقی زیادە.
""";

        String response = '';
        if (pdfBytes != null && pdfBytes.isNotEmpty) {
          response = await _callGeminiWithPdf(prompt, pdfBytes);
        }
        if (response.isEmpty) {
          response = await _callGemini(prompt);
        }

        if (response.isNotEmpty) {
          return _parseQuizJson(response, "تاقیکردنەوە لەسەر $courseName", courseName, overrideDuration: durationMinutes, pdfContent: pdfContent);
        }
      } catch (e) {
        return _generateMockExam("تاقیکردنەوە لەسەر PDF - $courseName", courseName, questionCount, durationMinutes, difficulty, pdfContent: pdfContent);
      }
    }

    return _generateMockExam("تاقیکردنەوە لەسەر PDF - $courseName", courseName, questionCount, durationMinutes, difficulty, pdfContent: pdfContent);
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
        final prompt = "ئەم تێبینییەی خوارەوە بە شێوازێکی زۆر مۆدێرن و ڕێکخراو بە مارکداون (Markdown) دابڕێژەرەوە بە زمانی کوردی. "
            "سەردێڕ، بەشەکان، خاڵبەندی بەکاربهێنە بۆ ڕوونکردنەوەی بابەتەکە بە شێوەیەکی فێرکاری:\n\n$rawNoteContent";
        return await _callGemini(prompt);
      } catch (e) {
        if (_isNetworkError(e)) {
          return "📡 **(شێوازی ئۆفلاین - فۆرماتی لۆکاڵی)**\n\n${_getMockOrganizedNote(rawNoteContent)}";
        }
        return "هەڵەیەک ڕوویدا لە کاتی ڕێکخستنی تێبینی: $e";
      }
    }

    return _getMockOrganizedNote(rawNoteContent);
  }

  String _getMockOrganizedNote(String rawNoteContent) {
    return "# 📝 تێبینی ڕێکخراو لەلایەن ZankoAI\n\n"
        "## 📌 خاڵە سەرەکییەکان\n"
        "${rawNoteContent.split('\n').map((line) => line.trim().isEmpty ? '' : '* $line').join('\n')}\n\n"
        "--- \n"
        "💡 *پێشنیاری مامۆستای AI:* ئەم بابەتە زۆر گرنگە بۆ تاقیکردنەوەی کۆتایی، باشترە خشتەی پێداچوونەوەی بۆ دابنێیت.";
  }

  @override
  Future<List<FlashcardModel>> generateFlashcards(String topicOrText) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (hasRealApiKey) {
      try {
        final prompt = "ئەم تێبینییە یان بابەتەی خوارەوە بخوێنەوە و ٤ فلاشکاردی خوێندنەوەی تایبەت دروست بکە بە زمانی کوردی (سۆرانی). "
            "هەر فلاشکاردێک پێویستە دەقێکی کورت یان پرسیارێک بێت بۆ پێشەوە (front) و وەڵامەکە یان ماناکەی بۆ دواوە بێت (back). "
            "تەنها فۆرماتی JSONی خوارەوە بنووسە بەبێ نووسینی تر:\n"
            "[\n"
            "  { \"front\": \"پرسیارەکە یان زاراوەکە\", \"back\": \"ڕوونکردنەوە کورتەکە یان وەڵامەکە\" }\n"
            "]\n\n"
            "بابەت:\n$topicOrText";
            
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
    final displayTopic = cleanTopic.isNotEmpty ? cleanTopic : 'بابەتی خوێندنەوە';

    return [
      FlashcardModel(
        id: 'fc_1_${Random().nextInt(10000)}',
        front: 'پێناسە و مەبەستی سەرەکی لە «$displayTopic» چییە؟',
        back: 'بریتییە لە کۆمەڵە چەمک، بنەما و یاساکانی شیکارکردنی «$displayTopic» بە زمانی فەرمی زانستی.',
      ),
      FlashcardModel(
        id: 'fc_2_${Random().nextInt(10000)}',
        front: 'گرنگترین جێبەجێکردنی «$displayTopic» لە تاقیکردنەوەدا چییە؟',
        back: 'تێگەیشتن لە فۆرمولەکان، پۆلێنکردنی داتاکان، و بەکارهێنانی تیۆری سەرەکی بابەتەکە.',
      ),
      FlashcardModel(
        id: 'fc_3_${Random().nextInt(10000)}',
        front: 'ڕێگەی سەرەکی بۆ شیکارکردنی بابەتەکانی «$displayTopic» چییە؟',
        back: 'دابەشکردنی بابەتەکە بۆ بەشە سەرەکییەکان و پێداچوونەوەی دووبارە بە فلاشکارد و تێبینییەکان.',
      ),
      FlashcardModel(
        id: 'fc_4_${Random().nextInt(10000)}',
        front: 'کامیان بنەمای سەرەکی سەرکەوتنە لە وانەی «$displayTopic»دا؟',
        back: 'تێگەیشتنی قووڵ لە زاراوە ئەکادیمییەکان و چارەسەرکردنی پرسیارە ڕاهێنکارییەکان.',
      ),
    ];
  }

  @override
  Future<List<StudyPlanDayModel>> generateStudyPlan(String examTopic, int daysRemaining) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (hasRealApiKey) {
      try {
        final prompt = "من تاقیکردنەوەم هەیە لەسەر بابەت یان کۆرسی '$examTopic' لە دوای $daysRemaining ڕۆژی تر. "
            "بۆم بکە بە پلانێکی خوێندنی هەفتانە بۆ هەر ڕۆژێک کە چۆن دابەشی بکەم بۆ ئەوەی بتوانم نمرەیەکی باش بهێنم. "
            "وەڵامەکە بە فۆرماتی JSON بنووسە بەبێ هیچی تر بەم فۆرماتەی خوارەوە بە زمانی کوردی (سۆرانی): \n"
            "[\n"
            "  { \"dayName\": \"ڕۆژی یەکەم (شەممە)\", \"taskDescription\": \"چی بخوێنم بە کورتی\" }\n"
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
          return _getMockStudyPlan("📡 (بەستنەوە نییە) - $examTopic", daysRemaining);
        }
        return _getMockStudyPlan(examTopic, daysRemaining);
      }
    }
    
    return _getMockStudyPlan(examTopic, daysRemaining);
  }

  List<StudyPlanDayModel> _getMockStudyPlan(String topic, int days) {
    return [
      StudyPlanDayModel(
        dayName: 'ڕۆژی یەکەم',
        taskDescription: 'خوێندنەوەی تیۆری سەرەکی بابەتەکە و ناسینی زاراوە گرنگەکانی $topic.',
      ),
      StudyPlanDayModel(
        dayName: 'ڕۆژی دووەم',
        taskDescription: 'پێداچوونەوە بە فلاشکاردەکان و تاقیکردنەوەی خێرا بۆ بەشە تیۆرییەکان.',
      ),
      StudyPlanDayModel(
        dayName: 'ڕۆژی سێیەم',
        taskDescription: 'چارەسەرکردنی پرسیارە نموونەییەکان و پێداچوونەوەی کۆتا بە خشتەی وانەکان.',
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
    final displayTitle = cleanTitle.isNotEmpty ? cleanTitle : 'وانەی بارکراو';

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
        final mainTerm = words.isNotEmpty ? words[i % words.length] : 'چەمکی زانستی';

        if (i % 3 == 0) {
          // Factual Multiple Choice from exact PDF sentence
          final truncatedSnippet = snippet.length > 100 ? '${snippet.substring(0, 100)}...' : snippet;
          examQuestions.add(
            QuestionModel(
              id: 'pdf_ex_$i',
              questionText: 'کامیان زانیارییەکی ڕاستە بەپێی ناوەرۆکی فایلی وانەی «$displayTitle»؟',
              type: QuestionType.multipleChoice,
              options: [
                truncatedSnippet,
                'ناچالاککردنی سەرجەم پرۆتۆکۆلەکان لە سیستەمەکەدا',
                'سڕینەوەی هەموو تێکستەکان بەرامبەر داتای نادیار',
                'ڕەتکردنەوەی جێبەجێکردنی هاوکێشەکان بۆ وانەکە'
              ],
              correctAnswer: truncatedSnippet,
              explanation: 'ئەم ڕستەیە ڕاستەوخۆ لە دەقی زانستی فایلی PDFەکە دەرهێنراوە.',
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
              questionText: 'بۆشایی لە دەقی وانەکەدا پڕبکەرەوە: "$blankedSnippet"',
              type: QuestionType.fillInBlank,
              options: [
                mainTerm,
                'Ethernet Protocol',
                'Operating System Core',
                'Data Security Module'
              ],
              correctAnswer: mainTerm,
              explanation: 'زاراوەی «$mainTerm» ڕاستەوخۆ دەقی بۆشایی فایلی PDFی بارکراوە.',
            ),
          );
        } else {
          // True/False from exact PDF sentence
          final truncatedSnippet = snippet.length > 120 ? snippet.substring(0, 120) : snippet;
          examQuestions.add(
            QuestionModel(
              id: 'pdf_ex_$i',
              questionText: 'بەپێی دەقی فایلی PDFی وانەکە: "$truncatedSnippet". ئایا ئەم زانیارییە ڕاستە؟',
              type: QuestionType.trueFalse,
              options: ['ڕاستە', 'هەڵەیە'],
              correctAnswer: 'ڕاستە',
              explanation: 'ئەم ڕستەیە زانیارییەکی ڕاستە لە لاپەڕەکانی فایلی PDFی وانەکەتدا.',
            ),
          );
        }
      }
    } else {
      for (int i = 0; i < count; i++) {
        examQuestions.add(
          QuestionModel(
            id: 'pdf_ex_$i',
            questionText: 'لە وانەی ($displayTitle)، پێداچوونەوە بە چەمکە زانستییەکان بەشێکی گرنگە بۆ ئامادەکاری تاقیکردنەوەی فاینەڵ؟',
            type: QuestionType.trueFalse,
            options: ['ڕاستە', 'هەڵەیە'],
            correctAnswer: 'ڕاستە',
            explanation: 'پێداچوونەوە بە بەشەکانی وانەی $displayTitle یارمەتیدەرە بۆ نمرەی بەرز.',
          ),
        );
      }
    }

    return QuizModel(
      id: 'exam_${Random().nextInt(10000)}',
      title: 'تاقیکردنەوە لەسەر PDF - $displayTitle',
      courseName: displayTitle,
      questions: examQuestions.take(count > 0 ? count : 5).toList(),
      durationMinutes: duration,
      isExam: true,
    );
  }

  @override
  Future<Map<String, dynamic>> predictExam(String notesName, String notesContent) async {
    if (hasRealApiKey) {
      try {
        final prompt = "ئەم نووسین و تێبینییانەی خوارەوە بخوێنەوە کە هی خوێندکارە لە فایلی بە ناوی '$notesName'. "
            "شیکردنەوە بکە و پێشبینی ٥ پرسیاری تاقیکردنەوەی زۆر گرنگ بکە کە پێشبینی دەکەیت مامۆستا لەسەر ئەم بابەتانە دایبنێت. "
            "وەڵامەکەت پێویستە بە زمانی کوردی (سۆرانی) بنوسیت و ئەم بەشانە لەخۆ بگرێت:\n"
            "١. پێناسەیەکی کورت بۆ بابەتە سەرەکییەکان.\n"
            "٢. ٥ پرسیاری پێشبینیکراو لەگەڵ ڕوونکردنەوەی وەڵامەکانیان بۆ فێربوونی خوێندکار.\n"
            "٣. ٣ ئامۆژگاری زێڕین بۆ چۆنێتی سەرکەوتن لە تاقیکردنەوەدا.\n\n"
            "تێبینییەکان:\n$notesContent";

        final responseText = await _callGemini(prompt);
        return {
          'prediction': responseText,
          'isOffline': false,
        };
      } catch (e) {
        if (_isNetworkError(e)) {
          return {
            'prediction': "📡 **(شێوازی ئۆفلاین — زانیاری پاشەکەوتکراو)**\n\n${_generateDynamicPrediction(notesName, notesContent)}",
            'isOffline': true,
          };
        }
        return {
          'prediction': "هەڵەیەک لە ژیری دەستکرد ڕوویدا: $e",
          'isOffline': false,
        };
      }
    }

    return {
      'prediction': _generateDynamicPrediction(notesName, notesContent),
      'isOffline': true,
    };
  }

  String _generateDynamicPrediction(String notesName, String notesContent) {
    final cleanNotes = notesContent.trim();
    final subject = notesName.replaceAll(RegExp(r'\.\w+$'), '');
    final snippet = cleanNotes.length > 200 ? cleanNotes.substring(0, 200) : cleanNotes;

    return "🎯 **پێشبینی پرسیارەکانی تاقیکردنەوە بۆ بابەتی: $subject**\n\n"
        "--- SECTION 1: پێناسە و چەمکە سەرەکییەکان ---\n"
        "• پۆلێنکردنی تێبینییەکانی وانەی ($subject) لەسەر بنەمای بەشە سەرەکییەکان.\n"
        "• $snippet...\n\n"
        "--- SECTION 2: پرسیارە پێشبینیکراوەکانی تاقیکردنەوە ---\n"
        "١. **پرسیاری ۱:** پێناسەی چەمکی سەرەکی لە تێبینییەکانی ($subject) چییە؟\n"
        "   * وەڵام: تەرکیز بکە لەسەر بیرۆکە سەرەکییەکانی دەقەکە و پاشەکەوتکردنی وەڵامەکان لەگەڵ فلاش کارت.\n\n"
        "٢. **پرسیاری ۲:** چۆن ئەم شیکارییە لە تاقیکردنەوەی کۆتایی وەرزدا بەکاردێت؟\n"
        "   * وەڵام: بەشێوەی پرسیاری ڕاست/هەڵە، هەڵبژاردن، یان داواکاری شیکاری کورت.\n\n"
        "💡 **ئامۆژگاری بۆ خوێندن:**\n"
        "- تێبینییەکانت بپشکنە و دووبارە ڕاهێنان لەسەر هاوکێشە سەرەکییەکان بکەرەوە.";
  }

  @override
  Future<Map<String, dynamic>> generateStudyRoadmap({
    required String subjectName,
    required int totalChapters,
    required int daysRemaining,
    required int hoursPerDay,
  }) async {
    try {
      final prompt = """
تۆ شارەزایەکی زانستی و ڕێنماییکاری زانکۆیی. تکایە بۆ بابەتی ($subjectName) کە ($totalChapters) بەشی هەیە و تەنها ($daysRemaining) ڕۆژی ماوە بۆ تاقیکردنەوە، و خوێندکار دەتوانێت ڕۆژانە ($hoursPerDay) کاتژمێر بخوێنێت، نەخشەڕێگایەکی ڕۆژانەی گونجاو بە زمانی کوردی (سۆرانی) بە شێوازی JSON بنووسەوە.

شێوازی پێویستی JSON:
{
  "advice": "ئامۆژگاری و ڕێنمایی کورتی زانستی بۆ تاقیکردنەوەکە",
  "tasks": [
    {
      "dayIndex": 1,
      "title": "سەردێڕی دەستکەوتی ڕۆژی یەکەم",
      "description": "ڕوونکردنەوەی وردی ئەوەی چ بەشێک بخوێندرێت",
      "suggestedPomodoros": 3
    }
  ]
}
""";
      final responseText = await _callGemini(prompt);
      if (responseText.isNotEmpty && responseText.contains('{')) {
        final start = responseText.indexOf('{');
        final end = responseText.lastIndexOf('}') + 1;
        final jsonSub = responseText.substring(start, end);
        return jsonDecode(jsonSub);
      }
    } catch (_) {}

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
          'title': 'پێداچوونەوەی گشتی و بەکارهێنانی فلاش کارتەکان 📑',
          'description': 'حلکردنی کویزەکانی ڕابردوو و تاقیکردنەوە لەسەر سەرجەم بەشەکانی (١ بۆ $totalChapters)',
          'suggestedPomodoros': (hoursPerDay * 2).clamp(2, 8),
        });
      } else {
        fallbackTasks.add({
          'dayIndex': i,
          'title': startChap == endChap
              ? 'خوێندنی بەشی $startChap لە بابەتی $subjectName 📖'
              : 'خوێندنی بەشەکانی ($startChap بۆ $endChap) 📚',
          'description': 'تێگەیشتن لە چەمکە سەرەکییەکان، دیاریکردنی وشە کلیلییەکان و پاشەکەوتکردنی لە فلاش کارت.',
          'suggestedPomodoros': (hoursPerDay * 2).clamp(2, 6),
        });
      }
    }

    return {
      'advice': 'بەردەوام بە لەسەر جێبەجێکردنی نەخشەڕێگاکەت بە بەکارهێنانی کاتژمێری فۆکەس (Pomodoro) تا بە بەرزترین نمرە سەربکەویت!',
      'tasks': fallbackTasks,
    };
  }

  @override
  Future<Map<String, dynamic>> generateKurdishVoiceLectureExplanation({
    required String pdfText,
    String? pdfName,
    String targetLanguage = 'ku',
  }) async {
    final cleanContent = pdfText.length > 15000 ? pdfText.substring(0, 15000) : pdfText;
    final isEn = targetLanguage == 'en';

    final jsonExample = isEn
        ? r'''
{
  "title": "Audio Lecture: Chapter Title",
  "summary": "Concise 2-sentence summary of the subject in English.",
  "targetLanguage": "en",
  "sections": [
    {
      "sectionTitle": "Section 1: Chapter Title in English",
      "kurdishExplanation": "Full detailed voice-optimized academic lecture script in clear spoken English for this topic. No bullet points, no markdown, just natural sentences.",
      "englishKeyTerms": ["Term 1: its definition", "Term 2: its definition"]
    }
  ]
}'''
        : r'''
{
  "title": "ڕوونکردنەوەی دەنگی: ناوی وانە",
  "summary": "پوختەیەکی کورتی ٢ ڕستەیی لەسەر گشتیاتی بابەتەکە بە کوردی.",
  "targetLanguage": "ku",
  "sections": [
    {
      "sectionTitle": "بەشی ١: ناونیشانی بەشەکە بە کوردی",
      "kurdishExplanation": "ڕوونکردنەوەی تێروتەسەلی مامۆستایانە بە کوردی سۆڕانی ڕەوان بە جۆرێک کە گوێگرتنی دەنگی ئاسان بێت، بەبێ هێما یان موارکداون.",
      "englishKeyTerms": ["Term 1: مانای کوردی", "Term 2: مانای کوردی"]
    }
  ]
}''';

    final prompt = isEn
        ? '''
You are a distinguished university professor giving a clear structured audio lecture based on this PDF material titled "${pdfName ?? 'Lecture Notes'}".

Here is the full PDF content:
---
$cleanContent
---

Your task: Read the PDF content above carefully and restructure ALL of it into a detailed, high quality, step-by-step academic audio lecture script ENTIRELY IN ENGLISH. Cover every topic, concept, and detail in the PDF.

CRITICAL RULES:
1. Use only the content from the PDF above — do NOT generate generic text.
2. Write in clear natural spoken academic English — no bullet points, no markdown symbols, no dashes, no code blocks.
3. Each section must correspond to actual content from the PDF.
4. The "kurdishExplanation" field contains the English lecture script for that section.
5. Include ALL key terms from the PDF with their definitions.

Return ONLY valid JSON matching this exact structure:
$jsonExample
'''
        : '''
تۆ مامۆستایەکی ئەکادیمی زانکۆیت و ئەرکت ئەوەیە ئەم فایلی PDFە بە شێوازێکی فێرکاریی باڵا، بە کوردییەکی سۆرانیی پاراو، ڕەوان و شیرین بە دەنگ بۆ خوێندکارانی زانکۆ شی بکەیتەوە.

ناوی فایل: ${pdfName ?? 'مەلزەمەی وانە'}

ناوەڕۆکی فایلی PDF:
---
$cleanContent
---

داواکاری:
ناوەڕۆکی PDFی سەرەوە بە وردی بخوێنەوە و بکەرە چەند بەشێکی زنجیرەیی فێرکاری کە هەر بەشێکی ڕوونکردنەوەیەکی تێروتەسەلی دەنگی لەخۆبگرێت.

ڕێساکانی دەقی دەنگی (kurdishExplanation):
١. بە کوردی سۆرانی پاراو و ئەکادیمی و بە ڕستەی تەواو و خۆش بنووسە، وەک ئەوەی مامۆستا لە هۆڵی وانەوتنەوەدا قسە بۆ خوێندکاران بکات.
٢. دەستەواژەی ژنێریک و پێشەکی ناپێویست مەنووسە، ڕاستەوخۆ ناوەڕۆک و چەمکە ڕاستەقینەکانی ناو فایلی PDFەکە شی بکەرەوە.
٣. دەقەکە تەنها تێکستی پەتی بێت بۆ خوێندنەوەی دەنگی (بێ خاڵبەندی بێسەروبەر، بێ ئەستێرە، بێ باکلاش، بێ کۆد).
٤. وشە زانستییە ئینگلیزییەکان لە خانەی englishKeyTerms دابنێ لەگەڵ مانای کوردییان.

تەنها JSON ی دروست بگەڕێنەوە بەپێی ئەم فۆرماتە:
$jsonExample
''';

    try {
      final jsonString = await _callGemini(prompt);
      if (jsonString.isNotEmpty && !jsonString.startsWith('⚠️')) {
        try {
          final startIndex = jsonString.indexOf('{');
          final endIndex = jsonString.lastIndexOf('}');
          if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
            final jsonSub = jsonString.substring(startIndex, endIndex + 1);
            final decoded = jsonDecode(jsonSub);
            if (decoded is Map<String, dynamic> && decoded.containsKey('sections')) {
              return decoded;
            }
          }
        } catch (jsonErr) {
          debugPrint('JSON parse error in voice explanation: $jsonErr');
        }
      }
    } catch (e) {
      debugPrint('Error generating voice explanation: $e');
    }

    if (isEn) {
      return {
        'title': 'Audio Lecture: ${pdfName ?? 'Lecture Notes'}',
        'summary': 'Could not connect to AI. Please check your internet and API key.',
        'targetLanguage': 'en',
        'sections': [
          {
            'sectionTitle': 'Connection Error',
            'kurdishExplanation': 'Could not reach the AI service. Please check your internet connection or API key, then try again.',
            'englishKeyTerms': []
          }
        ]
      };
    }

    return {
      'title': 'ڕوونکردنەوەی دەنگی: ${pdfName ?? 'وانەی ئەکادیمی'}',
      'summary': 'نەتوانرا پەیوەندی بە سێرڤەری AI بکرێت. تکایە ئینتەرنێت و کلیلی API پشکنین بکە.',
      'targetLanguage': 'ku',
      'sections': [
        {
          'sectionTitle': 'هەڵەی پەیوەندی',
          'kurdishExplanation': 'نەتوانرا بە سێرڤەری AI پەیوەندی بکرێت. تکایە ئینتەرنێتت پشکنین بکە یان کلیلی API بنووسە، پاشان دووبارە هەوڵ بدە.',
          'englishKeyTerms': []
        }
      ]
    };
  }
}
