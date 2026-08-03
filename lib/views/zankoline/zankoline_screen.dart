import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/language_provider.dart';
import '../../services/zankoline_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class ZankolineScreen extends StatefulWidget {
  const ZankolineScreen({super.key});

  @override
  State<ZankolineScreen> createState() => _ZankolineScreenState();
}

class _ZankolineScreenState extends State<ZankolineScreen> {
  bool _isScientific = true;

  final Map<String, TextEditingController> _controllers = {
    'kurdish': TextEditingController(),
    'arabic': TextEditingController(),
    'english': TextEditingController(),
    'math': TextEditingController(),
    'physics': TextEditingController(),
    'chemistry': TextEditingController(),
    'biology': TextEditingController(),
  };

  double? _totalScore;
  double? _percentage;
  List<ZankolineDepartmentModel> _matchedDepartments = [];
  String? _aiAdvice;
  bool _isAiLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculateAndMatch() async {
    double total = 0;
    int count = 0;

    _controllers.forEach((key, controller) {
      final val = double.tryParse(controller.text.trim());
      if (val != null) {
        total += val;
        count++;
      }
    });

    if (count == 0) return;

    final maxTotal = count * 100.0;
    final percentage = (total / maxTotal) * 100.0;
    final track = _isScientific ? 'scientific' : 'literary';

    final zankolineService = Provider.of<ZankolineService>(context, listen: false);
    final matched = zankolineService.filterMatchingDepartments(percentage, track);

    setState(() {
      _totalScore = total;
      _percentage = percentage;
      _matchedDepartments = matched;
      _aiAdvice = null;
      _isAiLoading = true;
    });

    final aiAdvice = await zankolineService.askZankolineAiAdvisor(percentage, track, matched);

    if (mounted) {
      setState(() {
        _aiAdvice = aiAdvice;
        _isAiLoading = false;
      });
    }
  }

  Future<void> _openZankolinePortal() async {
    final uri = Uri.parse('https://www.regayzanko.com');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          t('zankoline'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // ─── Zankoline Top Hero Banner ───
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF4338CA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('zankoline'),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t('zankoline_subtitle'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _openZankolinePortal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E1B4B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(double.infinity, 46),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                    label: Text(
                      t('zankoline_portal'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 12th Grade Mark Calculator Card ───
            Text(
              t('zankoline_calculator'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isScientific = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _isScientific ? ZankoColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'پۆلی ۱۲ - زانستی',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isScientific ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isScientific = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_isScientific ? ZankoColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'پۆلی ۱۲ - وێژەیی',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !_isScientific ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  _buildSubjectInput('کوردی (Kurdish)', _controllers['kurdish']!),
                  _buildSubjectInput('عەرەبی (Arabic)', _controllers['arabic']!),
                  _buildSubjectInput('ئینگلیزی (English)', _controllers['english']!),
                  _buildSubjectInput('بیرکاری (Mathematics)', _controllers['math']!),
                  if (_isScientific) ...[
                    _buildSubjectInput('فیزیا (Physics)', _controllers['physics']!),
                    _buildSubjectInput('کیمیا (Chemistry)', _controllers['chemistry']!),
                    _buildSubjectInput('زیندەوەرناسی (Biology)', _controllers['biology']!),
                  ],

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _calculateAndMatch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'ئەژمارکردن و ڕاوێژکاری زانکۆلاین',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),

                  if (_percentage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('کۆی گشتی نمرە', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                '${_totalScore?.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: ZankoColors.primary),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 36, color: Colors.grey.withValues(alpha: 0.3)),
                          Column(
                            children: [
                              const Text('تێکڕای ڕێژەی سەدی', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                '${_percentage?.toStringAsFixed(2)}%',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF34C759)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ─── AI Advisor Kurdish Guidance ───
            if (_isAiLoading || _aiAdvice != null) ...[
              const SizedBox(height: 24),
              Text(
                'ڕاوێژکاری زیرەکی زانکۆلاین (AI Advisor)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: _isAiLoading
                    ? const Row(
                        children: [
                          CupertinoActivityIndicator(),
                          SizedBox(width: 14),
                          Text('AI داواکارییەکەت شیدەکاتەوە...'),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.sparkles, color: ZankoColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'شیکاری و پێشنیاری مامۆستا AI',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ZankoColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _aiAdvice ?? '',
                            style: const TextStyle(fontSize: 13, height: 1.6),
                          ),
                        ],
                      ),
              ),
            ],

            // ─── Matched KRG Departments ───
            if (_matchedDepartments.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                t('department_matcher'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ..._matchedDepartments.map((dept) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ZankoColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'لانی کەم: ${dept.minMark}%',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ZankoColors.primary),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  dept.city,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            dept.college,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dept.university,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dept.description,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectInput(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '100 - 0',
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
