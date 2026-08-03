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
    final deptsSummary = matchedDepts.map((d) => '- ${d.university} (${d.college}): لانی کەم ${d.minMark}% [شار: ${d.city}]').join('\n');

    final prompt = '''
تۆ ڕاوێژکاری زیرەکی زانکۆلاینیت (ZankoLine AI Advisor) بۆ هەرێمی کوردستان.
قوتابییەکە نمرەی پۆلی ۱۲ی بریتییە لە: $studentMark% (لقی: $track).

ئەمە بەشە گونجاوەکانی وەرگرتنیەتی لە زانکۆکان:
$deptsSummary

تکایە بە زمانی کوردی (سۆرانی):
١. پیرۆزبایی لێبکە و هەڵسەنگاندنێکی کورت بۆ نمرەکەی بکە.
٢. باشترین ۳ بەشی بۆ شیکەرەوە کە بۆ داهاتووی کاری گونجاوترن.
٣. ڕێنمایی کورتی بدەرێ بۆ هەڵبژاردنی بەشەکان لە زانکۆلاین.
''';

    try {
      return await _aiService.askTeacher(prompt, []);
    } catch (e) {
      return 'تێکڕای نمرەکەت ($studentMark%) نایابە! دەتوانیت لە بەشە دەستنیشانکراوەکانی سەرەوە داواکاری پێشکەش بکەیت لە سیستەمی زانکۆلاین.';
    }
  }
}
