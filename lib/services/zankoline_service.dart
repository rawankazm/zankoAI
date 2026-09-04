import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  factory ZankolineDepartmentModel.fromJson(Map<String, dynamic> json, {String? docId}) {
    final collegeName = (json['department'] ?? json['college'] ?? '').toString();
    final rawMinMark = json['minScoreGeneral'] ?? json['min_mark'];
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

    final rawFee = json['yearlyFee'] ?? json['parallel_fee_iqd'];
    final int feeVal = rawFee != null ? (rawFee as num).toInt() : defaultFee;

    return ZankolineDepartmentModel(
      id: docId ?? (json['id'] ?? '').toString(),
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

  String formattedParallelFeeLocalized({bool isEnglish = false}) {
    final discountedMillions = discountedParallelFeeIqd / 1000000.0;

    if (isEnglish) {
      String formatValEn(double val) {
        if (val >= 1) {
          return val % 1 == 0 ? '${val.toStringAsFixed(0)}M' : '${val.toStringAsFixed(2)}M';
        }
        final thousands = (val * 1000).round();
        return '${thousands}K';
      }
      return '${formatValEn(discountedMillions)} IQD (after 45% discount)';
    }

    String formatValKu(double val) {
      if (val >= 1) {
        return val % 1 == 0 ? '${val.toStringAsFixed(0)} ملیۆن' : '${val.toStringAsFixed(2)} ملیۆن';
      }
      final thousands = (val * 1000).round();
      return '$thousands هەزار';
    }

    return '${formatValKu(discountedMillions)} دینار (دوای %45 داشکاندن)';
  }

  String get formattedParallelFee => formattedParallelFeeLocalized();
}

class ZankolineService extends ChangeNotifier {
  AiService? _aiService;
  List<ZankolineDepartmentModel> _departments = [];
  bool _isLoading = false;
  final Map<String, ZankolineDepartmentModel> _deptMap = {};

  ZankolineService([AiService? aiService]) : _aiService = aiService {
    loadDepartments();
    _listenToFirestoreDepartments();
  }

  void updateAiService(AiService? aiService) {
    _aiService = aiService;
  }

  bool get isLoading => _isLoading;
  List<ZankolineDepartmentModel> get departments => _departments;

  void _listenToFirestoreDepartments() {
    try {
      FirebaseFirestore.instance
          .collection('zankoline_departments')
          .get(const GetOptions(source: Source.serverAndCache))
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final item = ZankolineDepartmentModel.fromJson(data, docId: doc.id);
            _deptMap[doc.id] = item;
          }
          _departments = _deptMap.values.toList();
          notifyListeners();
        }
      }).catchError((err) {
        if (kDebugMode) print('Firestore zankoline fetch warning: $err');
      });
    } catch (_) {}
  }

  Future<void> loadDepartments() async {
    _isLoading = true;
    notifyListeners();
    try {
      final jsonStr = await rootBundle.loadString('assets/data/krg_zankoline.json');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      for (var e in jsonList) {
        final item = ZankolineDepartmentModel.fromJson(e);
        if (item.id.isNotEmpty) {
          _deptMap[item.id] = item;
        } else {
          _deptMap['${item.university}_${item.college}'] = item;
        }
      }
      _departments = _deptMap.values.toList();
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
      final deptTrack = dept.track.toLowerCase().trim();
      final targetTrack = track.toLowerCase().trim();
      final isTrackMatch = deptTrack == targetTrack ||
          deptTrack == 'all' ||
          deptTrack == 'common' ||
          deptTrack == 'both' ||
          deptTrack.isEmpty;
      if (!isTrackMatch) return false;

      if (isParallel) {
        final isParallelEligible = mark >= dept.parallelMinMark;
        final isTargetUpgrade = dept.minMark >= (mark - 1.0);
        return isParallelEligible && isTargetUpgrade;
      } else {
        return mark >= dept.minMark;
      }
    }).toList()
      ..sort((a, b) => b.minMark.compareTo(a.minMark));
  }

  Future<String> askZankolineAiAdvisor(
    double studentMark,
    String track,
    List<ZankolineDepartmentModel> matchedDepts, {
    bool isParallel = false,
    bool isEnglish = false,
  }) async {
    final trackName = isEnglish
        ? (track == 'scientific' ? 'Scientific' : 'Literary')
        : (track == 'scientific' ? 'زانستی' : 'وێژەیی');
    final systemModeName = isEnglish
        ? (isParallel ? 'Parallel Admission (45% Tuition Discount)' : 'General Admission (Free Tuition)')
        : (isParallel ? 'پاڕاڵێڵ (%45 داشکاندنی فەرمی)' : 'خوێندنی گشتی (بەخۆڕایی)');

    if (matchedDepts.isEmpty) {
      if (isEnglish) {
        return 'Based on your grade ($studentMark%) in the $trackName track under $systemModeName, no matching departments were found in the current cutoff database.';
      }
      return 'بەپێی تێکڕای نمرەکەت (%$studentMark) لە لقی $trackName لە سیستەمی $systemModeName، هیچ بەشێک نەدۆزرایەوە لە تۆماری ئێستادا.';
    }

    // Call real generative AI through AiService if connected
    if (_aiService != null) {
      try {
        final topDeptsList = matchedDepts
            .take(6)
            .map((d) => '${d.college} (${d.university})')
            .join(isEnglish ? ', ' : '، ');

        final prompt = isEnglish
            ? 'Act as an expert Kurdistan University admission advisor (Zankoline). '
              'A 12th-grade student with score $studentMark% in $trackName track is exploring options in $systemModeName. '
              'They qualify for ${matchedDepts.length} departments. Key matches: $topDeptsList. '
              'Provide 3-4 concise, highly practical academic bullet points in clean English advising their application strategy, competition, and priority choices.'
            : 'تۆ ڕاوێژکاری ئەکادیمی ژیری دەستکردی زانکۆلاینیت. '
              'قوتابییەکی پۆلی ١٢ بە تێکڕای %$studentMark لە لقی $trackName داواکاری پێشکەش دەکات لە سیستەمی $systemModeName. '
              'بۆ ${matchedDepts.length} بەش شایستەیە. لە دیارترینیان: $topDeptsList. '
              'بە زمانی کوردی (سۆرانی)، ٣ بۆ ٤ خاڵی زۆر بەسوود و کرداری و دڵسۆزانە پێشکەش بکە بۆ چۆنیەتی پڕکردنەوەی فۆڕمی زانکۆلاین و هەڵسەنگاندنی شایستەیی بەشەکان. کورت و ڕوون بێت.';

        final response = await _aiService!.askTeacher(prompt, []);
        if (response.trim().isNotEmpty &&
            !response.toLowerCase().contains('error') &&
            !response.toLowerCase().contains('failed')) {
          return response.trim();
        }
      } catch (e) {
        if (kDebugMode) print('Zankoline real AI query warning: $e');
      }
    }

    if (isEnglish) {
      return _buildLocalEnglishAdvisorSummary(studentMark, trackName, matchedDepts, isParallel: isParallel);
    }
    return _buildLocalKurdishAdvisorSummary(studentMark, trackName, matchedDepts, isParallel: isParallel);
  }

  String _buildLocalEnglishAdvisorSummary(double studentMark, String trackName, List<ZankolineDepartmentModel> matchedDepts, {bool isParallel = false}) {
    final buffer = StringBuffer();
    final systemLabel = isParallel ? 'Parallel Admission (45% Official Ministry Discount)' : 'General Admission (Free Tuition)';
    final topDepts = matchedDepts.take(3).map((d) => d.college).join(', ');

    buffer.writeln('Based on your grade ($studentMark%) in the $trackName track under ($systemLabel), you have competitive qualification chances across Kurdistan universities.');
    buffer.writeln('A total of ${matchedDepts.length} matching departments were found. Notable options: $topDepts.\n');

    buffer.writeln('💡 Advisor Guidance:');
    if (isParallel) {
      buffer.writeln('• Parallel admission allows admission into high-demand colleges with lower minimum cutoff scores.');
      buffer.writeln('• The KRG Ministry of Higher Education applies an official 45% discount on all annual parallel tuition fees.');
    } else {
      buffer.writeln('• Prioritize departments in your ZankoLine top 50 choices based on your academic interests and city location.');
    }
    buffer.writeln('• Explore the full list of matching departments below.');

    return buffer.toString();
  }

  String _buildLocalKurdishAdvisorSummary(double studentMark, String trackName, List<ZankolineDepartmentModel> matchedDepts, {bool isParallel = false}) {
    final buffer = StringBuffer();
    final systemLabel = isParallel ? 'سیستەمی پاڕاڵێڵ (%45 داشکاندنی فەرمی)' : 'خوێندنی گشتی (بەخۆڕایی)';
    final topDepts = matchedDepts.take(3).map((d) => d.college).join('، ');

    buffer.writeln('بەپێی تێکڕای نمرەکەت (%$studentMark) لە لقی $trackName لە ($systemLabel)، نمرەکەت هەلێکی زۆر باش دەبەخشێت بۆ وەرگرتن لە زانکۆکانی هەرێمی کوردستان.');
    buffer.writeln('کۆی ${_matchedDepartmentsCount(matchedDepts)} بەشی گونجاو دۆزرانەوە. لە دیارترینیان: $topDepts.\n');

    buffer.writeln('💡 ڕێنمایی ڕاوێژکار:');
    if (isParallel) {
      buffer.writeln('• بەکارهێنانی پاڕاڵێڵ ڕێگەت پێدەدات لە بەشە بەرزەکان (بە نمرەی کەمتر) وەربگیرێیت.');
      buffer.writeln('• وەزارەتی خوێندنی باڵا %45 داشکاندنی فەرمی بۆ تێچووی ساڵانەی پاڕاڵێڵ دەستنیشان کردووە.');
    } else {
      buffer.writeln('• بەپێی ئارەزووی خۆت و نزیکی شارەکەت، بەشەکان لە پێشینەی ٥٠ بەشەکەی زانکۆلاین بڕێزێنە.');
    }
    buffer.writeln('• تێبینی: دەتوانیت بەشەکان لە لیستی خوارەوە بە وردی بپشکنیت.');

    return buffer.toString();
  }

  int _matchedDepartmentsCount(List<ZankolineDepartmentModel> list) => list.length;
}
