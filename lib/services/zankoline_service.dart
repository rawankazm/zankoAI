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
  final int parallelFeeIqd;

  ZankolineDepartmentModel({
    required this.id,
    required this.university,
    required this.college,
    required this.minMark,
    required this.track,
    required this.city,
    required this.description,
    required this.parallelFeeIqd,
  });

  factory ZankolineDepartmentModel.fromJson(Map<String, dynamic> json) {
    final collegeName = (json['college'] ?? '').toString();
    final rawMinMark = json['min_mark'];
    final double minMarkVal = rawMinMark != null ? (rawMinMark as num).toDouble() : 50.0;

    int defaultFee = 1000000;
    if (collegeName.contains('پزیشکی گشتی')) {
      defaultFee = 5500000;
    } else if (collegeName.contains('پزیشکی ددان')) {
      defaultFee = 4500000;
    } else if (collegeName.contains('دەرمانسازی')) {
      defaultFee = 4000000;
    } else if (collegeName.contains('تەلارسازی') || collegeName.contains('ISE') || collegeName.contains('نەوت') || collegeName.contains('سوفتوێر')) {
      defaultFee = 2750000;
    } else if (collegeName.contains('ئەندازیاری') || collegeName.contains('پەرستاری') || collegeName.contains('بێهۆشکاری') || collegeName.contains('تەندروستی') || collegeName.contains('شیکاری')) {
      defaultFee = 2200000;
    } else if (collegeName.contains('کۆمپیوتەر') || collegeName.contains('IT') || collegeName.contains('زانست')) {
      defaultFee = 1650000;
    } else if (collegeName.contains('یاسا') || collegeName.contains('بازرگانی') || collegeName.contains('سیاسی')) {
      defaultFee = 1350000;
    } else if (collegeName.contains('پەیمانگەی')) {
      defaultFee = 750000;
    }

    final rawFee = json['parallel_fee_iqd'];
    final int feeVal = rawFee != null ? (rawFee as num).toInt() : defaultFee;

    return ZankolineDepartmentModel(
      id: (json['id'] ?? '').toString(),
      university: (json['university'] ?? '').toString(),
      college: collegeName,
      minMark: minMarkVal,
      track: (json['track'] ?? 'scientific').toString(),
      city: (json['city'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      parallelFeeIqd: feeVal,
    );
  }

  double get parallelMinMark => double.parse((minMark - 4.5).clamp(50.0, 100.0).toStringAsFixed(1));

  int get discountedParallelFeeIqd => (parallelFeeIqd * 0.55).round();

  String get formattedParallelFee {
    final discountedMillions = discountedParallelFeeIqd / 1000000.0;

    String formatVal(double val) {
      if (val >= 1) {
        return val % 1 == 0 ? '${val.toStringAsFixed(0)} ملیۆن' : '${val.toStringAsFixed(2)} ملیۆن';
      }
      final thousands = (val * 1000).round();
      return '$thousands هەزار';
    }

    return '${formatVal(discountedMillions)} دینار (دوای %45 داشکاندن)';
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

  Future<List<ZankolineDepartmentModel>> filterMatchingDepartments(double mark, String track, {bool isParallel = false}) async {
    if (_departments.isEmpty) {
      await loadDepartments();
    }
    return _departments.where((dept) {
      final isTrackMatch = dept.track.toLowerCase() == track.toLowerCase();
      if (!isTrackMatch) return false;

      if (isParallel) {
        // Parallel mode specifically targets departments that require Parallel to unlock
        // (i.e., student's mark qualifies for Parallel: mark >= parallelMinMark,
        // BUT the General cutoff is above or near student's mark: dept.minMark >= mark - 1.0).
        final isParallelEligible = mark >= dept.parallelMinMark;
        final isTargetUpgrade = dept.minMark >= (mark - 1.0);
        return isParallelEligible && isTargetUpgrade;
      } else {
        // General free public mode requires student mark >= General cutoff
        return mark >= dept.minMark;
      }
    }).toList()
      ..sort((a, b) => b.minMark.compareTo(a.minMark));
  }

  Future<String> askZankolineAiAdvisor(double studentMark, String track, List<ZankolineDepartmentModel> matchedDepts, {bool isParallel = false}) async {
    final trackName = track == 'scientific' ? 'زانستی' : 'وێژەیی';
    final systemModeName = isParallel ? 'پاڕاڵێڵ (تێکڕای کەمکراوە)' : 'خوێندنی گشتی / بەخۆڕایی';

    if (matchedDepts.isEmpty) {
      return 'بەپێی تێکڕای نمرەکەت (%$studentMark) لە لقی $trackName لە سیستەمی $systemModeName، هیچ بەشێک نەدۆزرایەوە.';
    }

    final deptsSummary = matchedDepts.map((d) {
      final minCutoff = isParallel ? d.parallelMinMark : d.minMark;
      return '• ${d.university} - ${d.college}\n  - نمرەی پاڕاڵێڵ/گشتی: %$minCutoff\n  - شار: ${d.city}\n  - وەسف: ${d.description}';
    }).join('\n\n');

    final prompt = '''
تۆ ڕاوێژکاری فەرمی زیرەکی زانکۆلاینیت (ZankoLine AI Advisor) بۆ زانکۆکانی هەرێمی کوردستان.
تێکڕای نمرەی قوتابی: %$studentMark (لقی: $trackName) - سیستەم: $systemModeName.

ئەمەش کۆمەڵەی بەشەکانن کە لەگەڵ نمرەکەی گونجاون:
$deptsSummary

تکایە وەڵامەکەت بە شێوازێکی پڕۆفێشناڵ و ڕوون بە کوردی (سۆرانی) بەم جۆرە بنووسە:
١. دەستپێک: "بەپێی تێکڕای نمرەکەت (%$studentMark) لە سیستەمی $systemModeName، ئەم بەشانە لە زانکۆکان دەتوانیت لێیان وەربگیرێیت:"
٢. لیستی بەشەکان لەگەڵ شیکاری کورت و ئامۆژگاری بۆ پاڕاڵێڵ.
''';

    try {
      final res = await _aiService.askTeacher(prompt, []);
      if (res.contains('API Key Required') || res.contains('تکایە API Key')) {
        return _buildLocalKurdishAdvisorSummary(studentMark, trackName, matchedDepts, isParallel: isParallel);
      }
      return res;
    } catch (_) {
      return _buildLocalKurdishAdvisorSummary(studentMark, trackName, matchedDepts, isParallel: isParallel);
    }
  }

  String _buildLocalKurdishAdvisorSummary(double studentMark, String trackName, List<ZankolineDepartmentModel> matchedDepts, {bool isParallel = false}) {
    final buffer = StringBuffer();
    final systemLabel = isParallel ? 'سیستەمی پاڕاڵێڵ (%40 داشکاندنی فەرمی)' : 'خوێندنی گشتی (بەخۆڕایی)';
    final topDepts = matchedDepts.take(3).map((d) => d.college).join('، ');

    buffer.writeln('بەپێی تێکڕای نمرەکەت (%$studentMark) لە لقی $trackName لە ($systemLabel)، نمرەکەت هەلێکی زۆر باش دەبەخشێت بۆ وەرگرتن لە زانکۆکانی هەرێمی کوردستان.');
    buffer.writeln('کۆی ${_matchedDepartmentsCount(matchedDepts)} بەشی گونجاو دۆزرانەوە. لە دیارترینیان: $topDepts.\n');

    buffer.writeln('💡 ڕێنمایی ڕاوێژکار:');
    if (isParallel) {
      buffer.writeln('• بەکارهێنانی پاڕاڵێڵ ڕێگەت پێدەدات لە بەشە بەرزەکان (بە نمرەی کەمتر) وەربگیرێیت.');
      buffer.writeln('• وەزارەتی خوێندنی باڵا %40 داشکاندنی فەرمی بۆ تێچووی ساڵانەی پاڕاڵێڵ دەستنیشان کردووە.');
    } else {
      buffer.writeln('• بەپێی ئارەزووی خۆت و نزیکی شارەکەت، بەشەکان لە پێشینەی ٥٠ بەشەکەی زانکۆلاین بڕێزێنە.');
    }
    buffer.writeln('• تێبینی: دەتوانیت بەشەکان لە لیستی خوارەوە بە وردی بپشکنیت.');

    return buffer.toString();
  }

  int _matchedDepartmentsCount(List<ZankolineDepartmentModel> list) => list.length;
}
