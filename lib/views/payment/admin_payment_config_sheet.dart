import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';

class AdminPaymentConfigSheet extends StatefulWidget {
  const AdminPaymentConfigSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminPaymentConfigSheet(),
    );
  }

  @override
  State<AdminPaymentConfigSheet> createState() => _AdminPaymentConfigSheetState();
}

class _AdminPaymentConfigSheetState extends State<AdminPaymentConfigSheet> {
  final TextEditingController _whatsappController = TextEditingController(text: '07509987345');
  final TextEditingController _telegramController = TextEditingController(text: 'rawankurdi');
  final TextEditingController _fibController = TextEditingController(text: 'FIB-ZANKO-9090');
  final TextEditingController _fastPayController = TextEditingController(text: '0750 789 9090');
  final TextEditingController _zainCashController = TextEditingController(text: '0780 789 9090');

  bool _isLoading = true;
  bool _isSaving = false;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _fetchCurrentNumbers();
  }

  Future<void> _fetchCurrentNumbers() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('config').doc('payment_config').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['whatsappNumber'] != null) _whatsappController.text = data['whatsappNumber'].toString();
        if (data['telegramUsername'] != null) _telegramController.text = data['telegramUsername'].toString();
        if (data['fibNumber'] != null) _fibController.text = data['fibNumber'].toString();
        if (data['fastPayNumber'] != null) _fastPayController.text = data['fastPayNumber'].toString();
        if (data['zainCashNumber'] != null) _zainCashController.text = data['zainCashNumber'].toString();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePaymentNumbers() async {
    final whatsapp = _whatsappController.text.trim();
    final telegram = _telegramController.text.trim();
    final fib = _fibController.text.trim();
    final fastpay = _fastPayController.text.trim();
    final zaincash = _zainCashController.text.trim();

    if (whatsapp.isEmpty || fib.isEmpty || fastpay.isEmpty || zaincash.isEmpty) {
      setState(() => _statusMsg = 'تکایە خانەکانی پەیوەندی و ژمارەکان پڕبکەرەوە');
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMsg = null;
    });

    try {
      await FirebaseFirestore.instance.collection('config').doc('payment_config').set({
        'whatsappNumber': whatsapp,
        'telegramUsername': telegram,
        'fibNumber': fib,
        'fastPayNumber': fastpay,
        'zainCashNumber': zaincash,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ڕێکخستنەکانی پارەدان و پەیوەندی VIP پاشەکەوت کران 💳'),
            backgroundColor: ZankoColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMsg = 'کێشەیەک هاتە پێشەوە: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    _telegramController.dispose();
    _fibController.dispose();
    _fastPayController.dispose();
    _zainCashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);

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
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '💳 ڕێکخستنی ژمارەکانی پارەدان و VIP',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark_circle_fill),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'ئەم زانیارییانەی خوارەوە لەسەر مۆبایلی سەرجەم خوێندکاران بە شێوەی ڕاستەوخۆ (Real-time) دەگۆڕێن:',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else ...[
                // WhatsApp
                TextField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: '💬 ژمارەی WhatsApp (بۆ کڕینی VIP)',
                    prefixIcon: const Icon(CupertinoIcons.chat_bubble_fill, color: Color(0xFF25D366)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),

                // Telegram
                TextField(
                  controller: _telegramController,
                  decoration: InputDecoration(
                    labelText: '✈️ یوزەرنەیمی Telegram',
                    prefixIcon: const Icon(CupertinoIcons.paperplane_fill, color: Color(0xFF229ED9)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),

                // FIB Number
                TextField(
                  controller: _fibController,
                  decoration: InputDecoration(
                    labelText: 'ژمارەی ئەژماری FIB — بانکی یەکەمی عێراقی',
                    prefixIcon: const Icon(Icons.account_balance_rounded, color: Color(0xFF0F172A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),

                // FastPay Number
                TextField(
                  controller: _fastPayController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'ژمارەی فاست پەی (FastPay Number)',
                    prefixIcon: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFE11D48)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 14),

                // ZainCash Number
                TextField(
                  controller: _zainCashController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'ژمارەی زین کاش (ZainCash Number)',
                    prefixIcon: Icon(Icons.phone_android_rounded, color: ZankoColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 20),

                if (_statusMsg != null) ...[
                  Text(_statusMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _savePaymentNumbers,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(CupertinoIcons.checkmark_seal_fill),
                    label: Text(_isSaving ? 'پاشەکەوت دەکرێت...' : 'پاشەکەوتکردنی ژمارەکان 💾'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZankoColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
