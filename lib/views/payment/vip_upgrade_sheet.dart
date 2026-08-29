import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../auth/login_screen.dart';

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
  String _selectedPlan = '1_month'; // '1_month', '3_months', '9_months'
  bool _showAccounts = true;

  String _whatsappNumber = '07509987345';
  String _telegramUsername = 'rawankurdi';
  String _fibNumber = 'FIB-ZANKO-9090';
  String _fastPayNumber = '0750 789 9090';

  int get _planPrice {
    switch (_selectedPlan) {
      case '3_months':
        return 12000;
      case '9_months':
        return 40000;
      case '1_month':
      default:
        return 5000;
    }
  }

  String get _planTitle {
    switch (_selectedPlan) {
      case '3_months':
        return 'پلانی وەرزی (٣ مانگ)';
      case '9_months':
        return 'پلانی ساڵانە (٩ مانگ)';
      case '1_month':
      default:
        return 'پلانی مانگانە (١ مانگ)';
    }
  }

  @override
  void initState() {
    super.initState();
    _listenToPaymentConfig();
  }

  void _listenToPaymentConfig() {
    void parseData(Map<String, dynamic>? data) {
      if (data == null || !mounted) return;
      setState(() {
        final whatsapp = data['whatsappNumber'] ??
            data['whatsAppNumber'] ??
            data['whatsapp'] ??
            data['whatsapp_number'];
        if (whatsapp != null && whatsapp.toString().trim().isNotEmpty) {
          _whatsappNumber = whatsapp.toString().trim();
        }

        final telegram = data['telegramUsername'] ??
            data['telegram'] ??
            data['telegramUser'] ??
            data['telegram_username'];
        if (telegram != null && telegram.toString().trim().isNotEmpty) {
          _telegramUsername = telegram.toString().trim();
        }

        final fib = data['fibNumber'] ?? data['fib'] ?? data['fib_number'];
        if (fib != null && fib.toString().trim().isNotEmpty) {
          _fibNumber = fib.toString().trim();
        }

        final fastpay = data['fastPayNumber'] ??
            data['fastpay'] ??
            data['fastPay'] ??
            data['fastpay_number'];
        if (fastpay != null && fastpay.toString().trim().isNotEmpty) {
          _fastPayNumber = fastpay.toString().trim();
        }
      });
    }

    FirebaseFirestore.instance
        .collection('config')
        .doc('payment_config')
        .get()
        .then((doc) {
      if (doc.exists) parseData(doc.data());
    }).catchError((e) {
      debugPrint('payment_config initial get warning: $e');
    });

    FirebaseFirestore.instance
        .collection('config')
        .doc('payment_config')
        .snapshots()
        .listen(
      (snap) {
        if (snap.exists) parseData(snap.data());
      },
      onError: (err) {
        debugPrint('payment_config snapshots error: $err');
      },
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  // ── Register VIP Request to Firestore for Admin Panel ─────────────────────
  Future<bool> _registerVipRequest({
    required BuildContext ctx,
    required dynamic user,
    required String platform,
  }) async {
    if (user == null || user.isGuest == true) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: const Text('تکایە سەرەتا بچۆ ژوورەوە (Login) بۆ ئەوەی داواکارییەکەت لە سیستەم تۆمار بکرێت'),
            backgroundColor: Colors.orange[800],
            action: SnackBarAction(
              label: 'داخیلبوون',
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ),
        );
      }
      return false;
    }

    try {
      final reqDoc = FirebaseFirestore.instance.collection('vip_requests').doc(user.id);
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.id);

      final priceStr = _formatPrice(_planPrice);

      await Future.wait([
        reqDoc.set({
          'id': user.id,
          'userId': user.id,
          'userEmail': user.email,
          'userName': user.name,
          'photoUrl': user.photoUrl,
          'plan': _selectedPlan,
          'planTitle': _planTitle,
          'price': _planPrice,
          'amount': '$priceStr د.ع',
          'paymentMethod': platform,
          'transactionId': 'لە چاتی $platform دەنێردرێت 💬',
          'receiptImageUrl': '',
          'method': platform.toLowerCase(),
          'status': 'pending',
          'notes': 'داواکاری لە ڕێگەی $platform نێردراوە',
          'requestedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        userDoc.set({
          'vipStatus': 'pending',
          'requestedPlan': _selectedPlan,
          'vipRequestedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]);
      return true;
    } catch (e) {
      debugPrint('Error creating vip_request: $e');
      return true; // proceed to open chat
    }
  }

  // ── Open WhatsApp ─────────────────────────────────────────────────────────
  Future<void> _launchWhatsApp() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    final registered = await _registerVipRequest(
      ctx: context,
      user: user,
      platform: 'WhatsApp',
    );
    if (!registered) return;

    final userName = user?.name ?? 'خوێندکار';
    final userEmail = user?.email ?? 'نادیار';
    final userId = user?.id ?? '';

    final priceStr = _formatPrice(_planPrice);
    final message = '''
سڵاو بەڕێزم 👑
دەمەوێت بەشداری VIP لە Zanko AI چالاک بکەم:

📌 زانیاری داواکاری:
• پلان: $_planTitle ($priceStr د.ع)
• ناوی خوێندکار: $userName
• ئیمەیڵ: $userEmail
• ئایدی هەژمار: $userId

(وێنەی وەسڵی پارەدانەکەم لە خوارەوە هاوپێچ کردووە 🧾👇)
'''.trim();

    String cleanPhone = _whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('07')) {
      cleanPhone = '964${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('7')) {
      cleanPhone = '964$cleanPhone';
    }

    final urlString = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('نەتوانرا واتسئاپ بکرێتەوە: $_whatsappNumber'),
            backgroundColor: ZankoColors.error,
          ),
        );
      }
    }
  }

  // ── Open Telegram ─────────────────────────────────────────────────────────
  Future<void> _launchTelegram() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    final registered = await _registerVipRequest(
      ctx: context,
      user: user,
      platform: 'Telegram',
    );
    if (!registered) return;

    final userName = user?.name ?? 'خوێندکار';
    final userEmail = user?.email ?? 'نادیار';
    final userId = user?.id ?? '';

    final priceStr = _formatPrice(_planPrice);
    final message = '''
سڵاو بەڕێزم 👑
دەمەوێت بەشداری VIP لە Zanko AI چالاک بکەم:

📌 زانیاری داواکاری:
• پلان: $_planTitle ($priceStr د.ع)
• ناوی خوێندکار: $userName
• ئیمەیڵ: $userEmail
• ئایدی هەژمار: $userId

(وێنەی وەسڵی پارەدانەکەم لە خوارەوە هاوپێچ کردووە 🧾👇)
'''.trim();

    String cleanUsername = _telegramUsername
        .replaceAll('@', '')
        .replaceAll('https://t.me/', '')
        .trim();

    final urlString = 'https://t.me/$cleanUsername?text=${Uri.encodeComponent(message)}';
    final uri = Uri.parse(urlString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('نەتوانرا تەلەگرام بکرێتەوە: @$_telegramUsername'),
            backgroundColor: ZankoColors.error,
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ژمارەی $label کۆپی کرا: $text 📋'),
        backgroundColor: ZankoColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final isVip = user?.isVip == true;

    return Directionality(
      textDirection: lang.textDirection,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with Drag handle & Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.chevron_back,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Header Banner ─────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1200), Color(0xFF2C1F00), Color(0xFF3D2B00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('👑', style: TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isVip ? 'ئەندامی نایابی VIP (چالاکە 👑)' : 'بەشداریکردنی نایابی VIP',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ڕاپۆرت و سێمینار بە Word و PPTX + تاقیکردنەوە و چاتی بێسنوور',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Value Pitch Card ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لە مەکتەبەکان بۆ تەنها یەک سێمینار یان ڕاپۆرت ١٥,٠٠٠+ د.ع لێوەردەگرن! لە Zanko AI بە ٥,٠٠٠ د.ع تەواوی مانگەکە بە دەیان سێمینار، ڕاپۆرت و پێشبینی تاقیکردنەوە بەدەستبهێنە.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.amber[200] : const Color(0xFF9A5B00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Plan Selection ────────────────────────────────────────────
              Text(
                '١. پلانی گونجاو بۆ خۆت هەڵبژێرە:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _buildPlanCard(
                      id: '1_month',
                      title: '١ مانگ',
                      subtitle: 'سەرەتایی',
                      price: '٥,٠٠٠',
                      currency: 'د.ع',
                      badge: null,
                      isSelected: _selectedPlan == '1_month',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPlanCard(
                      id: '3_months',
                      title: '٣ مانگ',
                      subtitle: 'وەرزی تاقیکردنەوە',
                      price: '١٢,٠٠٠',
                      currency: 'د.ع',
                      badge: '🔥 پێشنیارکراو',
                      badgeColor: const Color(0xFFE11D48),
                      discount: '٢٠٪ داشکاندن',
                      isSelected: _selectedPlan == '3_months',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPlanCard(
                      id: '9_months',
                      title: '٩ مانگ',
                      subtitle: 'تەواوی ساڵ',
                      price: '٤٠,٠٠٠',
                      currency: 'د.ع',
                      badge: '👑 باشترین بەها',
                      badgeColor: const Color(0xFFB8860B),
                      discount: 'پاشەکەوتی ٥,٠٠٠ د.ع',
                      isSelected: _selectedPlan == '9_months',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Payment Accounts Reference ────────────────────────────────
              Text(
                '٢. پارەکە بۆ یەکێک لەم ژمارانە بنێرە:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222B) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showAccounts = !_showAccounts),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 18,
                              color: Color(0xFFB8860B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ژمارەکانی پارەدان (FastPay, FIB)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                                ),
                              ),
                            ),
                            Icon(
                              _showAccounts ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showAccounts) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            _buildPaymentRow(
                              title: 'FastPay',
                              number: _fastPayNumber,
                              color: const Color(0xFFE11D48),
                              icon: Icons.account_balance_wallet_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            _buildPaymentRow(
                              title: 'FIB (IBAN)',
                              number: _fibNumber,
                              color: const Color(0xFF0F172A),
                              icon: Icons.account_balance_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '📌 دوای ناردنی پارەکە، لە خوارەوە لە ڕێگەی واتسئاپ یان تەلەگرام وێنەی وەسڵەکە بنێرە.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Step 3: Send Receipt via WhatsApp / Telegram ──────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1B262C), const Color(0xFF161E2E)]
                        : [const Color(0xFFF0FDF4), const Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            CupertinoIcons.paperplane_fill,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '٣. ناردنی وێنەی وەسڵ بۆ بەڕێوەبەر:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🧾', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'دوای ئەوەی پارەکەت نارد، لە ڕێگەی واتسئاپ یان تەلەگرام وێنەی وەسڵەکەت بنێرە تاوەکو ئەدمین ڕاستەوخۆ VIPەکەت بۆ چالاک بکات ⚡',
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.45,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // WhatsApp Button
                    ElevatedButton.icon(
                      onPressed: _launchWhatsApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(CupertinoIcons.chat_bubble_fill, size: 20),
                      label: const Text(
                        'ناردنی وێنەی وەسڵ لە واتسئاپ (WhatsApp) 💬',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Telegram Button
                    ElevatedButton.icon(
                      onPressed: _launchTelegram,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF229ED9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(CupertinoIcons.paperplane_fill, size: 20),
                      label: const Text(
                        'ناردنی وێنەی وەسڵ لە تەلەگرام (Telegram) ✈️',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── VIP Perks Checklist ───────────────────────────────────────
              Text(
                'سوودە تایبەتەکانی VIP:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                CupertinoIcons.doc_richtext,
                'ڕاپۆرت و سێمینار بە Word و PowerPoint',
                'داگرتنی ڕاستەوخۆی فایلی .docx و .pptx بە فۆرماتی ئەکادیمی و سەرچاوە',
              ),
              _buildFeatureRow(
                CupertinoIcons.sparkles,
                'پێشبینیکەری پرسیاری تاقیکردنەوە (AI Exam)',
                'پێشبینی ئەو پرسیارانەی ئەگەری ٩٠٪ لە فاینەڵ دێنەوە لەگەڵ تاقیکردنەوەی تاقیکاری',
              ),
              _buildFeatureRow(
                CupertinoIcons.chat_bubble_2_fill,
                'گفتوگۆ و پرسیاری بێسنوور لەگەڵ مامۆستای AI',
                'لابردنی هەموو جۆرە سنووردارکردنێکی ڕۆژانە بۆ گفتوگۆ',
              ),
              _buildFeatureRow(
                CupertinoIcons.camera_viewfinder,
                'شیکارکردنی وێنەی مەلزەمە و پرسیاری ئاڵۆز',
                'شیکارکردنی هاوکێشە، ماتماتیک، پزیشکی و ئەندازیاری بە هەنگاو',
              ),
              _buildFeatureRow(
                CupertinoIcons.bolt_fill,
                'خێرایی وەڵامدانەوە و ژیریی مۆدێلی بەرز',
                'وەڵامدانەوەی پێشینەدار (Priority) بە بەرزترین وردبینی',
              ),

              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.shield_lefthalf_fill,
                    size: 14,
                    color: Color(0xFFB8860B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'پارێزراو و پشتڕاستکراوە لەلایەن تیمی birdev',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Plan Card Widget ───────────────────────────────────────────────────────
  Widget _buildPlanCard({
    required String id,
    required String title,
    required String subtitle,
    required String price,
    required String currency,
    required String? badge,
    Color badgeColor = const Color(0xFFE11D48),
    String? discount,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFD700).withValues(alpha: 0.12)
              : (isDark ? ZankoColors.darkCardSecondary : Colors.grey[50]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700)
                : (isDark ? Colors.white12 : Colors.grey[200]!),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ] else ...[
              const SizedBox(height: 15),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isSelected
                      ? const Color(0xFFB8860B)
                      : (isDark ? Colors.white : Colors.black87),
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? const Color(0xFFB8860B)
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    currency,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (discount != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    discount,
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFB8860B), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow({
    required String title,
    required String number,
    required Color color,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ZankoColors.primary,
              ),
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
            ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
            onPressed: () => _copyToClipboard(number, title),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'کۆپیکردن',
          ),
        ],
      ),
    );
  }
}
