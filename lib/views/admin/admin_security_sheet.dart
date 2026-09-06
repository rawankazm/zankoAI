import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class AdminSecuritySheet extends StatefulWidget {
  const AdminSecuritySheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminSecuritySheet(),
    );
  }

  @override
  State<AdminSecuritySheet> createState() => _AdminSecuritySheetState();
}

class _AdminSecuritySheetState extends State<AdminSecuritySheet> {
  String _activeTab = 'alerts'; // 'alerts', 'blocked', 'search'
  final Map<String, bool> _processingIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is DateTime) {
      final date = timestamp;
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (timestamp is String) {
      final date = DateTime.tryParse(timestamp);
      if (date != null) {
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    }
    return '';
  }

  /// Block user from app
  Future<void> _blockUser({
    required String userId,
    required String userName,
    String? alertId,
    String? customReason,
  }) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final adminEmail = auth.currentUser?.email ?? 'admin';
    final reasonCtrl = TextEditingController(text: customReason ?? 'بلۆک کرایت بەهۆی تێپەڕاندنی سنووری ٣ ناونیشانی IP و هاوبەشکردنی ئەکاونت.');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Colors.redAccent, size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'بلۆککردنی بەکارهێنەر ⛔',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ئایا دڵنیایت دەتەوێت هەژماری "$userName" بلۆک بکەیت؟ چیتر ناتوانێت هیچ بەشێکی ئەپەکە بەکاربهێنێت.',
              style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'هۆکاری بلۆککردن',
                labelStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('پاشگەزبوونەوە', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('بەڵێ، بلۆکی بکە', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final actionKey = alertId ?? userId;
    setState(() => _processingIds[actionKey] = true);

    try {
      final reason = reasonCtrl.text.trim();

      // 1. Update user document
      await Supabase.instance.client.from('profiles').update({
        'status': 'suspended',
      }).eq('id', userId);

      // 2. Log audit event
      await Supabase.instance.client.from('audit_logs').insert({
        'user_id': userId,
        'action': 'USER_BLOCKED',
        'entity_type': 'user',
        'entity_id': userId,
        'payload': {'reason': reason, 'blockedBy': adminEmail},
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⛔ بەکارهێنەر $userName بە سەرکەوتوویی بلۆک کرا.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ کێشەیەک ڕوویدا لە بلۆککردن: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(actionKey));
    }
  }

  /// Unblock user from app
  Future<void> _unblockUser({
    required String userId,
    required String userName,
    String? alertId,
  }) async {
    final actionKey = alertId ?? userId;
    setState(() => _processingIds[actionKey] = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final adminEmail = auth.currentUser?.email ?? 'admin';

      await Supabase.instance.client.from('profiles').update({
        'status': 'active',
      }).eq('id', userId);

      await Supabase.instance.client.from('audit_logs').insert({
        'user_id': userId,
        'action': 'USER_UNBLOCKED',
        'entity_type': 'user',
        'entity_id': userId,
        'payload': {'unblockedBy': adminEmail},
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ بلۆکی هەژماری $userName لادرا و چالاککرایەوە.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ کێشەیەک ڕوویدا: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(actionKey));
    }
  }

  /// Reset IP Addresses and approve user login
  Future<void> _approveAndResetIps({
    required String userId,
    required String userName,
    required String alertId,
    String? newIp,
  }) async {
    setState(() => _processingIds[alertId] = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final adminEmail = auth.currentUser?.email ?? 'admin';

      // 1. Reset user blocked status
      await Supabase.instance.client.from('profiles').update({
        'status': 'active',
      }).eq('id', userId);

      // 2. Mark audit log
      await Supabase.instance.client.from('audit_logs').insert({
        'user_id': userId,
        'action': 'IP_RESET_APPROVED',
        'entity_type': 'user',
        'entity_id': userId,
        'payload': {'newIp': newIp, 'approvedBy': adminEmail},
      });

      // 3. Send notification to user
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'title': '✅ داواکاریی IP پەسەندکرا',
        'body': 'داواکارییەکەت لەلایەن بەڕێوەبەرەوە پەسەندکرا و ناونیشانی IP نوێکرایەوە. دەتوانیت ئێستا بە ئاسایی بچیتە ژوورەوە.',
        'type': 'security_approved',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ناونیشانی IPی $userName پاککرایەوە و ڕێگەی پێدرا.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ کێشەیەک ڕوویدا: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(alertId));
    }
  }

  /// Dismiss / Delete security alert
  Future<void> _dismissAlert(String alertId) async {
    try {
      await Supabase.instance.client.from('audit_logs').delete().eq('id', alertId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('داواکارییەکە سڕایەوە.'), duration: Duration(seconds: 2)),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13161C) : Colors.grey[50],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ─── Header ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: Colors.redAccent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'داواکارییەکانی ئاسایش و بلۆککردنی IP 🛡️',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'بەڕێوەبردنی سەرپێچییەکانی ٣ IP، مۆبایلی جیاواز و بلۆککردن',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ─── Tab Switcher ──────────────────────────────────────────
                  Row(
                    children: [
                      _buildTabButton('alerts', '🚨 داواکاری و ئاگادارییەکان', isDark),
                      const SizedBox(width: 8),
                      _buildTabButton('blocked', '⛔ بەکارهێنەرە بلۆککراوەکان', isDark),
                      const SizedBox(width: 8),
                      _buildTabButton('search', '🔍 گەڕانی بەکارهێنەر', isDark),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Body Content ──────────────────────────────────────────────────
            Expanded(
              child: _activeTab == 'alerts'
                  ? _buildAlertsTab(isDark)
                  : (_activeTab == 'blocked' ? _buildBlockedUsersTab(isDark) : _buildSearchTab(isDark)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label, bool isDark) {
    final isSelected = _activeTab == tabKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = tabKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? (tabKey == 'blocked' ? Colors.redAccent : const Color(0xFF7D2AE8))
                : (isDark ? const Color(0xFF282E3A) : Colors.grey[200]),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 1. ALERTS TAB ─────────────────────────────────────────────────────────
  Widget _buildAlertsTab(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('audit_logs')
          .stream(primaryKey: ['id'])
          .eq('action', 'IP_LIMIT_APPEAL'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('کێشەیەک لە بارکردنی زانیارییەکان ڕوویدا: ${snapshot.error}', style: const TextStyle(color: Colors.grey)),
          );
        }

        final pendingDocs = snapshot.data ?? [];

        if (pendingDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_rounded, size: 64, color: Colors.green.withValues(alpha: 0.6)),
                const SizedBox(height: 14),
                const Text(
                  'هیچ داواکاری یان سەرپێچییەکی نوێی ئاسایش نییە 🎉',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'هەموو بەکارهێنەران لە چوارچێوەی یاساکانی ١ ئامێر و ٣ IP کار دەکەن.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pendingDocs.length,
          itemBuilder: (context, index) {
            final data = pendingDocs[index];
            final payload = (data['payload'] as Map<String, dynamic>?) ?? {};
            final alertId = data['id']?.toString() ?? '';
            final userId = (data['user_id'] ?? payload['userId'] ?? '').toString();
            final userName = (payload['name'] ?? 'خوێندکار').toString();
            final email = (payload['email'] ?? '').toString();
            final attemptedIp = (payload['attemptedIp'] ?? '').toString();
            final reason = (payload['reason'] ?? 'تێپەڕاندنی سنووری ٣ IP').toString();
            final userNote = payload['userNote'] as String?;
            final dateStr = _formatDate(data['created_at']);
            final rawKnownIps = data['knownIps'];
            List<String> knownIps = [];
            if (rawKnownIps is List) {
              knownIps = rawKnownIps.map((e) => e.toString()).toList();
            }

            final isProcessing = _processingIds[alertId] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(CupertinoIcons.person_crop_circle_badge_exclam, color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              email,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'تێپەڕاندنی 3 IP ⛔',
                          style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Violation Reason
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text('هۆکار: $reason', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber)),
                      ],
                    ),
                  ),

                  // Attempt Details
                  if (attemptedIp.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          const Text('IPی چوارەم (هەوڵدراو): ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(attemptedIp, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ],
                      ),
                    ),

                  if (knownIps.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('IPە تۆمارکراوەکان: ', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                          ...knownIps.map((ip) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(ip, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              )),
                        ],
                      ),
                    ),

                  if (userNote != null && userNote.trim().isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF282E3A) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 15, color: Colors.blueAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'داواکاریی خوێندکار: $userNote',
                              style: const TextStyle(fontSize: 12, color: Colors.blueAccent, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (dateStr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('📅 کات: $dateStr', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                    ),

                  const SizedBox(height: 14),

                  // Action Buttons
                  if (isProcessing)
                    const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                  else
                    Row(
                      children: [
                        // 1. Block Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _blockUser(
                              userId: userId,
                              userName: userName,
                              alertId: alertId,
                              customReason: 'بلۆک کرایت بەهۆی هەوڵدان بۆ تێپەڕاندنی سنووری ٣ IP و هاوبەشکردنی ئەکاونت.',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.block_rounded, size: 16),
                            label: const Text('بلۆککردن ⛔', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 2. Approve & Reset IP Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _approveAndResetIps(
                              userId: userId,
                              userName: userName,
                              alertId: alertId,
                              newIp: attemptedIp,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_rounded, size: 16),
                            label: const Text('پاککردنەوەی IP ✅', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3. Delete Alert Button
                        IconButton(
                          onPressed: () => _dismissAlert(alertId),
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                          tooltip: 'سڕینەوەی داواکاری',
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── 2. BLOCKED USERS TAB ──────────────────────────────────────────────────
  Widget _buildBlockedUsersTab(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('status', 'suspended'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 60, color: Colors.grey),
                SizedBox(height: 12),
                Text('هیچ بەکارهێنەرێکی بلۆککراو نییە', style: TextStyle(fontSize: 15, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index];
            final userId = data['id']?.toString() ?? '';
            final userName = data['name'] as String? ?? 'خوێندکار';
            final email = data['email'] as String? ?? '';
            final blockReason = 'بلۆککراوە لەلایەن ئەدمین';
            final blockedAtStr = _formatDate(data['updated_at']);
            final isProcessing = _processingIds[userId] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                        Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('هۆکار: $blockReason', style: const TextStyle(fontSize: 11.5, color: Colors.redAccent)),
                        if (blockedAtStr.isNotEmpty)
                          Text('📅 $blockedAtStr', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isProcessing)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    ElevatedButton(
                      onPressed: () => _unblockUser(userId: userId, userName: userName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('لابردنی بلۆک 🔓', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── 3. USER SEARCH & INSTANT BLOCK TAB ────────────────────────────────────
  Widget _buildSearchTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'گەڕان بەپێی ناوی خوێندکار یان ئیمەیڵ...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7D2AE8)),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E222B) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('profiles').stream(primaryKey: ['id']).limit(40),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data ?? [];
              final filteredDocs = allDocs.where((data) {
                if (_searchQuery.isEmpty) return true;
                final name = (data['name'] as String? ?? '').toLowerCase();
                final email = (data['email'] as String? ?? '').toLowerCase();
                return name.contains(_searchQuery) || email.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(
                  child: Text('هیچ بەکارهێنەرێک نەدۆزرایەوە.', style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index];
                  final userId = data['id']?.toString() ?? '';
                  final userName = data['name'] as String? ?? 'خوێندکار';
                  final email = data['email'] as String? ?? '';
                  final isBlocked = data['is_blocked'] == true;
                  final isVip = data['subscription_tier'] == 'VIP';
                  final role = data['role'] as String? ?? 'student';
                  final ipCount = 0;

                  final isProcessing = _processingIds[userId] == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E222B) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isBlocked ? Colors.redAccent.withValues(alpha: 0.4) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isBlocked
                              ? Colors.redAccent.withValues(alpha: 0.2)
                              : (isVip ? Colors.amber.withValues(alpha: 0.2) : const Color(0xFF7D2AE8).withValues(alpha: 0.15)),
                          child: Icon(
                            isBlocked ? Icons.block : (isVip ? Icons.star_rounded : Icons.person_rounded),
                            color: isBlocked ? Colors.redAccent : (isVip ? Colors.amber : const Color(0xFF7D2AE8)),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(userName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                                  if (role == 'admin') ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Admin', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                                    ),
                                  ],
                                ],
                              ),
                              Text(email, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text('🌐 ناونیشانی IP بەکارهاتوو: $ipCount / 3', style: const TextStyle(fontSize: 10.5, color: Colors.blueGrey)),
                            ],
                          ),
                        ),
                        if (isProcessing)
                          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        else if (role != 'admin') ...[
                          if (isBlocked)
                            ElevatedButton(
                              onPressed: () => _unblockUser(userId: userId, userName: userName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('لابردنی بلۆک', style: TextStyle(fontSize: 11)),
                            )
                          else
                            ElevatedButton(
                              onPressed: () => _blockUser(userId: userId, userName: userName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('بلۆککردن ⛔', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
