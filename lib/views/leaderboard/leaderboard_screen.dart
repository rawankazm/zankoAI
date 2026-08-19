import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/score_service.dart';
import '../../services/leaderboard_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedTabIndex = 0; // 0 = All Departments, 1 = By Department
  String? _selectedDepartment;
  List<String> _departmentList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDepartments();
    });
  }

  Future<void> _loadDepartments() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final depts = await LeaderboardService.instance.getRegisteredDepartments(currentUser: currentUser);

    if (mounted) {
      setState(() {
        _departmentList = depts;
        _selectedDepartment = currentUser?.departmentName ?? (depts.isNotEmpty ? depts.first : 'ئەندازیاری سیستەمی زانیاری');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final scoreService = Provider.of<ScoreService>(context);
    final leaderboardService = LeaderboardService.instance;

    final currentUser = authService.currentUser;
    final badges = leaderboardService.getBadges(scoreService);

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          langProvider.translate('leaderboard_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: FutureBuilder<List<StudentRankModel>>(
          future: leaderboardService.getLeaderboard(
            currentUser: currentUser,
            scoreService: scoreService,
            selectedDepartment: _selectedTabIndex == 1 ? _selectedDepartment : null,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }

            final rankings = snapshot.data ?? [];
            final top1 = rankings.isNotEmpty ? rankings[0] : null;
            final top2 = rankings.length > 1 ? rankings[1] : null;
            final top3 = rankings.length > 2 ? rankings[2] : null;
            final restRankings = rankings.length > 3 ? rankings.sublist(3) : <StudentRankModel>[];

            StudentRankModel? myRankModel;
            try {
              myRankModel = rankings.firstWhere((e) => e.isCurrentUser);
            } catch (_) {}

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // ── Header Summary Card (Streak & Badges) ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF4834D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('🔥', style: TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${leaderboardService.streakDays} ${langProvider.translate('streak_days')}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'بەردەوامی لەسەر خوێندن',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Text('⭐', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Text(
                                  myRankModel != null ? '${myRankModel.points} XP' : '0 XP',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                      // Badges horizontal list
                      SizedBox(
                        height: 70,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: badges.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final b = badges[index];
                            return Container(
                              width: 130,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: b.isUnlocked
                                    ? Colors.white.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: b.isUnlocked ? Colors.white38 : Colors.white10,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(b.icon, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          b.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: b.isUnlocked ? Colors.white : Colors.white60,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: b.progress,
                                            minHeight: 4,
                                            backgroundColor: Colors.white24,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              b.isUnlocked ? const Color(0xFF55E6C1) : Colors.white38,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Tab Bar (1: All Depts vs 2: By Dept) ──
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222A) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 0
                                  ? ZankoColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                langProvider.translate('all_departments'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTabIndex == 0 ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 1
                                  ? ZankoColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                langProvider.translate('by_department'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTabIndex == 1 ? Colors.white : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Department Filter Chips (If Tab 2 Selected) ──
                if (_selectedTabIndex == 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _departmentList.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final dept = _departmentList[index];
                        final isSelected = dept == _selectedDepartment;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDepartment = dept),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? ZankoColors.primary : (isDark ? const Color(0xFF252934) : Colors.white),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? ZankoColors.primary : (isDark ? Colors.white10 : Colors.grey[300]!),
                              ),
                            ),
                            child: Text(
                              dept,
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
                ],

                const SizedBox(height: 24),

                // ── Top 3 Podium Winners ──
                if (rankings.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 2nd Place (Left)
                      if (top2 != null)
                        _buildPodiumItem(
                          context,
                          model: top2,
                          crown: '🥈',
                          badgeColor: const Color(0xFFA0A0A0),
                          height: 120,
                          isDark: isDark,
                        ),

                      const SizedBox(width: 12),

                      // 1st Place (Center - Highest)
                      if (top1 != null)
                        _buildPodiumItem(
                          context,
                          model: top1,
                          crown: '🥇',
                          badgeColor: const Color(0xFFFFD700),
                          height: 145,
                          isDark: isDark,
                          isCenter: true,
                        ),

                      const SizedBox(width: 12),

                      // 3rd Place (Right)
                      if (top3 != null)
                        _buildPodiumItem(
                          context,
                          model: top3,
                          crown: '🥉',
                          badgeColor: const Color(0xFFCD7F32),
                          height: 105,
                          isDark: isDark,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],

                // ── My Current Rank Header Badge ──
                if (myRankModel != null) ...[
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: ZankoColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '#${myRankModel.rank}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ZankoColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${langProvider.translate('my_rank')}: ${myRankModel.name}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${myRankModel.departmentName} • 🔥 ${myRankModel.streak} ڕۆژ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${myRankModel.points} XP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: ZankoColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Remaining Rankings List (4th onwards) ──
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: restRankings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final student = restRankings[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: student.isCurrentUser
                            ? ZankoColors.primary.withValues(alpha: 0.18)
                            : (isDark ? const Color(0xFF1E222A) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: student.isCurrentUser
                              ? ZankoColors.primary
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0)),
                          width: student.isCurrentUser ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              '#${student.rank}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: student.isCurrentUser
                                    ? ZankoColors.primary
                                    : (isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: ZankoColors.primary.withValues(alpha: 0.2),
                            child: Text(
                              student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: ZankoColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '${student.departmentName} • 🔥 ${student.streak} ڕۆژ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${student.points} XP',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPodiumItem(
    BuildContext context, {
    required StudentRankModel model,
    required String crown,
    required Color badgeColor,
    required double height,
    required bool isDark,
    bool isCenter = false,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(crown, style: TextStyle(fontSize: isCenter ? 26 : 20)),
          const SizedBox(height: 4),
          CircleAvatar(
            radius: isCenter ? 26 : 22,
            backgroundColor: badgeColor.withValues(alpha: 0.3),
            child: Text(
              model.name.isNotEmpty ? model.name[0].toUpperCase() : 'S',
              style: TextStyle(
                fontSize: isCenter ? 18 : 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            model.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCenter ? 13 : 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : ZankoColors.textPrimary,
            ),
          ),
          Text(
            '${model.points} XP',
            style: TextStyle(
              fontSize: isCenter ? 11 : 10,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: height,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  badgeColor.withValues(alpha: 0.6),
                  badgeColor.withValues(alpha: 0.2),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Center(
              child: Text(
                '#${model.rank}',
                style: TextStyle(
                  fontSize: isCenter ? 24 : 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
