import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';

class PdfChatScreen extends StatefulWidget {
  const PdfChatScreen({super.key});

  @override
  State<PdfChatScreen> createState() => _PdfChatScreenState();
}

class _PdfChatScreenState extends State<PdfChatScreen> {
  String? _selectedPdf = 'Operating_Systems_Lecture_4.pdf';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withOpacity(0.9),
        elevation: 0,
        title: Text(
          langProvider.translate('pdf_chat'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            // PDF Upload Hero Container
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              color: ZankoColors.primary.withOpacity(0.06),
              border: Border.all(color: ZankoColors.primary.withOpacity(0.25), width: 1.5),
              onTap: () {},
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: ZankoColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: ZankoShadows.floating,
                    ),
                    child: const Icon(
                      CupertinoIcons.doc_fill,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    langProvider.translate('upload_pdf_title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    langProvider.translate('upload_pdf_subtitle'),
                    style: TextStyle(
                      fontSize: 12,
                      color: ZankoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Active PDF Document Card
            Text(
              langProvider.translate('active_document'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      CupertinoIcons.doc_fill,
                      color: Color(0xFFFF3B30),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedPdf!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '24 Pages • 4.2 MB',
                          style: TextStyle(
                            fontSize: 12,
                            color: ZankoColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.checkmark_alt_circle_fill,
                    color: ZankoColors.success,
                    size: 22,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // AI PDF Action Tools Header
            Text(
              langProvider.translate('ai_pdf_actions'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () {},
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.doc_plaintext, color: ZankoColors.primary, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          langProvider.translate('summarize'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () {},
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.question_circle, color: Color(0xFFAF52DE), size: 28),
                        const SizedBox(height: 8),
                        Text(
                          langProvider.translate('quiz'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : ZankoColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
