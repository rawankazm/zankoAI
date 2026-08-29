import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppExitDialog extends StatelessWidget {
  const AppExitDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const AppExitDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.only(top: 28, left: 24, right: 24, bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2435),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'چوونەدەرەوە له ئەپ',
              textAlign: TextAlign.center,
              style: GoogleFonts.vazirmatn(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            // Message Body
            Text(
              'ئایا دڵنیایت کە دەتوێت له ئەپەکە بچیته دەره‌وە؟',
              textAlign: TextAlign.center,
              style: GoogleFonts.vazirmatn(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFCBD5E1),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel Button (پاشگەزبوونەوە)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(
                    'پاشگەزبوونەوە',
                    style: GoogleFonts.vazirmatn(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF818CF8),
                    ),
                  ),
                ),
                // Exit Button (چوونەدەرەوە)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(
                    'چوونەدەرەوە',
                    style: GoogleFonts.vazirmatn(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF87171),
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
