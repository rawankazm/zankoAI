import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme.dart';

class AdminBroadcastSheet extends StatefulWidget {
  final bool isDark;
  const AdminBroadcastSheet({super.key, required this.isDark});

  @override
  State<AdminBroadcastSheet> createState() => _AdminBroadcastSheetState();
}

class _AdminBroadcastSheetState extends State<AdminBroadcastSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _workerUrlController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();

  String _selectedTarget = 'all'; // all, vip, streak_reminder
  bool _isSending = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('cf_worker_url') ?? 'https://zankoai.rawankurdi181.workers.dev';
    final secret = prefs.getString('cf_worker_secret') ?? 'zanko_secret_2026';
    if (mounted) {
      setState(() {
        _workerUrlController.text = url;
        _secretController.text = secret;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cf_worker_url', _workerUrlController.text.trim());
    await prefs.setString('cf_worker_secret', _secretController.text.trim());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _workerUrlController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _statusMessage = 'تکایە ناونیشان و دەقی پەیام بنووسە';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isSending = true;
      _statusMessage = null;
    });

    try {
      await _saveSettings();

      // 1. Write to Firestore 'notifications' collection (for in-app bell & active streams)
      await FirebaseFirestore.instance.collection('notifications').add({
        'title': title,
        'body': body,
        'target': _selectedTarget,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Trigger Cloudflare Worker Push Notification (wakes up closed/locked phones)
      final workerUrl = _workerUrlController.text.trim();
      if (workerUrl.isNotEmpty) {
        final cleanUrl = workerUrl.endsWith('/') ? workerUrl.substring(0, workerUrl.length - 1) : workerUrl;
        final targetUri = Uri.parse('$cleanUrl/send');
        final topic = _selectedTarget == 'vip' ? 'vip_students' : 'all_students';

        final client = HttpClient();
        final req = await client.postUrl(targetUri);
        req.headers.set('Content-Type', 'application/json; charset=UTF-8');
        req.headers.set('X-Secret-Key', _secretController.text.trim());
        req.write(jsonEncode({
          'title': title,
          'body': body,
          'topic': topic,
        }));
        await req.close();
        client.close();
      }

      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _isSending = false;
          _isSuccess = true;
          _statusMessage = 'پەیامەکە بە سەرکەوتوویی بۆ هەموو خوێندکاران نێردرا! 🚀';
          _titleController.clear();
          _bodyController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _isSuccess = false;
          _statusMessage = 'پەیام لە داتابەیس تۆمارکرا، بەڵام سێرڤەر: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ZankoColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    CupertinoIcons.paperplane_fill,
                    color: ZankoColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ناردنی ئاگاداری بەپەلە (Push Notification)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Target Selector
            Text(
              'کێ پێی بگات؟',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.grey[300] : ZankoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTargetOption('all', '👥 هەموو خوێندکاران'),
                const SizedBox(width: 10),
                _buildTargetOption('vip', '⭐ خوێندکارانی VIP'),
              ],
            ),
            const SizedBox(height: 16),

            // Title Field
            Text(
              'ناونیشانی پەیام',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.grey[300] : ZankoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _titleController,
              hint: 'بۆ نموونە: 🔔 ئاگاداری تاقیکردنەوەی میدترم',
            ),
            const SizedBox(height: 14),

            // Body Field
            Text(
              'دەقی پەیام',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.grey[300] : ZankoColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _bodyController,
              hint: 'دەقی ئەو پەیامەی کە لەسەر شاشەی مۆبایلەکەیان دەردەکەوێت بنووسە...',
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Cloudflare Worker URL (Optional Settings)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  '🌐 بەستنەوە بە Cloudflare Worker (بژاردەیی)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                  ),
                ),
                children: [
                  _buildTextField(
                    controller: _workerUrlController,
                    hint: 'https://zanko-push.workers.dev',
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _secretController,
                    hint: 'Secret Key (بۆ نموونە: zanko_secret_2026)',
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : ZankoColors.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _isSuccess ? const Color(0xFF10B981) : ZankoColors.error,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZankoColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSending
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.paperplane_fill, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'ناردنی دەستبەجێ بۆ هەمووان',
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
    );
  }

  Widget _buildTargetOption(String value, String label) {
    final isSelected = _selectedTarget == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTarget = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? ZankoColors.primary.withValues(alpha: 0.15)
                : (widget.isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF5F5FA)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? ZankoColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? ZankoColors.primary
                    : (widget.isDark ? Colors.white70 : ZankoColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E5EA),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 13,
          color: widget.isDark ? Colors.white : ZankoColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 12,
            color: widget.isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
