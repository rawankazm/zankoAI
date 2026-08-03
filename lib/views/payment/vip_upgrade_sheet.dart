import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';

class VipUpgradeSheet extends StatefulWidget {
  const VipUpgradeSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VipUpgradeSheet(),
    );
  }

  @override
  State<VipUpgradeSheet> createState() => _VipUpgradeSheetState();
}

class _VipUpgradeSheetState extends State<VipUpgradeSheet> {
  String _selectedMethod = 'fib'; // 'fib', 'fastpay', 'zaincash'
  bool _isProcessing = false;
  final TextEditingController _transactionController = TextEditingController();

  Future<void> _processVipUpgrade() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 1200));

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null && !user.isGuest) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.id).set({
          'isVip': true,
          'vipPaymentMethod': _selectedMethod,
          'vipTransactionId': _transactionController.text.trim(),
          'vipActivatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('👑 پیرۆزە! تایبەتمەندی بەشداربوونی VIP بەسەرکەوتوویی چالاککرا.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);
    final textDir = lang.textDirection;

    return Directionality(
      textDirection: textDir,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? ZankoColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),

              // Hero VIP Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9500), Color(0xFFFF5E00), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9500).withValues(alpha: 0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.star_fill, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'بەشداربوونی VIP بەدەستبهێنە',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'پەیامی بێسنوور + کورتکردنەوەی PDF + چارەسەری وێنەیی پرسیارەکان',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // VIP Features Bullet List
              _buildFeatureRow(context, CupertinoIcons.chat_bubble_2_fill, 'پەیامی بێسنوور لەگەڵ مامۆستا AI', 'لایەنی ٥ پەیامی بەخۆڕایی لادەبرێت'),
              _buildFeatureRow(context, CupertinoIcons.doc_text_fill, 'سەربەست کورتکردنەوەی فایلی PDF', 'بێ سنووردارکردنی قەبارەی پەڕەکان'),
              _buildFeatureRow(context, CupertinoIcons.camera_fill, 'چارەسەرکردنی پرسیار بە وێنەی کامێرا', 'پۆلی ۱۲ و بەشەکانی زانکۆ بە خێرایی'),
              _buildFeatureRow(context, CupertinoIcons.star_circle_fill, 'نیشانەی فەرمی VIP لە سەر پڕۆفایل', 'بەشداربووی پێشەنگ و بەرزین'),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Payment Method Title
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'ڕێگەی پارەدان هەڵبژێرە (Payment Method):',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // FIB Payment Option
              _buildPaymentOptionCard(
                id: 'fib',
                title: 'FIB (First Iraqi Bank / بانکی یەکەمی عێراقی)',
                subtitle: 'پاشەکەوت و نەواڕی بانکی یەکەمی عێراقی',
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF0F172A),
              ),
              const SizedBox(height: 8),

              // FastPay Payment Option
              _buildPaymentOptionCard(
                id: 'fastpay',
                title: 'FastPay (فاست پەپ)',
                subtitle: 'ژمارەی فاست پەپ: 0750 123 4567',
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFFE11D48),
              ),
              const SizedBox(height: 8),

              // ZainCash Payment Option
              _buildPaymentOptionCard(
                id: 'zaincash',
                title: 'ZainCash (زین کاش)',
                subtitle: 'ژمارەی زین کاش: 0780 123 4567',
                icon: Icons.phone_android_rounded,
                color: const Color(0xFF7C3AED),
              ),

              const SizedBox(height: 16),

              // Transaction Code optional input
              TextField(
                controller: _transactionController,
                decoration: InputDecoration(
                  labelText: 'ژمارەی پسوولە / Transaction ID (ئارەزوومەندانه):',
                  hintText: 'نموونە: TXN-884920',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              const SizedBox(height: 20),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processVipUpgrade,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isProcessing
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.star_fill, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'چالاککردنی VIP (٥,٠٠٠ دیناری مانگانە)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFF9500), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFFFF9500), size: 22),
          ],
        ),
      ),
    );
  }
}
