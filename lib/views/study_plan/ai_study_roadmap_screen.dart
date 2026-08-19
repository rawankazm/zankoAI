import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/ai_service.dart';
import '../../services/study_roadmap_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../../services/database_service.dart';
import '../../services/docx_generator_service.dart';

class AiStudyRoadmapScreen extends StatefulWidget {
  const AiStudyRoadmapScreen({super.key});

  @override
  State<AiStudyRoadmapScreen> createState() => _AiStudyRoadmapScreenState();
}

class _AiStudyRoadmapScreenState extends State<AiStudyRoadmapScreen> {
  int _selectedRoadmapIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StudyRoadmapService.instance.loadRoadmaps();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    final roadmapService = StudyRoadmapService.instance;

    return ListenableBuilder(
      listenable: roadmapService,
      builder: (context, _) {
        final roadmaps = roadmapService.roadmaps;
        final currentRoadmap = roadmaps.isNotEmpty && _selectedRoadmapIndex < roadmaps.length
            ? roadmaps[_selectedRoadmapIndex]
            : null;

        return Scaffold(
          backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
          appBar: AppBar(
            backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
            elevation: 0,
            title: Text(
              langProvider.translate('study_roadmap'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            actions: [
              if (roadmaps.isNotEmpty)
                IconButton(
                  icon: const Icon(CupertinoIcons.doc_arrow_down_fill, color: ZankoColors.primary, size: 24),
                  tooltip: 'Word (.docx)',
                  onPressed: () {
                    final current = roadmaps[_selectedRoadmapIndex];
                    DocxGeneratorService.exportRoadmapToDocx(
                      subjectName: current.subjectName,
                      daysLeft: current.daysLeft,
                      tasks: current.tasks
                          .map((t) => {'day': t.dayIndex, 'title': t.title, 'desc': t.description})
                          .toList(),
                    );
                  },
                ),
              IconButton(
                icon: Icon(CupertinoIcons.add_circled_solid, color: ZankoColors.primary, size: 26),
                tooltip: langProvider.translate('create_roadmap'),
                onPressed: () => _openCreateRoadmapModal(context),
              ),
            ],
          ),
          body: SafeArea(
            child: roadmaps.isEmpty
                ? _buildEmptyState(context, isDark, langProvider)
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Roadmap Selector Chips (if multiple roadmaps exist) ──
                        if (roadmaps.length > 1) ...[
                          SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: roadmaps.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, idx) {
                                final rm = roadmaps[idx];
                                final isSelected = idx == _selectedRoadmapIndex;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedRoadmapIndex = idx),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isSelected ? ZankoColors.primary : (isDark ? const Color(0xFF1E222A) : Colors.white),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isSelected ? ZankoColors.primary : (isDark ? Colors.white10 : Colors.grey[300]!),
                                      ),
                                    ),
                                    child: Text(
                                      rm.subjectName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : ZankoColors.textPrimary),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (currentRoadmap != null) ...[
                          // ── Active Exam Countdown & Progress Header ──
                          _buildExamCountdownHeader(context, currentRoadmap, isDark),

                          const SizedBox(height: 20),

                          // ── AI Advice Note Card ──
                          if (currentRoadmap.advice.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: ZankoColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Text('💡', style: TextStyle(fontSize: 22)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      currentRoadmap.advice,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: isDark ? Colors.purple[100] : const Color(0xFF5B21B6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '📋 نەخشەڕێگای ڕۆژانە',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${(currentRoadmap.progressPercentage * 100).toInt()}% تەواوکراوە',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: ZankoColors.primary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // ── Day-by-Day Timeline List ──
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: currentRoadmap.tasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final task = currentRoadmap.tasks[idx];
                              return _buildTaskTimelineTile(context, currentRoadmap.id, task, isDark, roadmapService);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, LanguageProvider langProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.calendar_badge_plus, size: 64, color: ZankoColors.primary),
            const SizedBox(height: 16),
            Text(
              'هیچ نەخشەڕێگایەک دروست نەکراوە',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ناونیوانی وانەکەت و ڕۆژانی ماوە دابنێ تا ژیریی دەستکرد پلانێکی تۆکمەت بۆ بنووسێت.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openCreateRoadmapModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZankoColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(CupertinoIcons.sparkles),
              label: Text(
                langProvider.translate('create_roadmap'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCountdownHeader(BuildContext context, StudyRoadmapModel rm, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ZankoColors.darkCardSecondary, const Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.flame_fill, color: Color(0xFFEF4444), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '🔥 ${rm.daysLeft} ڕۆژ ماوە بۆ تاقیکردنەوە',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(CupertinoIcons.trash, color: Colors.white54, size: 18),
                onPressed: () async {
                  await StudyRoadmapService.instance.deleteRoadmap(rm.id);
                  if (mounted) setState(() => _selectedRoadmapIndex = 0);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rm.subjectName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${rm.totalChapters} بەش • ڕۆژانە ${rm.hoursPerDay} کاتژمێر خوێندن',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                      value: rm.progressPercentage,
                      strokeWidth: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                  Text(
                    '${(rm.progressPercentage * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTimelineTile(
    BuildContext context,
    String roadmapId,
    StudyTaskModel task,
    bool isDark,
    StudyRoadmapService service,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (_) async {
              await service.toggleTaskCompleted(roadmapId, task.id);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ڕۆژی ${task.dayIndex}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ZankoColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : ZankoColors.textPrimary,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  task.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(CupertinoIcons.timer, size: 14, color: Color(0xFFFF9F0A)),
                    const SizedBox(width: 4),
                    Text(
                      '${task.suggestedPomodoros} سێشنی فۆکەس (Pomodoro)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFFF9F0A), fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        final db = Provider.of<DatabaseService>(context, listen: false);
                        db.incrementPomodoros();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('سێشنی فۆکەسی Pomodoro (٢٥ خولەک) دەستی پێکرد! ⏱️'),
                            backgroundColor: Color(0xFFFF9F0A),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9F0A).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'دەستپێکردن ⏱️',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF9F0A)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCreateRoadmapModal(BuildContext context) {
    final subjectController = TextEditingController();
    int totalChapters = 5;
    int daysRemaining = 7;
    int hoursPerDay = 3;
    bool isGenerating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF15181E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🪄 دروستکردنی پلانی خوێندن',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.white54),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: subjectController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'ناوی وانە / بابەت (نموونە: داتابەیس)',
                        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF1E222A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ژمارەی بەشەکان (Chapters):', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('$totalChapters بەش', style: TextStyle(color: ZankoColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: totalChapters.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      activeColor: ZankoColors.primary,
                      onChanged: (val) => setModalState(() => totalChapters = val.toInt()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ڕۆژانی ماوە بۆ تاقیکردنەوە:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('$daysRemaining ڕۆژ', style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: daysRemaining.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: const Color(0xFFEF4444),
                      onChanged: (val) => setModalState(() => daysRemaining = val.toInt()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('کاتژمێری خوێندن لە ڕۆژێکدا:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('$hoursPerDay کاتژمێر', style: const TextStyle(color: Color(0xFFFF9F0A), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: hoursPerDay.toDouble(),
                      min: 1,
                      max: 8,
                      divisions: 7,
                      activeColor: const Color(0xFFFF9F0A),
                      onChanged: (val) => setModalState(() => hoursPerDay = val.toInt()),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isGenerating
                          ? null
                          : () async {
                              final name = subjectController.text.trim();
                              if (name.isEmpty) return;

                              setModalState(() => isGenerating = true);
                              final aiService = Provider.of<AiService>(context, listen: false);

                              try {
                                final res = await aiService.generateStudyRoadmap(
                                  subjectName: name,
                                  totalChapters: totalChapters,
                                  daysRemaining: daysRemaining,
                                  hoursPerDay: hoursPerDay,
                                );

                                final List<dynamic> rawTasks = res['tasks'] ?? [];
                                final tasks = rawTasks.map((t) {
                                  return StudyTaskModel(
                                    id: 't_${DateTime.now().millisecondsSinceEpoch}_${t['dayIndex']}',
                                    dayIndex: t['dayIndex'] ?? 1,
                                    title: t['title'] ?? '',
                                    description: t['description'] ?? '',
                                    suggestedPomodoros: t['suggestedPomodoros'] ?? 2,
                                  );
                                }).toList();

                                final newRoadmap = StudyRoadmapModel(
                                  id: 'rm_${DateTime.now().millisecondsSinceEpoch}',
                                  subjectName: name,
                                  examDate: DateTime.now().add(Duration(days: daysRemaining)),
                                  totalChapters: totalChapters,
                                  hoursPerDay: hoursPerDay,
                                  tasks: tasks,
                                  advice: res['advice'] ?? '',
                                );

                                await StudyRoadmapService.instance.saveRoadmap(newRoadmap);

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  setState(() => _selectedRoadmapIndex = 0);
                                }
                              } catch (_) {
                                setModalState(() => isGenerating = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZankoColors.primary,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isGenerating
                          ? const CupertinoActivityIndicator(color: Colors.white)
                          : const Text(
                              'داڕشتنی پلانی خوێندن 🪄',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
