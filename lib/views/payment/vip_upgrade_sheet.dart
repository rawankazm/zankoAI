import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

enum _UploadStep { form, uploading, done }

class _VipUpgradeSheetState extends State<VipUpgradeSheet>
    with SingleTickerProviderStateMixin {
  String _selectedMethod = 'fib';
  final TextEditingController _transactionController = TextEditingController();

  File? _receiptFile;
  double _uploadProgress = 0;
  _UploadStep _step = _UploadStep.form;
  String? _errorMsg;

  late AnimationController _checkCtrl;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkScale = CurvedAnimation(parent: _checkCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _checkCtrl.dispose();
    _transactionController.dispose();
    super.dispose();
  }

  // ── Pick receipt image ────────────────────────────────────────────────────
  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() => _receiptFile = File(picked.path));
    }
  }

  // ── Submit VIP request ────────────────────────────────────────────────────
  Future<void> _submitRequest() async {
    if (_receiptFile == null) {
      setState(() => _errorMsg = 'تکایە وێنەی وەسڵی پارەدانەکەت بنێرە 📷');
      return;
    }
    setState(() { _step = _UploadStep.uploading; _errorMsg = null; });

    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null || user.isGuest) return;

    try {
      // 1. Upload receipt image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref('vip_receipts/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final task = storageRef.putFile(_receiptFile!);
      task.snapshotEvents.listen((snap) {
        setState(() {
          _uploadProgress = snap.bytesTransferred / snap.totalBytes;
        });
      });
      await task;
      final receiptUrl = await storageRef.getDownloadURL();

      // 2. Create vip_request document (status = pending — admin reviews it)
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      );

      await FirebaseFirestore.instance.collection('vip_requests').add({
        'userId': user.id,
        'userName': user.name,
        'userEmail': user.email,
        'paymentMethod': _selectedMethod,
        'transactionId': _transactionController.text.trim(),
        'receiptImageUrl': receiptUrl,
        'amount': 5000,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt,
      });

      // 3. Update user doc: vipStatus = pending (NOT isVip: true yet)
      await FirebaseFirestore.instance.collection('users').doc(user.id).set({
        'vipStatus': 'pending',
      }, SetOptions(merge: true));

      setState(() => _step = _UploadStep.done);
      _checkCtrl.forward();
    } catch (e) {
      setState(() {
        _step = _UploadStep.form;
        _errorMsg = 'کێشەیەک هاتە: $e';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
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
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _step == _UploadStep.done
                ? _buildSuccessView(isDark)
                : _step == _UploadStep.uploading
                    ? _buildUploadingView(isDark)
                    : _buildFormView(isDark),
          ),
        ),
      ),
    );
  }

  // ── Form View ─────────────────────────────────────────────────────────────
  Widget _buildFormView(bool isDark) {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          width: 40, height: 5,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(height: 18),

        // ── Header Banner ─────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1200), Color(0xFF2C1F00), Color(0xFF3D2B00)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.25),
                blurRadius: 20, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(children: [
            const Text('👑', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            const Text(
              'VIP بەدەستبهێنە',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFFD700)),
            ),
            const SizedBox(height: 4),
            Text(
              'پارەدان بکە، وەسڵەکەت بنێرە، ئەدمین پشتڕاست دەکاتەوە',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Features ─────────────────────────────────────────────────────
        _buildFeatureRow(CupertinoIcons.chat_bubble_2_fill,   'پەیامی بێسنوور',   'لایەنی ٥ی بەخۆڕایی لادەبرێت'),
        _buildFeatureRow(CupertinoIcons.doc_text_fill,        'کورتکردنەوەی PDF', 'بێ سنووردارکردن'),
        _buildFeatureRow(CupertinoIcons.camera_fill,          'وێنەی پرسیار',     'شیکاری AI بۆ وێنەکانت'),
        _buildFeatureRow(CupertinoIcons.star_circle_fill,     'نیشانەی VIP 👑',   'لە پرۆفایلت'),

        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),

        // ── Payment Method ────────────────────────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'ڕێگەی پارەدان هەڵبژێرە:',
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : ZankoColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPaymentOption('fib',      'FIB — بانکی یەکەمی عێراقی',       'بانکی یەکەمی عێراقی',          Icons.account_balance_rounded,      const Color(0xFF0F172A)),
        const SizedBox(height: 8),
        _buildPaymentOption('fastpay',  'FastPay — فاست پەی',               'ژمارە: 0750 123 4567',           Icons.account_balance_wallet_rounded,const Color(0xFFE11D48)),
        const SizedBox(height: 8),
        _buildPaymentOption('zaincash', 'ZainCash — زین کاش',               'ژمارە: 0780 123 4567',           Icons.phone_android_rounded,         const Color(0xFF7C3AED)),

        const SizedBox(height: 16),

        // ── Transaction ID ────────────────────────────────────────────────
        TextField(
          controller: _transactionController,
          decoration: InputDecoration(
            labelText: 'ژمارەی پسوولە / Transaction ID',
            hintText: 'نموونە: TXN-884920',
            prefixIcon: const Icon(Icons.tag_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),

        // ── Receipt Upload ────────────────────────────────────────────────
        GestureDetector(
          onTap: _pickReceipt,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _receiptFile != null
                  ? const Color(0xFF10B981).withValues(alpha: 0.08)
                  : (isDark ? ZankoColors.darkCardSecondary : Colors.grey[50]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _receiptFile != null
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white24 : Colors.grey[300]!),
                width: _receiptFile != null ? 2 : 1.5,
              ),
            ),
            child: _receiptFile == null
                ? Column(children: [
                    Icon(CupertinoIcons.camera_fill,
                        size: 36,
                        color: isDark ? Colors.white38 : Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'وێنەی وەسڵی پارەدانت بنێرە *',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'کلیک بکە تا وێنەیەک هەڵبژێریت لە گەلەرییەکەت',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                    ),
                  ])
                : Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_receiptFile!, width: 72, height: 72, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✅ وەسڵ هەڵبژێردرا', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                        const SizedBox(height: 4),
                        Text(_receiptFile!.path.split('/').last,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _pickReceipt,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: const Text('گۆڕین', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    )),
                  ]),
          ),
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Color(0xFFEF4444), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
            ]),
          ),
        ],

        const SizedBox(height: 20),

        // ── Submit Button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _submitRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB8860B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('👑', style: TextStyle(fontSize: 20)),
                SizedBox(width: 10),
                Text(
                  'ناردنی داواکاری VIP — ٥,٠٠٠ دیناری مانگانە',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),
        Text(
          '⏳ دوای ناردن، ئەدمین لە ناو ٢٤ کاتژمێردا پشتڕاست دەکاتەوە',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500]),
        ),
      ],
    );
  }

  // ── Uploading View ────────────────────────────────────────────────────────
  Widget _buildUploadingView(bool isDark) {
    return SizedBox(
      key: const ValueKey('uploading'),
      height: 280,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👑', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 20),
          const Text('داواکارییەکەت دەنێرێت...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),
          const SizedBox(height: 10),
          Text('${(_uploadProgress * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFFD700))),
        ],
      ),
    );
  }

  // ── Success View ──────────────────────────────────────────────────────────
  Widget _buildSuccessView(bool isDark) {
    return SizedBox(
      key: const ValueKey('done'),
      height: 340,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _checkScale,
            child: Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFB8860B), Color(0xFFFFD700)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 44)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'پیرۆزە! داواکارییەکەت نێردرا',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'ئەدمین لە ناو ٢٤ کاتژمێردا داواکارییەکەت پشتڕاست دەکاتەوە\nئاگادارکردنەوە بۆت دەنێرێت کاتێک VIPت چالاک دەبێت 🔔',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF3D2000),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('باشە، چاوەڕوام دەبێت ✓', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFB8860B), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        )),
      ]),
    );
  }

  Widget _buildPaymentOption(String id, String title, String subtitle, IconData icon, Color color) {
    final isSelected = _selectedMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          )),
          if (isSelected) const Icon(CupertinoIcons.checkmark_circle_fill, color: Color(0xFFFFD700), size: 22),
        ]),
      ),
    );
  }
}
