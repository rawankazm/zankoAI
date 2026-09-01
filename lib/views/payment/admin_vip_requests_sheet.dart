import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';

class AdminVipRequestsSheet extends StatefulWidget {
  const AdminVipRequestsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminVipRequestsSheet(),
    );
  }

  @override
  State<AdminVipRequestsSheet> createState() => _AdminVipRequestsSheetState();
}

class _AdminVipRequestsSheetState extends State<AdminVipRequestsSheet> {
  String _filterStatus = 'pending'; // 'pending', 'approved', 'rejected', 'all'
  final Map<String, bool> _processingIds = {};

  int _getPlanDays(String? plan) {
    if (plan == '9_months' || plan == '9months') return 270;
    if (plan == 'yearly' || plan == 'annual') return 365;
    if (plan == '3_months' || plan == 'semester' || plan == '3months') return 90;
    return 30; // default 1_month / monthly
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  Future<void> _approveVipRequest({
    required String requestId,
    required String userId,
    required String userName,
    required String? plan,
    required dynamic existingExpiresAt,
  }) async {
    if (_processingIds[requestId] == true) return;
    setState(() => _processingIds[requestId] = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final adminEmail = auth.currentUser?.email ?? 'admin';
      final planDays = _getPlanDays(plan);

      Timestamp expiresAt;
      if (existingExpiresAt is Timestamp && existingExpiresAt.toDate().isAfter(DateTime.now())) {
        expiresAt = existingExpiresAt;
      } else {
        expiresAt = Timestamp.fromDate(DateTime.now().add(Duration(days: planDays)));
      }

      // 1. Update vip_requests doc
      await FirebaseFirestore.instance.collection('vip_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': adminEmail,
        'expiresAt': expiresAt,
      });

      // 2. Immediately update user document so auth stream instantly grants VIP
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'isVip': true,
        'vipStatus': 'active',
        'vipPlan': plan ?? 'monthly',
        'vipExpiresAt': expiresAt,
        'vipApprovedAt': FieldValue.serverTimestamp(),
        'vipApprovedBy': adminEmail,
      }, SetOptions(merge: true));

      // 3. Send instant private notification ONLY to this specific user
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'recipientId': userId,
        'target': 'user',
        'title': '🎉 پیرۆزە! هەژمارەکەت بوو بە VIP',
        'body': 'داواکاری بەشداریکردنی VIPەکەت لەلایەن بەڕێوەبەرەوە پەسەندکرا. ئێستا دەتوانیت لە هەموو تایبەتمەندییە بێسنوورەکانی ZankoAI سوودمەند بیت!',
        'type': 'vip_approved',
        'category': 'vip_approved',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Also write directly to user's private subcollection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': '🎉 پیرۆزە! هەژمارەکەت بوو بە VIP',
        'body': 'داواکاری بەشداریکردنی VIPەکەت لەلایەن بەڕێوەبەرەوە پەسەندکرا. ئێستا دەتوانیت لە هەموو تایبەتمەندییە بێسنوورەکانی ZankoAI سوودمەند بیت!',
        'type': 'vip_approved',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('✅ هەژماری $userName بە سەرکەوتوویی بوو بە VIP!'),
                ),
              ],
            ),
            backgroundColor: ZankoColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ کێشەیەک ڕوویدا لە پەسەندکردن: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(requestId));
    }
  }

  Future<void> _rejectVipRequest({
    required String requestId,
    required String userId,
    required String userName,
  }) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final adminEmail = auth.currentUser?.email ?? 'admin';
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'ڕەتکردنەوەی داواکاری VIP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ئایا دڵنیایت لە ڕەتکردنەوەی داواکارییەکەی $userName؟'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'هۆکاری ڕەتکردنەوە (ئارەزوومەندانە)...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ڕەتکردنەوە', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingIds[requestId] = true);
    final reason = reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'وەسڵی پارەدان یان ژمارەی حەواڵە نادروستە';

    try {

      // 1. Update vip_requests doc
      await FirebaseFirestore.instance.collection('vip_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': adminEmail,
        'rejectionReason': reason,
      });

      // 2. Update user doc
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'isVip': false,
        'vipStatus': 'rejected',
        'vipRejectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Send notification to user
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'recipientId': userId,
        'target': 'user',
        'title': '⚠️ ئاگاداری دەربارەی داواکاری VIP',
        'body': 'داواکاری بەشداریکردنی VIPەکەت پەسەند نەکرا. هۆکار: $reason',
        'type': 'vip_rejected',
        'category': 'vip_rejected',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('داواکارییەکەی $userName ڕەتکرایەوە'),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('کێشە: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(requestId));
    }
  }

  void _showReceiptDialog(String imageUrl, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'وەسڵی پارەدانی $userName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: imageUrl.startsWith('data:image/') || !imageUrl.startsWith('http')
                      ? (() {
                          try {
                            final base64Clean = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
                            final bytes = base64Decode(base64Clean);
                            return Image.memory(bytes, fit: BoxFit.contain, height: 400);
                          } catch (_) {
                            return const SizedBox(height: 150, child: Center(child: Text('⚠️ وێنەی وەسڵ نەکرایەوە')));
                          }
                        })()
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          height: 400,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const SizedBox(
                              height: 200,
                              child: Center(child: CupertinoActivityIndicator()),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => const SizedBox(
                            height: 150,
                            child: Center(
                              child: Text('⚠️ وێنەی وەسڵ نەکرایەوە'),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 دەتوانیت وێنەکە زووم (Pinch-to-zoom) بکەیت بۆ خوێندنەوەی ژمارەکان',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: lang.textDirection,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('vip_requests').snapshots(),
          builder: (context, snapshot) {
            final allDocs = List<DocumentSnapshot>.from(snapshot.data?.docs ?? []);
            
            final pendingDocs = allDocs.where((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              return (data['status'] as String? ?? 'pending').toLowerCase() == 'pending';
            }).toList();

            final approvedDocs = allDocs.where((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              return (data['status'] as String? ?? '').toLowerCase() == 'approved';
            }).toList();

            final rejectedDocs = allDocs.where((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              return (data['status'] as String? ?? '').toLowerCase() == 'rejected';
            }).toList();

            List<DocumentSnapshot> displayedDocs;
            if (_filterStatus == 'pending') {
              displayedDocs = pendingDocs;
            } else if (_filterStatus == 'approved') {
              displayedDocs = approvedDocs;
            } else if (_filterStatus == 'rejected') {
              displayedDocs = rejectedDocs;
            } else {
              displayedDocs = allDocs;
            }

            displayedDocs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>? ?? {};
              final bData = b.data() as Map<String, dynamic>? ?? {};
              final aTime = (aData['requestedAt'] as Timestamp?)?.toDate() ?? 
                            (aData['createdAt'] as Timestamp?)?.toDate() ?? 
                            DateTime.now();
              final bTime = (bData['requestedAt'] as Timestamp?)?.toDate() ?? 
                            (bData['createdAt'] as Timestamp?)?.toDate() ?? 
                            DateTime.now();
              return bTime.compareTo(aTime);
            });

            return Column(
              children: [
                // Handle Bar
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('👑', style: TextStyle(fontSize: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'بەڕێوەبردنی داواکارییەکانی VIP',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : ZankoColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'پەسەندکردنی ڕاستەوخۆی بەشداریکردنی قوتابیان',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : ZankoColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark_circle_fill, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Filter Tabs with Real-Time Counters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('pending', 'چاوەڕوانکراو (${pendingDocs.length})', Icons.hourglass_top_rounded, Colors.orange),
                      const SizedBox(width: 8),
                      _buildFilterChip('approved', 'پەسەندکراو (${approvedDocs.length})', Icons.check_circle_rounded, Colors.green),
                      const SizedBox(width: 8),
                      _buildFilterChip('rejected', 'ڕەتکراوە (${rejectedDocs.length})', Icons.cancel_rounded, Colors.red),
                      const SizedBox(width: 8),
                      _buildFilterChip('all', 'سەرجەم (${allDocs.length})', Icons.list_alt_rounded, Colors.blue),
                    ],
                  ),
                ),
                const Divider(height: 24),

                // Stream of Requests
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text('کێشەیەک هاتە: ${snapshot.error}', textAlign: TextAlign.center),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting && allDocs.isEmpty) {
                        return const Center(child: CupertinoActivityIndicator());
                      }

                      if (displayedDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _filterStatus == 'pending' ? Icons.task_alt_rounded : Icons.inbox_rounded,
                                size: 56,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _filterStatus == 'pending'
                                    ? 'هیچ داواکارییەکی چاوەڕوانکراو نییە 🎉'
                                    : 'هیچ داواکارییەک نەدۆزرایەوە',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'داواکاری نوێی VIP لێرە پیشان دەدرێت',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: displayedDocs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = displayedDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final requestId = doc.id;
                      final userId = data['userId'] as String? ?? '';
                      final userName = data['userName'] as String? ?? 'خوێندکار';
                      final userEmail = data['userEmail'] as String? ?? '';
                      final plan = data['plan'] as String? ?? 'monthly';
                      final planTitle = data['planTitle'] as String? ?? 'پلان مانگانە';
                      final paymentMethod = data['paymentMethod'] as String? ?? 'FastPay';
                      final transactionId = data['transactionId'] as String? ?? '---';
                      final amount = data['amount'] as String? ?? (data['price'] != null ? '${data['price']} د.ع' : '5,000 د.ع');
                      final receiptImageUrl = data['receiptImageUrl'] as String?;
                      final notes = data['notes'] as String?;
                      final status = data['status'] as String? ?? 'pending';
                      final requestedAt = data['requestedAt'] ?? data['createdAt'];
                      final isProcessing = _processingIds[requestId] == true;

                      return _buildRequestCard(
                        isDark: isDark,
                        requestId: requestId,
                        userId: userId,
                        userName: userName,
                        userEmail: userEmail,
                        plan: plan,
                        planTitle: planTitle,
                        paymentMethod: paymentMethod,
                        transactionId: transactionId,
                        notes: notes,
                        amount: amount,
                        receiptImageUrl: receiptImageUrl,
                        status: status,
                        requestedAt: requestedAt,
                        isProcessing: isProcessing,
                        expiresAt: data['expiresAt'],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  ),
);
}

  Widget _buildFilterChip(String statusKey, String label, IconData icon, Color color) {
    final isSelected = _filterStatus == statusKey;
    return InkWell(
      onTap: () => setState(() => _filterStatus = statusKey),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required bool isDark,
    required String requestId,
    required String userId,
    required String userName,
    required String userEmail,
    required String plan,
    required String planTitle,
    required String paymentMethod,
    required String transactionId,
    String? notes,
    required String amount,
    required String? receiptImageUrl,
    required String status,
    required dynamic requestedAt,
    required bool isProcessing,
    required dynamic expiresAt,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'پەسەندکراوە (Active)';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'ڕەتکراوەتەوە';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'چاوەڕوانکراو (Pending)';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkBackground : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == 'pending'
              ? Colors.orange.withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : Colors.grey[200]!),
          width: status == 'pending' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: User info & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ZankoColors.primary.withValues(alpha: 0.15),
                child: Text(
                  userName.isNotEmpty ? userName[0] : 'U',
                  style: TextStyle(
                    color: ZankoColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    if (userEmail.isNotEmpty)
                      Text(
                        userEmail,
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Plan & Payment Details Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildInfoBadge('👑 $planTitle', const Color(0xFFB8860B)),
              _buildInfoBadge('💳 $paymentMethod', const Color(0xFF0284C7)),
              _buildInfoBadge('💰 $amount', const Color(0xFF059669)),
            ],
          ),
          const SizedBox(height: 10),

          // Transaction ID & Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.tag_rounded, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ژمارەی حەواڵە: $transactionId',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
                Text(
                  _formatDate(requestedAt),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (notes != null && notes.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Text(
                '📝 تێبینی خوێندکار: $notes',
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.amber[200] : const Color(0xFF9A5B00)),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Row 3: Receipt Button & Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              if (receiptImageUrl != null && receiptImageUrl.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _showReceiptDialog(receiptImageUrl, userName),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('بینینی وەسڵ 🧾', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ZankoColors.primary,
                    side: BorderSide(color: ZankoColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),

              if (status == 'pending') ...[
                OutlinedButton(
                  onPressed: isProcessing
                      ? null
                      : () => _rejectVipRequest(requestId: requestId, userId: userId, userName: userName),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('ڕەتکردنەوە', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _approveVipRequest(
                            requestId: requestId,
                            userId: userId,
                            userName: userName,
                            plan: plan,
                            existingExpiresAt: expiresAt,
                          ),
                  icon: isProcessing
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Icon(Icons.verified_rounded, color: Colors.white, size: 16),
                  label: Text(
                    isProcessing ? 'پەسەندکردن...' : 'پەسەندکردنی VIP ⚡',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ] else if (status == 'approved') ...[
                TextButton.icon(
                  onPressed: isProcessing
                      ? null
                      : () => _rejectVipRequest(requestId: requestId, userId: userId, userName: userName),
                  icon: const Icon(Icons.undo_rounded, size: 14, color: Colors.grey),
                  label: const Text('هەڵوەشاندنەوەی VIP', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
