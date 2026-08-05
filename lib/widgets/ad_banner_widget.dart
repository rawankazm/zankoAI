import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

/// Reads active ads from Firestore and shows them as a hero banner matching the premium design.
/// Pass [screenName] matching one of the screen IDs set in the Admin panel.
/// If no active ad targets this screen, the widget renders as SizedBox.shrink().
class AdBannerWidget extends StatefulWidget {
  final String screenName;

  const AdBannerWidget({super.key, required this.screenName});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget>
    with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _ads = [];
  int _currentIndex = 0;
  StreamSubscription? _sub;
  Timer? _rotateTimer;
  bool _dismissed = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);

    _listenToAds();
  }

  void _listenToAds() {
    _sub = FirebaseFirestore.instance
        .collection('ads')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      final filtered = snap.docs
          .map((d) => {...d.data(), 'id': d.id})
          .where((ad) {
            final screens = List<String>.from(ad['showOnScreens'] ?? []);
            return screens.contains(widget.screenName);
          })
          .toList();

      if (mounted) {
        setState(() {
          _ads.clear();
          _ads.addAll(filtered);
          _currentIndex = 0;
        });
        _startRotation();
      }
    });
  }

  void _startRotation() {
    _rotateTimer?.cancel();
    if (_ads.length > 1) {
      _rotateTimer = Timer.periodic(const Duration(seconds: 7), (_) {
        if (!mounted) return;
        _fadeCtrl.reverse().then((_) {
          if (!mounted) return;
          setState(() => _currentIndex = (_currentIndex + 1) % _ads.length);
          _fadeCtrl.forward();
        });
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _rotateTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _openLink(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _getLocalizedField(Map<String, dynamic> ad, String langCode, String fieldName) {
    if (langCode == 'ar') {
      final arVal = ad['${fieldName}Ar'] ?? ad['${fieldName}_ar'];
      if (arVal != null && arVal.toString().isNotEmpty) return arVal.toString();
    } else if (langCode == 'en') {
      final enVal = ad['${fieldName}En'] ?? ad['${fieldName}_en'];
      if (enVal != null && enVal.toString().isNotEmpty) return enVal.toString();
    }
    // Fallback to Kurdish / default
    final kuVal = ad['${fieldName}Ku'] ?? ad[fieldName];
    return kuVal?.toString() ?? '';
  }

  String _getLocalizedButtonText(Map<String, dynamic> ad, String langCode) {
    if (langCode == 'ar') {
      final val = ad['buttonTextAr'];
      if (val != null && val.toString().isNotEmpty) return val.toString();
      return 'تفاصيل';
    } else if (langCode == 'en') {
      final val = ad['buttonTextEn'];
      if (val != null && val.toString().isNotEmpty) return val.toString();
      return 'View More';
    }
    final val = ad['buttonTextKu'];
    if (val != null && val.toString().isNotEmpty) return val.toString();
    return 'زیاتر ببینە';
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _ads.isEmpty) return const SizedBox.shrink();

    final ad = _ads[_currentIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = (ad['imageUrl'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;

    final langCode = Localizations.localeOf(context).languageCode;
    final title = _getLocalizedField(ad, langCode, 'title');
    final description = _getLocalizedField(ad, langCode, 'description');
    final buttonText = _getLocalizedButtonText(ad, langCode);

    final cardBgColor = isDark ? const Color(0xFF1B2033) : const Color(0xFF1A1F36);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        height: 185,
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // ── Background & Image Split ─────────────────────────────────
              Row(
                children: [
                  // Left Side Content Area
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 18, right: 14, top: 16, bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 🏷️ Badge Pill (e.g., ڕیکلام / سپۆنسەر)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.4)),
                            ),
                            child: Text(
                              langCode == 'ar' ? 'إعلان' : (langCode == 'en' ? 'Sponsored' : 'ڕیکلام'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF93C5FD),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 📌 Title
                          Text(
                            title.isNotEmpty ? title : (ad['title'] ?? ''),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.25,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          // 📝 Description
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.35,
                                color: Colors.grey[300],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                          const Spacer(),

                          // 🔘 CTA Action Button
                          GestureDetector(
                            onTap: () => _openLink(ad['linkUrl']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    buttonText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Side Image Area with Gradient Blend
                  Expanded(
                    flex: 5,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: hasImage
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _adPlaceholder(),
                                  errorWidget: (_, __, ___) => _adPlaceholder(),
                                )
                              : _adPlaceholder(),
                        ),
                        // Gradient Overlay to blend image smoothly into text
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cardBgColor,
                                  cardBgColor.withOpacity(0.7),
                                  Colors.transparent,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: const [0.0, 0.25, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Dismiss Button ────────────────────────────────────────────
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: () => setState(() => _dismissed = true),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),

              // ── Dot Indicators (if multiple ads) ─────────────────────────
              if (_ads.length > 1)
                Positioned(
                  bottom: 12,
                  left: 18,
                  child: Row(
                    children: List.generate(
                      _ads.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: i == _currentIndex ? 16 : 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: i == _currentIndex
                              ? const Color(0xFF8B5CF6)
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adPlaceholder() => Container(
        color: const Color(0xFF282F4B),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📢', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 4),
              Text(
                'ZankoAI Sponsor',
                style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      );
}
