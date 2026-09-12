// ==============================================================================
// ZankoAI Academic History Sheet — Supabase Backend Saved Reports & Seminars
// ==============================================================================

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/academic_report_seminar_model.dart';
import '../services/report_seminar_service.dart';
import '../theme.dart';

class AcademicHistorySheet extends StatefulWidget {
  final bool initialIsSeminar;
  final bool isDark;
  final String? currentFontFamily;
  final Function(AcademicSeminarRecord seminar) onLoadSeminar;
  final Function(AcademicReportRecord report) onLoadReport;

  const AcademicHistorySheet({
    super.key,
    required this.initialIsSeminar,
    required this.isDark,
    this.currentFontFamily,
    required this.onLoadSeminar,
    required this.onLoadReport,
  });

  @override
  State<AcademicHistorySheet> createState() => _AcademicHistorySheetState();
}

class _AcademicHistorySheetState extends State<AcademicHistorySheet> {
  late bool _isSeminarTab;
  bool _isLoading = true;
  List<AcademicSeminarRecord> _seminars = [];
  List<AcademicReportRecord> _reports = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isSeminarTab = widget.initialIsSeminar;
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final s = await ReportSeminarService.instance.getSeminars();
      final r = await ReportSeminarService.instance.getReports();

      if (mounted) {
        setState(() {
          _seminars = s;
          _reports = r;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteSeminar(AcademicSeminarRecord seminar) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'سڕینەوەی سیمینار',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: widget.currentFontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'دڵنیایت لە سڕینەوەی سیمیناری "${seminar.title}"؟ ئەم کردارە ناگەڕێتەوە.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: widget.currentFontFamily,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'سڕینەوە',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ReportSeminarService.instance.deleteSeminar(seminar.id);
      setState(() {
        _seminars.removeWhere((s) => s.id == seminar.id);
      });
    }
  }

  Future<void> _confirmDeleteReport(AcademicReportRecord report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'سڕینەوەی ڕاپۆرت',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: widget.currentFontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'دڵنیایت لە سڕینەوەی ڕاپۆرتی "${report.title}"؟ ئەم کردارە ناگەڕێتەوە.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: widget.currentFontFamily,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('پاشگەزبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'سڕینەوە',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ReportSeminarService.instance.deleteReport(report.id);
      setState(() {
        _reports.removeWhere((r) => r.id == report.id);
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  String _getLanguageBadge(String code) {
    switch (code) {
      case 'en':
        return '🇬🇧 English';
      case 'ar':
        return '🇸🇦 العربية';
      case 'badini':
        return '🏔️ بادینی';
      case 'ku':
      default:
        return '☀️ سۆرانی';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final themeColor = _isSeminarTab
        ? const Color(0xFF7D2AE8) // Purple
        : const Color(0xFFF97316); // Orange

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkBackground : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    CupertinoIcons.time_solid,
                    color: themeColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مێژووی پاشەکەوتکراوی ئەکادیمی',
                        style: TextStyle(
                          fontFamily: widget.currentFontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : ZankoColors.textPrimary,
                        ),
                      ),
                      Text(
                        'سیمینار و ڕاپۆرتە تۆمارکراوەکانت لە Supabase',
                        style: TextStyle(
                          fontFamily: widget.currentFontFamily,
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.grey[400]
                              : ZankoColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    CupertinoIcons.clear_circled_solid,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Two-Mode Selector (سیمینارەکان / ڕاپۆرتەکان)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSeminarTab = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isSeminarTab
                              ? const Color(0xFF7D2AE8)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isSeminarTab
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF7D2AE8,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.paintbrush_fill,
                              size: 15,
                              color: _isSeminarTab ? Colors.white : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'سیمینارەکان (${_seminars.length})',
                              style: TextStyle(
                                fontFamily: widget.currentFontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: _isSeminarTab
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.grey[400]
                                          : ZankoColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isSeminarTab = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isSeminarTab
                              ? const Color(0xFFF97316)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: !_isSeminarTab
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFF97316,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.doc_text_fill,
                              size: 15,
                              color: !_isSeminarTab
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ڕاپۆرتەکان (${_reports.length})',
                              style: TextStyle(
                                fontFamily: widget.currentFontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: !_isSeminarTab
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.grey[400]
                                          : ZankoColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(radius: 14))
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: Colors.amber,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'هەڵە لە وەرگرتنی مێژوو: $_errorMessage',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: widget.currentFontFamily,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetchHistory,
                            child: const Text('دووبارە هەوڵبدەرەوە'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isSeminarTab
                ? _buildSeminarsList(isDark)
                : _buildReportsList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSeminarsList(bool isDark) {
    if (_seminars.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.paintbrush_fill,
        title: 'هیچ سیمینارێکی پاشەکەوتکراو نییە',
        subtitle: 'کاتێک سیمینارێک دروست دەکەیت، ئۆتۆماتیکی لێرە تۆمار دەبێت.',
        color: const Color(0xFF7D2AE8),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _seminars.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final item = _seminars[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey[200]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7D2AE8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.tv_fill,
                      color: Color(0xFF7D2AE8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontFamily: widget.currentFontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : ZankoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getLanguageBadge(item.language),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(item.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmDeleteSeminar(item),
                    icon: const Icon(
                      CupertinoIcons.trash,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onLoadSeminar(item);
                  },
                  icon: const Icon(
                    CupertinoIcons.arrow_up_right_circle_fill,
                    size: 16,
                  ),
                  label: Text(
                    'کردنەوە و دەستکاریکردن',
                    style: TextStyle(
                      fontFamily: widget.currentFontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7D2AE8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportsList(bool isDark) {
    if (_reports.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.doc_text_fill,
        title: 'هیچ ڕاپۆرتێکی پاشەکەوتکراو نییە',
        subtitle: 'کاتێک ڕاپۆرتێک دروست دەکەیت، ئۆتۆماتیکی لێرە تۆمار دەبێت.',
        color: const Color(0xFFF97316),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _reports.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final item = _reports[idx];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? ZankoColors.darkCard : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey[200]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.doc_fill,
                      color: Color(0xFFF97316),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontFamily: widget.currentFontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : ZankoColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getLanguageBadge(item.language),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(item.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _confirmDeleteReport(item),
                    icon: const Icon(
                      CupertinoIcons.trash,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onLoadReport(item);
                  },
                  icon: const Icon(
                    CupertinoIcons.arrow_up_right_circle_fill,
                    size: 16,
                  ),
                  label: Text(
                    'کردنەوە و دەستکاریکردن',
                    style: TextStyle(
                      fontFamily: widget.currentFontFamily,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isDark = widget.isDark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: widget.currentFontFamily,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: widget.currentFontFamily,
                fontSize: 12,
                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
