import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../theme.dart';

/// Reads active ads from Firestore and shows them as a hero banner matching the premium design.
/// Pass [screenName] matching one of the screen IDs set in the Admin panel (e.g. 'home', 'zankoline', 'ai_teacher').
class AdBannerWidget extends StatefulWidget {
  final String screenName;

  const AdBannerWidget({super.key, required this.screenName});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  bool _dismissed = false;

  Future<void> _openAdUrl(String urlStr) async {
    if (urlStr.trim().isEmpty) return;
    String formattedUrl = urlStr.trim();
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.parse(formattedUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error launching ad URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final langProvider = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ads').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final matchingAds = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;

          // Check active flag
          final isActive = data['isActive'] == true;
          if (!isActive) return false;

          // Check showOnScreens array
          final showOnScreens = data['showOnScreens'];
          if (showOnScreens is List) {
            final screens = showOnScreens.map((e) => e.toString().toLowerCase()).toList();
            if (screens.contains('all') || screens.contains(widget.screenName.toLowerCase())) {
              return true;
            }
          }
          // If no showOnScreens specified, show on all by default
          if (showOnScreens == null) return true;

          return false;
        }).toList();

        if (matchingAds.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show the matching ad
        final adData = matchingAds.first.data() as Map<String, dynamic>;

        final currentLang = langProvider.currentLanguage;
        String title = adData['title'] ?? '';
        if (currentLang == AppLanguage.arabic && (adData['titleAr']?.toString().isNotEmpty ?? false)) {
          title = adData['titleAr'];
        } else if (currentLang == AppLanguage.english && (adData['titleEn']?.toString().isNotEmpty ?? false)) {
          title = adData['titleEn'];
        }

        String description = adData['description'] ?? '';
        if (currentLang == AppLanguage.arabic && (adData['descAr']?.toString().isNotEmpty ?? false)) {
          description = adData['descAr'];
        } else if (currentLang == AppLanguage.english && (adData['descEn']?.toString().isNotEmpty ?? false)) {
          description = adData['descEn'];
        }

        String buttonText = adData['buttonTextKu'] ?? 'سەردان بکە';
        if (currentLang == AppLanguage.arabic && (adData['buttonTextAr']?.toString().isNotEmpty ?? false)) {
          buttonText = adData['buttonTextAr'];
        } else if (currentLang == AppLanguage.english && (adData['buttonTextEn']?.toString().isNotEmpty ?? false)) {
          buttonText = adData['buttonTextEn'];
        }

        final imageUrl = adData['imageUrl'] as String?;
        final linkUrl = adData['linkUrl'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E222A), const Color(0xFF15181E)]
                  : [Colors.white, const Color(0xFFF8FAFC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: ZankoColors.primary.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner Image if available
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      GestureDetector(
                        onTap: () => _openAdUrl(linkUrl),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          color: Colors.black12,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),

                    // Title + Description + Action Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: ZankoColors.primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            CupertinoIcons.speaker_2_fill,
                                            size: 11,
                                            color: ZankoColors.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'ڕیکلام',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: ZankoColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (title.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                                    ),
                                  ),
                                ],
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (linkUrl.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => _openAdUrl(linkUrl),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ZankoColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: Text(
                                buttonText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Dismiss button in top corner
                Positioned(
                  top: 8,
                  left: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _dismissed = true),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
