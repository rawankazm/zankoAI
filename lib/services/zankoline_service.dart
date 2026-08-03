import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';

class ZankolineDepartmentModel {
  final String id;
  final String university;
  final String college;
  final double minMark;
  final String track;
  final String city;
  final String description;

  ZankolineDepartmentModel({
    required this.id,
    required this.university,
    required this.college,
    required this.minMark,
    required this.track,
    required this.city,
    required this.description,
  });

  factory ZankolineDepartmentModel.fromJson(Map<String, dynamic> json) {
    return ZankolineDepartmentModel(
      id: json['id'] ?? '',
      university: json['university'] ?? '',
      college: json['college'] ?? '',
      minMark: (json['min_mark'] as num).toDouble(),
      track: json['track'] ?? 'scientific',
      city: json['city'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

class ZankolineService extends ChangeNotifier {
  final AiService _aiService;
  List<ZankolineDepartmentModel> _departments = [];
  bool _isLoading = false;

  ZankolineService(this._aiService) {
    loadDepartments();
  }

  bool get isLoading => _isLoading;
  List<ZankolineDepartmentModel> get departments => _departments;

  Future<void> loadDepartments() async {
    _isLoading = true;
    notifyListeners();
    try {
      final jsonStr = await rootBundle.loadString('assets/data/krg_zankoline.json');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _departments = jsonList.map((e) => ZankolineDepartmentModel.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) print('Error loading Zankoline dataset: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<ZankolineDepartmentModel> filterMatchingDepartments(double mark, String track) {
    return _departments.where((dept) {
      final isTrackMatch = dept.track.toLowerCase() == track.toLowerCase();
      final isMarkEligible = mark >= dept.minMark;
      return isTrackMatch && isMarkEligible;
    }).toList()
      ..sort((a, b) => b.minMark.compareTo(a.minMark));
  }

  Future<String> askZankolineAiAdvisor(double studentMark, String track, List<ZankolineDepartmentModel> matchedDepts) async {
    final trackName = track == 'scientific' ? 'زانستی' : 'وێژەیی';

    if (matchedDepts.isEmpty) {
      return 'بەپێی تێکڕای نمرەکەت ($studentMark%) لە لقی $trackName، هیچ بەشێک لە نمرەی نزمتر نەدۆزرایەوە. تکایە نمرەیەکی بەرزتر داخڵ بکە یان بەشە هەڵبژێردراوەکانی پۆلی ۱۲ بپشکنە.';
    }

    final deptsSummary = matchedDepts.map((d) => '• ${d.university} - ${d.college}\n  - لانی کەم نمرە: ${d.minMark}%\n  - شار: ${d.city}\n  - وەسف: ${d.description}').join('\n\n');

    final prompt = '''
تۆ ڕاوێژکاری فەرمی زیرەکی زانکۆلاینیت (ZankoLine AI Advisor) بۆ زانکۆکانی هەرێمی کوردستان.
تێکڕای نمرەی قوتابی لە پۆلی ۱۲: $studentMark% (لقی: $trackName).

ئەمەش کۆمەڵەی بەشەکانن کە لەگەڵ نمرەکەی گونجاون:
$deptsSummary

تکایە وەڵامەکەت بە شێوازێکی پڕۆفێشناڵ و ڕوون بە کوردی (سۆرانی) بەم جۆرە بنووسە:
١. دەستپێک: "بەپێی تێکڕای نمرەکەت ($studentMark%)، ئەم بەشانەی خوارەوە لە زانکۆکان دەتوانیت لێیان وەربگیرێیت:"
٢. لیستی بەشەکان لەگەڵ شیکاری کورت.
''';

    try {
      final res = await _aiService.askTeacher(prompt, []);
      if (res.contains('API Key Required') || res.contains('تکایە API Key')) {
        return _buildLocalKurdishAdvisorSummary(studentMark, trackName, matchedDepts);
      }
      return res;
    } catch (_) {
      return _buildLocalKurdishAdvisorSummary(studentMark, trackName, matchedDepts);
    }
  }

  String _buildLocalKurdishAdvisorSummary(double studentMark, String trackName, List<ZankolineDepartmentModel> matchedDepts) {
    final buffer = StringBuffer();
    buffer.writeln('بەپێی تێکڕای نمرەکەت %$studentMark لە لقی $trackName، ئەم بەشانەی خوارەوە لە زانکۆکانی هەرێمی کوردستان لەگەڵ نمرەکەت دەگونجێن:\n');

    for (var i = 0; i < matchedDepts.length; i++) {
      final dept = matchedDepts[i];
      buffer.writeln('${i + 1} - ${dept.college} - ${dept.university}');
      buffer.writeln('  - لانی کەم نمرەی وەرگرتن: %${dept.minMark}');
      buffer.writeln('  - شار: ${dept.city}');
      buffer.writeln('  - دەربارەی بەشەکە: ${dept.description}\n');
    }

    buffer.writeln('💡 ڕێنمایی: بەپێی ئارەزووی خۆت و نزیکی شارەکەت، بەشەکان لە سیستەمی زانکۆلاین کۆپ بکەرەوە و داواکاری پێشکەش بکە.');
    return buffer.toString();
  }
}
