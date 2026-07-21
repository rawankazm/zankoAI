import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/quiz_model.dart';
import '../models/flashcard_model.dart';
import '../models/study_plan_model.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gemini;

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
  String? _apiKey;

  @override
  String? get apiKey => _apiKey;

  @override
  set apiKey(String? key) {
    _apiKey = key;
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
      model: 'gemini-2.0-flash',
      apiKey: _apiKey!,
      systemInstruction: systemInstruction.isNotEmpty
          ? gemini.Content.system(systemInstruction)
          : null,
    );
    
    final content = [gemini.Content.text(prompt)];
    final response = await model.generateContent(content);
    return response.text ?? "نەتوانرا وەڵام لە لایەن AI بەدەستبهێنرێت.";
  }

  @override
  Future<String> askTeacher(String userPrompt, List<Map<String, String>> chatHistory) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (hasRealApiKey) {
      try {
        String historyStr = "";
        for (var msg in chatHistory) {
          historyStr += "${msg['role'] == 'user' ? 'خوێندکار' : 'مامۆستا'}: ${msg['content']}\n";
        }
        final prompt = "$historyStrخوێندکار: $userPrompt\nمامۆستا:";
        
        const systemInstruction = 
            "تۆ مامۆستایەکی زیرەکی زانکۆیت بە ناوی ZankoAI. وەک مامۆستایەکی دڵسۆز و ڕوون یارمەتی خوێندکارەکە بدە. "
            "وەڵامەکانت بە زمانی کوردی (سۆرانی) بن. بە ڕوونی، خاڵبەندی، و بە شێوازێکی فێرکاری و ئەکادیمی وەڵام بدەرەوە.";
            
        return await _callGemini(prompt, systemInstruction: systemInstruction);
      } catch (e) {
        if (_isNetworkError(e)) {
          return "📡 **(شێوازی ئۆفلاین - بەستنەوە بەستراو نییە)**\n\n" + 
                 _getMockTeacherResponse(userPrompt);
        }
        return "هەڵەیەک ڕوویدا لە بەستنەوە بە AI: $e";
      }
    }

    return _getMockTeacherResponse(userPrompt);
  }

  String _getMockTeacherResponse(String userPrompt) {
    final query = userPrompt.toLowerCase();
    if (query.contains('operating system') || query.contains('سیستەمی کارپێکردن')) {
      return "وەک مامۆستایەکی سیستەمی کارپێکردن (OS)، با ئەمەت بۆ ڕوون بکەمەوە:\n\n"
          "سیستەمی کارپێکردن گرنگترین نەرمەکاڵایە کە لەسەر کۆمپیوتەر کاردەکات. بەرپرسە لە بەڕێوەبردنی یادگەی کۆمپیوتەرەکە و پرۆسەکان، هەروەها ڕێکخستنی هەموو ڕەقەکاڵا و نەرمەکاڵاکان.\n\n"
          "سێ ئەرکی سەرەکی OS بریتیین لە:\n"
          "١. **Processor Management:** دابەشکردنی کات و توانای CPU بەسەر پرۆسە جیاوازەکاندا.\n"
          "٢. **Memory Management:** چاودێریکردنی چی لە یادگەدایە و کێ بەکاری دەهێنێت.\n"
          "٣. **File System:** چۆنێتی پاشەکەوتکردن و ڕێکخستنی زانیارییەکان لەسەر دیسک.";
    } 
    
    if (query.contains('کۆد') || query.contains('code') || query.contains('program')) {
      return "با وەک مامۆستایەکی بەرنامەسازی سەیری ئەم کۆدە بکەین:\n\n"
          "لە فلاتەر و دارتدا، کاتێک دەتەوێت گۆڕانکاری لە ڕوکاری ئەپەکەدا بکەیت، پێویستە `setState` بەکاربهێنیت بۆ ئەوەی فلاتەر بزانێت کە دەبێت ڕوکارەکە نوێ بکاتەوە.\n\n"
          "بۆ نموونە:\n"
          "```dart\n"
          "int count = 0;\n"
          "void increment() {\n"
          "  setState(() {\n"
          "    count++; \n"
          "  });\n"
          "}\n"
          "```";
    }

    return "سڵاو خوێندکاری خۆشەویست! من ZankoAI مامۆستای زیرەکی تۆم. لەبەر ئەوەی بەشی ئۆفلاین چالاکە، دەتوانیت پرسیارم لێ بکەیت لەسەر 'سیستەمی کارپێکردن' یان 'کۆدنووسین' بۆ بینینی وەڵامی نموونەیی.";
  }

  @override
  Future<Map<String, dynamic>> summarizePdf(String pdfName, String pdfContent) async {
    await Future.delayed(const Duration(milliseconds: 1000));

    if (hasRealApiKey) {
      try {
        final prompt = "ئەم دەقەی خوارەوە کە لە فایلی بە ناوی '$pdfName' دەرهێنراوە بە وردی کورت بکەرەوە. "
            "وەڵامەکەت پێویستە بە زمانی کوردی (سۆرانی) بێت و سێ بەش لەخۆ بگرێت: "
            "١- کورتهەیەکی گشتی (Summary)\n"
            "٢- خاڵە سەرەکی و گرنگەکان (Key Points) وەک لیستی خاڵبەندی\n"
            "٣- وەرگێڕانی گرنگترین پارچەی دەقەکە بۆ کوردی (Translation)\n\n"
            "دەقەکە:\n$pdfContent";
        
        final responseText = await _callGemini(prompt);
        
        final sections = responseText.split('\n\n');
        String summary = responseText;
        List<String> keyPoints = [];
        String translation = "وەرگێڕان لە دەقی سەرەکییەوە ئەنجامدراوە.";
        
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
            'summary': "📡 **(شێوازی ئۆفلاین)**\n\n" + mockRes['summary']!,
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
      'translation': "ئەم پەڕتووکە لەسەر تۆڕەکانی کۆمپیوتەر ڕێبەرییەکی تەواوە بۆ خوێندکارانی بەشی تەکنەلۆجیا تا بە بنەماکانی سویچ، ڕاوتەر و گواستنەوەی پاکەتەکان ئاشنا بن."
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
        final prompt = "ئەم دەقەی خوارەوە بخوێنەرەوە و کویزێکی تاقیکاری لەسەر دروست بکە بە زمانی کوردی (سۆرانی). "
            "کویزەکە پێویستە ٣ پرسیار لەخۆ بگرێت: "
            "١- یەکەم پرسیار هەڵبژاردەیی (multipleChoice) لەگەڵ ٤ بژاردە. "
            "٢- دووەم پرسیار ڕاست یان هەڵە (trueFalse). "
            "٣- سێیەم پرسیار پڕکردنەوەی بۆشایی (fillInBlank). "
            "تکایە وەڵامەکە تەنها وەک فۆرماتی JSON ڕوون بنووسە بەم شێوازەی خوارەوە (بەبێ نووسینی تر): \n"
            "{\n"
            "  \"title\": \"تاقیکردنەوەی خێرا لەسەر وانەکە\",\n"
            "  \"questions\": [\n"
            "     { \"questionText\": \"پرسیاری یەکەم لێرە\", \"type\": \"multipleChoice\", \"options\": [\"بژاردەی ١\", \"بژاردەی ٢\", \"بژاردەی ٣\", \"بژاردەی ٤\"], \"correctAnswer\": \"وەڵامی ڕاست لێرە کە هاوشێوەی یەکێک لە بژاردەکانە\" },\n"
            "     { \"questionText\": \"پرسیاری دووەم لێرە\", \"type\": \"trueFalse\", \"correctAnswer\": \"ڕاستە\" },\n"
            "     { \"questionText\": \"پرسیاری سێیەم لێرە بە شێوازی بۆشایی\", \"type\": \"fillInBlank\", \"correctAnswer\": \"وەڵامەکە\" }\n"
            "  ]\n"
            "}\n\n"
            "دەقەکە:\n$fileText";
        
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
          title: data['title'] ?? 'کویزی نوێ بە AI',
          courseName: courseName,
          questions: questions,
        );
      } catch (e) {
        if (_isNetworkError(e)) {
          return _generateMockQuiz("📡 (کویزی ئۆفلاین) - تۆڕ بەردەست نییە", courseName);
        }
        return _generateMockQuiz("تاقیکردنەوەی خێرا (Fallback)", courseName);
      }
    }

    return _generateMockQuiz("کویزی دەقی بارکراو", courseName);
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
          return "📡 **(شێوازی ئۆفلاین - فۆرماتی لۆکاڵی)**\n\n" + 
                 _getMockOrganizedNote(rawNoteContent);
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
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (hasRealApiKey) {
      try {
        final prompt = "ئەم تێبینییە یان بابەتەی خوارەوە بخوێنەرەوە و ٤ فلاشکاردی خوێندنەوەی تایبەت دروست بکە بە زمانی کوردی (سۆرانی). "
            "هەر فلاشکاردێک پێویستە دەقێکی کورت یان پرسیارێک بێت بۆ پێشەوە (front) و وەڵامەکە یان ماناکەی بۆ دواوە بێت (back). "
            "تەنها فۆرماتی JSON خوارەوە بنووسە بەبێ نووسینی تر:\n"
            "[\n"
            "  { \"front\": \"پرسیارەکە یان زاراوەکە\", \"back\": \"ڕوونکردنەوە کورتەکە یان وەڵامەکە\" }\n"
            "]\n\n"
            "بابەت:\n$topicOrText";
            
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
          return _getMockFlashcards("📡 (بەستنەوە نییە) - $topicOrText");
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
        front: 'مۆدێلی OSI چییە؟',
        back: 'ڕێکخراوێکە بۆ لێکتێگەیشتنی پرۆتۆکۆلەکانی تۆڕ لە ٧ چینی جیاوازدا.',
      ),
      FlashcardModel(
        id: 'c2',
        front: 'کارکردنی CPU چییە؟',
        back: 'ئامێری سەرەکی جێبەجێکردنی فەرمانەکان و پرۆسێسەکردنی زانیارییەکان لە کۆمپیوتەردا.',
      ),
      FlashcardModel(
        id: 'c3',
        front: 'مەبەست لە Deadlock چییە لە سیستەمی کارپێکردندا؟',
        back: 'کاتێک دوو پڕۆسس یان زیاتر چاوەڕوانی یەکدی دەکەن بۆ ئازادکردنی سەرچاوەیەک، و هەموو دەوەستن.',
      ),
      FlashcardModel(
        id: 'c4',
        front: 'سیستەمی فایل (File System) چییە؟',
        back: 'شێوازی ڕێکخستن و هەڵگرتنی فایل و زانیارییەکان لەسەر دیسکی پاشەکەوتکردن.',
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

  // Mock quiz fallback generator
  QuizModel _generateMockQuiz(String topic, String courseName) {
    final List<QuestionModel> questions = [
      QuestionModel(
        id: 'q_n1',
        questionText: 'ئەرکی سەرەکی ڕاوتەر (Router) چییە لە تۆڕدا؟',
        type: QuestionType.multipleChoice,
        options: [
          'بەستنەوەی جۆینتەکان لە هەمان تۆڕی ناوخۆییدا',
          'ڕێڕەوکردن و ئاڕاستەکردنی داتا لە نێوان تۆڕە جیاوازەکاندا',
          'پاراستنی کۆمپیوتەر لە ڤایرۆس',
          'دابینکردنی وزەی کارەبا بۆ ئامێرەکان'
        ],
        correctAnswer: 'ڕێڕەوکردن و ئاڕاستەکردنی داتا لە نێوان تۆڕە جیاوازەکاندا',
      ),
      QuestionModel(
        id: 'q_n2',
        questionText: 'مۆدێلی OSI لە ٧ چین پێکهاتووە.',
        type: QuestionType.trueFalse,
        correctAnswer: 'ڕاستە',
      ),
      QuestionModel(
        id: 'q_n3',
        questionText: 'پڕۆتۆکۆلی... کە بۆ کردنەوەی ماڵپەڕەکان بەکاردێت ناوی چییە؟',
        type: QuestionType.fillInBlank,
        correctAnswer: 'HTTPS',
      )
    ];

    return QuizModel(
      id: 'quiz_${Random().nextInt(10000)}',
      title: 'تاقیکردنەوەی خێرا: $topic',
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
        final prompt = "ئەم نووسین و تێبینییانەی خوارەوە بخوێنەرەوە کە هی خوێندکارە لە فایلی بە ناوی '$notesName'. "
            "شیکردنەوە بکە و پێشبینی ٥ پرسیاری تاقیکردنەوەی زۆر گرنگ بکە کە پێشبینی دەکەیت مامۆستا لەسەر ئەم بابەتانە داینێت. "
            "وەڵامەکەت پێویستە بە زمانی کوردی (سۆرانی) بنوسیت و ئەم بەشانە لەخۆ بگرێت:\n"
            "١. پێناسەیەکی کورت بۆ بابەتە سەرەکییەکان.\n"
            "٢. ٥ پرسیاری پێشبینیکراو لەگەڵ ڕوونکردنەوەی وەڵامەکانیان بۆ فێربوونی خوێندکار.\n"
            "٣. ٣ ئامۆژگاری زێڕین بۆ چۆنێتی سەرزەنشتکردن یان تەمرینکردنی ئەم بابەتانە.\n\n"
            "تێبینییەکان:\n$notesContent";

        final responseText = await _callGemini(prompt);
        return {
          'prediction': responseText,
        };
      } catch (e) {
        if (_isNetworkError(e)) {
          return {
            'prediction': "📡 **(شێوازی ئۆفلاین)**\n\n" + _getMockPrediction(notesName),
          };
        }
        return {
          'prediction': "هەڵەیەک لە ژیری دەستکرد ڕوویدا: $e",
        };
      }
    }

    return {
      'prediction': _getMockPrediction(notesName),
    };
  }

  String _getMockPrediction(String notesName) {
    return "پێشبینی پرسیارەکانی تاقیکردنەوە بۆ بابەتەکە:\n\n"
        "١. **پرسیاری یەکەم:** جیاوازی نێوان RAM و ROM چییە؟\n"
        "   * وەڵام: RAM یادگەیەکی کاتییە و بە کوژانەوەی ئامێرەکە زانیارییەکانی دەسڕێتەوە، بەڵام ROM نەگۆڕە و زانیاری ڕێکخستنی سەرەتایی کۆمپیوتەری تێدایە.\n\n"
        "٢. **پرسیاری دووەم:** سیستەمی فایلی NTFS چییە و جیاوازی لەگەڵ FAT32 چییە؟\n"
        "   * وەڵام: NTFS پشتگیری فایلی گەورەتر دەکات و پارێزگاری زیاترە بە بەراورد لەگەڵ FAT32 کە وەشانی کۆنترە.\n\n"
        "٣. **پرسیاری سێیەم:** پرۆسە (Process) لە سیستەمی کارپێکردندا چییە؟\n"
        "   * وەڵام: پرۆسە بریتییە لە بەرنامەیەک کە لە کاتی جێبەجێکردندایە و سەرچاوەکانی وەک CPU و RAM بەکاردێنێت.\n\n"
        "💡 **ئامۆژگاری بۆ خوێندن:**\n"
        "- تەرکیز لەسەر جیاوازییەکان بکە لە نێوان چەمکەکان.\n"
        "- پۆینتەر و شێوازی مێمۆری لەم وانەیەدا زۆر گرنگە.";
  }
}
