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
    final deptsSummary = matchedDepts.map((d) => '• ${d.university} - ${d.college}\n  - لانی کەم نمرە: ${d.minMark}%\n  - شار: ${d.city}\n  - وەسفی بەش: ${d.description}').join('\n\n');

    final prompt = '''
تۆ ڕاوێژکاری فەرمی زیرەکی زانکۆلاینیت (ZankoLine AI Advisor) بۆ زانکۆکانی هەرێمی کوردستان.
تێکڕای نمرەی قوتابی لە پۆلی ۱۲: $studentMark% (لقی: ${track == 'scientific' ? 'زانستی' : 'وێژەیی'}).

ئەمەش کۆمەڵەی بەشەکانن کە لەگەڵ نمرەکەی گونجاون:
$deptsSummary

تکایە وەڵامەکەت بە شێوازێکی پڕۆفێشناڵ و ڕوون بە کوردی (سۆرانی) بەم جۆرە بنووسە:

١. دەستپێک: "بەپێی تێکڕای نمرەکەت ($studentMark%)، ئەم بەشانەی خوارەوە لە زانکۆکان دەتوانیت لێیان وەربگیرێیت:"
٢. لیستی بەشەکان: بۆ هەر بەشێک ناو، لانی کەم نمرەی وەرگرتن، و وەسفێکی تێروتەسەل دەربارەی داهاتووی بەشەکە و بوارەکانی کارکردنی روونبکەرەوە.
٣. کۆتایی: ئامۆژگاری و ڕێنمایی کورت بۆ داواکاری پێشکەشکردن لە زانکۆلاین.
''';

    try {
      return await _aiService.askTeacher(prompt, []);
    } catch (e) {
      return 'بەپێی تێکڕای نمرەکەت ($studentMark%)، دەتوانیت لە بەشە دەستنیشانکراوەکانی سەرەوە داواکاری لە سیستەمی زانکۆلاین پێشکەش بکەیت.';
    }
  }
}
