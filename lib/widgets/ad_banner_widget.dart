import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../theme.dart';

/// Reads active ads from Supabase or returns empty banner
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
    if (!formattedUrl.startsWith('http://') &&
        !formattedUrl.startsWith('https://')) {
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

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .handleError((_) => <Map<String, dynamic>>[]),
      builder: (context, snapshot) {
        final allRows = snapshot.data ?? [];
        final matchingAds = allRows
            .where((row) {
              final data = row['data'] is Map
                  ? (row['data'] as Map<String, dynamic>)
                  : <String, dynamic>{};
              final isAd =
                  data['is_ad'] == true ||
                  (row['type'] == 'broadcast' && data['is_ad'] == true);
              if (!isAd) return false;
              if (data['is_deleted'] == true) return false;

              final isActive =
                  data['isActive'] == true ||
                  data['is_active'] == true ||
                  (data['isActive'] == null && data['is_active'] == null);
              if (!isActive) return false;

              final screens = data['showOnScreens'] ?? data['show_on_screens'];
              if (screens is List && screens.isNotEmpty) {
                final screenList = screens.map((s) => s.toString()).toList();
                return screenList.contains(widget.screenName) ||
                    screenList.contains('all');
              }
              return true;
            })
            .map((row) {
              final data = row['data'] is Map
                  ? (row['data'] as Map<String, dynamic>)
                  : <String, dynamic>{};
              return {
                'id': row['id'],
                'title': row['title'] ?? data['title'],
                'description': row['body'] ?? data['description'],
                ...data,
              };
            })
            .toList();

        if (matchingAds.isEmpty) {
          return const SizedBox.shrink();
        }

        final adData = matchingAds.first;

        final currentLang = langProvider.currentLanguage;
        String title = (adData['title'] ?? '').toString();
        final titleAr =
            (adData['titleAr'] ?? adData['title_ar'])?.toString() ?? '';
        final titleEn =
            (adData['titleEn'] ?? adData['title_en'])?.toString() ?? '';
        if (currentLang == AppLanguage.arabic && titleAr.isNotEmpty) {
          title = titleAr;
        } else if (currentLang == AppLanguage.english && titleEn.isNotEmpty) {
          title = titleEn;
        }

        String description = (adData['description'] ?? '').toString();
        final descAr =
            (adData['descAr'] ?? adData['desc_ar'])?.toString() ?? '';
        final descEn =
            (adData['descEn'] ?? adData['desc_en'])?.toString() ?? '';
        if (currentLang == AppLanguage.arabic && descAr.isNotEmpty) {
          description = descAr;
        } else if (currentLang == AppLanguage.english && descEn.isNotEmpty) {
          description = descEn;
        }

        String buttonText =
            (adData['buttonTextKu'] ?? adData['button_text_ku'] ?? 'سەردان بکە')
                .toString();
        final btnAr =
            (adData['buttonTextAr'] ?? adData['button_text_ar'])?.toString() ??
            '';
        final btnEn =
            (adData['buttonTextEn'] ?? adData['button_text_en'])?.toString() ??
            '';
        if (currentLang == AppLanguage.arabic && btnAr.isNotEmpty) {
          buttonText = btnAr;
        } else if (currentLang == AppLanguage.english && btnEn.isNotEmpty) {
          buttonText = btnEn;
        }

        final imageUrl = (adData['imageUrl'] ?? adData['image_url']) as String?;
        final linkUrl = (adData['linkUrl'] ?? adData['link_url'] ?? '')
            .toString();

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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ZankoColors.primary.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.speaker_2_fill,
                                            size: 11,
                                            color: ZankoColors.primary,
                                          ),
                                          const SizedBox(width: 4),
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
                                      color: isDark
                                          ? Colors.white
                                          : ZankoColors.textPrimary,
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
                                      color: isDark
                                          ? Colors.grey[400]
                                          : ZankoColors.textSecondary,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
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
