// ==============================================================================
// ZankoAI Premium Subscription Screen
// Responsive, Kurdish-first, Zero Client Trust, Hosted Checkout
// ==============================================================================

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_error.dart';
import '../../models/subscription_model.dart';
import '../../services/auth_service.dart';
import '../../services/language_provider.dart';
import '../../services/subscription_client_service.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../payment/vip_upgrade_sheet.dart';

class PremiumSubscriptionScreen extends StatefulWidget {
  final SubscriptionClientService? clientService;
  const PremiumSubscriptionScreen({super.key, this.clientService});

  /// Convenient static launcher that can be pushed or shown as a modal sheet
  static Future<void> show(BuildContext context, {SubscriptionClientService? clientService}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumSubscriptionScreen(clientService: clientService),
      ),
    );
  }

  @override
  State<PremiumSubscriptionScreen> createState() =>
      _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen> {
  late final SubscriptionClientService _subscriptionService;

  bool _isLoading = true;
  UserSubscriptionModel? _subscription;
  String? _errorMessage;

  // Selected options
  SubscriptionPlanType _selectedPlan = SubscriptionPlanType.premiumMonthly;
  PaymentProviderOption _selectedProvider = PaymentProviderOption.fastpay;
  String _selectedTab = 'PREMIUM'; // 'FREE' or 'PREMIUM'

  // Payment flow state
  SubscriptionFlowState _flowState = SubscriptionFlowState.idle;
  SubscriptionCheckoutModel? _checkoutSession;
  Timer? _verificationPollTimer;
  String? _flowMessage;

  @override
  void initState() {
    super.initState();
    _subscriptionService = widget.clientService ?? SubscriptionClientService.instance;
    _fetchAuthoritativeSubscription();
  }

  @override
  void dispose() {
    _verificationPollTimer?.cancel();
    super.dispose();
  }

  /// Fetches authoritative server status via GET /api/subscription
  Future<void> _fetchAuthoritativeSubscription({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final sub = await _subscriptionService.getSubscription();
      if (!mounted) return;

      setState(() {
        _subscription = sub;
        _isLoading = false;

        // If active premium is verified by server, update flow state
        if (sub.canAccessPremiumFeatures) {
          _verificationPollTimer?.cancel();
          if (_flowState == SubscriptionFlowState.paymentPending ||
              _flowState == SubscriptionFlowState.verifying) {
            _flowState = SubscriptionFlowState.paymentSuccessful;
            _flowMessage = 'Payment successful! Premium activated.';
          }
        }
      });

      // Synchronize with app auth state if user is logged in
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.currentUser != null && sub.isPremium) {
        auth.reloadUser();
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (!silent) {
          _errorMessage = _extractErrorMessage(err);
        }
      });
    }
  }

  String _extractErrorMessage(dynamic err) {
    if (err is DioException) {
      final apiErr = ApiError.fromDioException(err);
      return apiErr.message;
    }
    final str = err.toString();
    if (str.contains('NETWORK_ERROR') || str.contains('connection error')) {
      return 'پەیوەندی بە سێرڤەرەوە پچڕا، تکایە دڵنیابە لە هەبوونی ئینتەرنێت یان بەردەستبوونی باکێند.';
    }
    return str;
  }

  /// Starts the hosted checkout flow: POST /api/subscription/checkout
  Future<void> _handleUpgrade() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null || user.isGuest) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() {
      _flowState = SubscriptionFlowState.loading;
      _flowMessage = null;
      _checkoutSession = null;
    });

    try {
      final checkout = await _subscriptionService.createCheckout(
        plan: _selectedPlan,
        provider: _selectedProvider.id,
      );

      if (!mounted) return;

      setState(() {
        _checkoutSession = checkout;
        _flowState = SubscriptionFlowState.paymentPending;
        _flowMessage =
            'چاوەڕوانی تەواوکردنی پارەدان لە پەڕەی دەروازەی پارێزراودا...';
      });

      // Launch provider's official hosted/redirect URL
      if (checkout.checkoutUrl != null && checkout.checkoutUrl!.isNotEmpty) {
        await SubscriptionClientService.launchCheckoutUrl(
          checkout.checkoutUrl!,
        );
      }

      // Start automatic polling every 4 seconds to verify server-side state
      _startVerificationPolling();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _flowState = SubscriptionFlowState.paymentFailed;
        _flowMessage = 'هەڵەیەک ڕوویدا لە دروستکردنی پارەدان: ${_extractErrorMessage(err)}';
      });
    }
  }

  /// Initiates polling for server-side verification
  void _startVerificationPolling() {
    _verificationPollTimer?.cancel();
    int attempts = 0;
    const maxAttempts = 30; // 2 minutes total (30 * 4s)

    _verificationPollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (timer) async {
        attempts++;
        if (!mounted || attempts > maxAttempts) {
          timer.cancel();
          return;
        }

        try {
          final sub = await _subscriptionService.getSubscription();
          if (!mounted) return;

          if (sub.canAccessPremiumFeatures) {
            timer.cancel();
            setState(() {
              _subscription = sub;
              _flowState = SubscriptionFlowState.paymentSuccessful;
              _flowMessage =
                  'پیرۆزە! ئابوونەی پرێمیۆم بە سەرکەوتوویی لە سێرڤەرەوە پشتڕاستکرایەوە.';
            });
            final auth = Provider.of<AuthService>(context, listen: false);
            auth.reloadUser();
          }
        } catch (_) {
          // Ignore intermittent poll errors
        }
      },
    );
  }

  /// Manual button tap to verify payment via GET /api/subscription
  Future<void> _manualVerifyPayment() async {
    setState(() {
      _flowState = SubscriptionFlowState.verifying;
    });

    try {
      final sub = await _subscriptionService.getSubscription();
      if (!mounted) return;

      setState(() {
        _subscription = sub;
        if (sub.canAccessPremiumFeatures) {
          _flowState = SubscriptionFlowState.paymentSuccessful;
          _flowMessage =
              'پیرۆزە! ئابوونەی پرێمیۆم بە سەرکەوتوویی لە سێرڤەرەوە پشتڕاستکرایەوە.';
          _verificationPollTimer?.cancel();
          final auth = Provider.of<AuthService>(context, listen: false);
          auth.reloadUser();
        } else {
          _flowState = SubscriptionFlowState.paymentPending;
          _flowMessage =
              'پارەدانەکە هێشتا لە لایەن دەروازەکەوە پەسەند نەکراوە. تکایە دوای ئەنجامدانی پارەدان چەند چرکەیەک چاوەڕێ بکە و دووبارە دابگرە.';
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _flowState = SubscriptionFlowState.paymentPending;
        _flowMessage = 'نەتوانرا پەیوەندی بە سێرڤەرەوە بکرێت: ${_extractErrorMessage(err)}';
      });
    }
  }

  void _showLoginRequiredDialog() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZankoRadius.card),
        ),
        title: Text(
          lang.translate('login_required'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(lang.translate('login_to_continue')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZankoColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/login');
            },
            child: Text(lang.translate('login')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? ZankoColors.darkBackground : const Color(0xFFF7F9FC);

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: isDark ? ZankoColors.darkCard : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: appIcon(HugeIcons.strokeRoundedArrowLeft01),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            lang.translate('plan_premium'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: appIcon(HugeIcons.strokeRoundedRefresh),
              tooltip: lang.translate('verify_payment'),
              onPressed: () => _fetchAuthoritativeSubscription(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 16))
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: RefreshIndicator(
                        onRefresh: () => _fetchAuthoritativeSubscription(),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          children: [
                            if (_errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(ZankoRadius.card),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        appIcon(HugeIcons.strokeRoundedAlertCircle,
                                            color: Colors.red, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        icon: appIcon(
                                            HugeIcons.strokeRoundedWallet02,
                                            size: 16,
                                            color: Colors.white),
                                        label: const Text(
                                          'داواکردنی ڕاستەوخۆ بە (FastPay / FIB / ZainCash)',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () =>
                                            VipUpgradeSheet.show(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // 1. Current Plan & Status Header
                            _buildCurrentPlanHeader(lang, isDark),
                            const SizedBox(height: 16),

                            // 2. Active Flow State Banner (Pending, Successful, Failed)
                            if (_flowState != SubscriptionFlowState.idle)
                              _buildFlowStateBanner(lang, isDark),

                            // 3. Live Quotas & Remaining Usage Breakdown
                            _buildUsageBreakdownCard(lang, isDark),
                            const SizedBox(height: 20),

                            // 4. FREE vs PREMIUM Comparison Selector
                            _buildPlanComparisonSection(lang, isDark),
                            const SizedBox(height: 20),

                            // 5. Monthly / Yearly Billing Cycle Switcher
                            _buildBillingCycleSwitcher(lang, isDark),
                            const SizedBox(height: 20),

                            // 6. Payment Provider Options (FastPay, FIB, ZainCash, Qi Card)
                            _buildPaymentMethodOptions(lang, isDark),
                            const SizedBox(height: 16),

                            // 7. Security Notice (Zero Raw Card Storage)
                            _buildSecurityNotice(lang, isDark),
                            const SizedBox(height: 24),

                            // 8. Action Button (Upgrade to Premium / Verify)
                            _buildActionButton(lang, isDark),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. Current Plan Header & Authoritative Subscription Status
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildCurrentPlanHeader(LanguageProvider lang, bool isDark) {
    final sub = _subscription;
    // Strict server verification: do NOT display Premium unless backend confirms it
    final isPremium = sub != null && sub.canAccessPremiumFeatures;
    final status = sub?.status ?? SubscriptionStatusType.expired;

    String statusText;
    Color statusColor;
    dynamic statusIcon;

    if (isPremium) {
      statusText = lang.translate('subscription_active');
      statusColor = const Color(0xFF10B981); // Emerald
      statusIcon = HugeIcons.strokeRoundedCheckmarkBadge01;
    } else if (status == SubscriptionStatusType.pastDue) {
      statusText = 'لە قۆناغی چاوەڕوانی پارەدان (Past Due)';
      statusColor = const Color(0xFFF59E0B); // Amber
      statusIcon = HugeIcons.strokeRoundedClock01;
    } else if (status == SubscriptionStatusType.canceled) {
      statusText = 'ئابوونە هەڵوەشێندراوەتەوە';
      statusColor = const Color(0xFF6B7280);
      statusIcon = HugeIcons.strokeRoundedCancel01;
    } else {
      statusText = lang.translate('subscription_expired');
      statusColor = const Color(0xFFEF4444); // Red
      statusIcon = HugeIcons.strokeRoundedAlertCircle;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPremium
            ? LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [const Color(0xFF035EC2), const Color(0xFF023E8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isPremium
            ? null
            : (isDark ? ZankoColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(ZankoRadius.card),
        border: Border.all(
          color: isPremium
              ? const Color(0xFFE4D27D)
              : (isDark ? ZankoColors.darkBorder : ZankoColors.border),
          width: isPremium ? 1.5 : 1.0,
        ),
        boxShadow: ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Plan Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFFE4D27D)
                      : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    appIcon(
                      isPremium
                          ? HugeIcons.strokeRoundedCrown
                          : HugeIcons.strokeRoundedUser,
                      size: 16,
                      color: isPremium
                          ? const Color(0xFF0F172A)
                          : ZankoColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPremium
                          ? lang.translate('plan_premium')
                          : lang.translate('plan_free'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isPremium
                            ? const Color(0xFF0F172A)
                            : ZankoColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status Chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    appIcon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Title & Explanation
          Text(
            isPremium
                ? 'تۆ خاوەنی هەژماری تایبەتی پرێمیۆمی ZankoAI یت ✨'
                : 'پلانی ئێستات بەخۆڕاییە (Free Plan)',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isPremium
                  ? Colors.white
                  : (isDark ? Colors.white : ZankoColors.textPrimary),
            ),
          ),
          const SizedBox(height: 6),

          // Renewal Date / Expiry Date
          if (isPremium && sub.currentPeriodEnd != null)
            Row(
              children: [
                appIcon(
                  HugeIcons.strokeRoundedCalendar03,
                  size: 15,
                  color: isPremium
                      ? const Color(0xFFE4D27D)
                      : ZankoColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${lang.translate('renewal_date')}: ${_formatDate(sub.currentPeriodEnd!)} (${sub.daysRemaining} ڕۆژی ماوە)',
                  style: TextStyle(
                    fontSize: 13,
                    color: isPremium
                        ? Colors.white.withValues(alpha: 0.9)
                        : ZankoColors.textSecondary,
                  ),
                ),
              ],
            )
          else
            Text(
              'بەرزبکەرەوە بۆ پرێمیۆم بۆ ئەوەی دەستت بگات بە ژیری دەستکردی خێرا و سەروو ٥٠٠ پرسیاری ڕۆژانە.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? ZankoColors.darkTextSecondary
                    : ZankoColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. Flow State Banner (Payment Pending, Successful, Failed, Verifying)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFlowStateBanner(LanguageProvider lang, bool isDark) {
    Color bannerColor;
    dynamic bannerIcon;
    String bannerTitle;

    switch (_flowState) {
      case SubscriptionFlowState.paymentPending:
        bannerColor = const Color(0xFFF59E0B); // Amber
        bannerIcon = HugeIcons.strokeRoundedClock01;
        bannerTitle = lang.translate('payment_pending');
        break;
      case SubscriptionFlowState.verifying:
        bannerColor = ZankoColors.primary;
        bannerIcon = HugeIcons.strokeRoundedRefresh;
        bannerTitle = lang.translate('verify_payment');
        break;
      case SubscriptionFlowState.paymentSuccessful:
        bannerColor = const Color(0xFF10B981); // Emerald
        bannerIcon = HugeIcons.strokeRoundedCheckmarkBadge01;
        bannerTitle = lang.translate('payment_successful');
        break;
      case SubscriptionFlowState.paymentFailed:
        bannerColor = const Color(0xFFEF4444); // Red
        bannerIcon = HugeIcons.strokeRoundedCancel01;
        bannerTitle = lang.translate('payment_failed');
        break;
      case SubscriptionFlowState.loading:
      case SubscriptionFlowState.idle:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ZankoRadius.card),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _flowState == SubscriptionFlowState.verifying
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: bannerColor,
                      ),
                    )
                  : appIcon(bannerIcon, color: bannerColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bannerTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: bannerColor,
                  ),
                ),
              ),
            ],
          ),
          if (_flowMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _flowMessage!,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
            ),
          ],

          // If payment is pending and dynamic QR payload exists (e.g. FIB)
          if (_flowState == SubscriptionFlowState.paymentPending &&
              _checkoutSession?.qrPayload != null &&
              _checkoutSession!.qrPayload!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: ZankoShadows.soft,
                ),
                child: QrImageView(
                  data: _checkoutSession!.qrPayload!,
                  version: QrVersions.auto,
                  size: 180.0,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'کۆدی QR سکان بکە لە ڕێگەی ئەپی FIB یان دەروازەکەت',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
          ],

          // Buttons for pending payment state
          if (_flowState == SubscriptionFlowState.paymentPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ZankoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZankoRadius.button),
                      ),
                    ),
                    icon: appIcon(HugeIcons.strokeRoundedRefresh,
                        size: 16, color: Colors.white),
                    label: Text(lang.translate('verify_payment')),
                    onPressed: _manualVerifyPayment,
                  ),
                ),
                if (_checkoutSession?.checkoutUrl != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: bannerColor,
                      side: BorderSide(color: bannerColor),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ZankoRadius.button),
                      ),
                    ),
                    icon: appIcon(HugeIcons.strokeRoundedGlobe,
                        size: 16, color: bannerColor),
                    label: const Text('کردنەوەی دەروازە'),
                    onPressed: () {
                      SubscriptionClientService.launchCheckoutUrl(
                        _checkoutSession!.checkoutUrl!,
                      );
                    },
                  ),
                ],
              ],
            ),
          ],

          // Direct VIP Request button when payment fails or backend is offline
          if (_flowState == SubscriptionFlowState.paymentFailed) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ZankoRadius.button),
                  ),
                ),
                icon: appIcon(HugeIcons.strokeRoundedWallet02,
                    size: 16, color: Colors.white),
                label: const Text(
                  'داواکردنی ڕاستەوخۆ بە (FastPay / FIB / ZainCash)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () => VipUpgradeSheet.show(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. Authoritative Usage & Quota Breakdown Card
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildUsageBreakdownCard(LanguageProvider lang, bool isDark) {
    final sub = _subscription;
    final usage = sub?.usage;
    final isPremium = sub?.canAccessPremiumFeatures ?? false;

    // Feature list with authoritatively tracked quotas or defaults
    final featuresList = [
      _FeatureMetric(
        id: 'ai_chat',
        title: lang.translate('feature_ai_chat'),
        icon: HugeIcons.strokeRoundedAiMagic,
        currentUsage: usage?.getFeature('ai_chat')?.currentUsage ?? 0,
        limit: usage?.getFeature('ai_chat')?.limit ?? (isPremium ? 500 : 10),
        remaining: usage?.getFeature('ai_chat')?.remaining ??
            (isPremium ? 500 : 10),
        period: 'daily',
        resetAt: usage?.getFeature('ai_chat')?.resetAt,
        unit: 'پرسیار',
      ),
      _FeatureMetric(
        id: 'pdf',
        title: lang.translate('feature_pdf'),
        icon: HugeIcons.strokeRoundedBook02,
        currentUsage: usage?.getFeature('pdf')?.currentUsage ?? 0,
        limit: usage?.getFeature('pdf')?.limit ?? (isPremium ? 100 : 3),
        remaining: usage?.getFeature('pdf')?.remaining ?? (isPremium ? 100 : 3),
        period: 'monthly',
        resetAt: usage?.getFeature('pdf')?.resetAt,
        unit: 'کتێب / فایل',
      ),
      _FeatureMetric(
        id: 'ocr',
        title: lang.translate('feature_ocr'),
        icon: HugeIcons.strokeRoundedCamera01,
        currentUsage: usage?.getFeature('ocr')?.currentUsage ?? 0,
        limit: usage?.getFeature('ocr')?.limit ?? (isPremium ? 200 : 10),
        remaining: usage?.getFeature('ocr')?.remaining ?? (isPremium ? 200 : 10),
        period: 'monthly',
        resetAt: usage?.getFeature('ocr')?.resetAt,
        unit: 'لاپەڕە',
      ),
      _FeatureMetric(
        id: 'homework',
        title: lang.translate('feature_homework'),
        icon: HugeIcons.strokeRoundedPencilEdit02,
        currentUsage: usage?.getFeature('homework')?.currentUsage ?? 0,
        limit: usage?.getFeature('homework')?.limit ?? (isPremium ? 200 : 10),
        remaining: usage?.getFeature('homework')?.remaining ??
            (isPremium ? 200 : 10),
        period: 'daily',
        resetAt: usage?.getFeature('homework')?.resetAt,
        unit: 'پرسیار',
      ),
      _FeatureMetric(
        id: 'audio',
        title: lang.translate('feature_audio'),
        icon: HugeIcons.strokeRoundedMic01,
        currentUsage: usage?.getFeature('audio')?.currentUsage ?? 0,
        limit: usage?.getFeature('audio')?.limit ?? (isPremium ? 100 : 5),
        remaining: usage?.getFeature('audio')?.remaining ?? (isPremium ? 100 : 5),
        period: 'monthly',
        resetAt: usage?.getFeature('audio')?.resetAt,
        unit: 'تۆمار',
      ),
      _FeatureMetric(
        id: 'quiz',
        title: lang.translate('feature_quiz'),
        icon: HugeIcons.strokeRoundedMortarboard02,
        currentUsage: usage?.getFeature('quiz')?.currentUsage ?? 0,
        limit: usage?.getFeature('quiz')?.limit ?? (isPremium ? 200 : 5),
        remaining: usage?.getFeature('quiz')?.remaining ?? (isPremium ? 200 : 5),
        period: 'monthly',
        resetAt: usage?.getFeature('quiz')?.resetAt,
        unit: 'تاقیکردنەوە',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(ZankoRadius.card),
        border: Border.all(
          color: isDark ? ZankoColors.darkBorder : ZankoColors.border,
        ),
        boxShadow: ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ڕێژەی بەکارهێنان و کۆتای ماوە',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    appIcon(
                      HugeIcons.strokeRoundedClock01,
                      size: 13,
                      color:
                          isDark ? Colors.white60 : ZankoColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ئەمشەو 12:00 نوێ دەبێتەوە',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? Colors.white70 : ZankoColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Render each feature progress bar
          ...featuresList.map((f) => _buildFeatureUsageRow(f, lang, isDark)),
        ],
      ),
    );
  }

  Widget _buildFeatureUsageRow(
    _FeatureMetric metric,
    LanguageProvider lang,
    bool isDark,
  ) {
    final ratio = metric.limit <= 0
        ? 0.0
        : (metric.currentUsage / metric.limit).clamp(0.0, 1.0);

    Color progressColor;
    if (ratio >= 0.9) {
      progressColor = const Color(0xFFEF4444); // Red
    } else if (ratio >= 0.7) {
      progressColor = const Color(0xFFF59E0B); // Amber
    } else {
      progressColor = const Color(0xFF035EC2); // Zanko Blue
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              appIcon(
                metric.icon,
                size: 16,
                color: isDark ? const Color(0xFFE4D27D) : ZankoColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  metric.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                  ),
                ),
              ),
              // Used vs Limit
              Text(
                '${metric.currentUsage} / ${metric.limit} ${metric.unit}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : ZankoColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor:
                  isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 4),

          // Remaining & Period text
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ماوە: ${metric.remaining} ${metric.unit}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: metric.remaining <= 0
                      ? const Color(0xFFEF4444)
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
              Text(
                metric.period == 'daily'
                    ? 'نوێبوونەوە: ڕۆژانە'
                    : 'نوێبوونەوە: مانگانە',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. FREE vs PREMIUM Comparison Section
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPlanComparisonSection(LanguageProvider lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                lang.translate('free_vs_premium'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Segmented switch between FREE & PREMIUM view
            Container(
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : const Color(0xFFECEFF4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _buildTabButton('FREE', 'بەخۆڕایی', isDark),
                  _buildTabButton('PREMIUM', 'پرێمیۆم ⭐', isDark),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Active Comparison Cards
        _selectedTab == 'FREE'
            ? _buildFreePlanCard(lang, isDark)
            : _buildPremiumPlanCard(lang, isDark),
      ],
    );
  }

  Widget _buildTabButton(String tabKey, String label, bool isDark) {
    final isSelected = _selectedTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (tabKey == 'PREMIUM'
                  ? const Color(0xFF035EC2)
                  : (isDark ? Colors.white24 : Colors.white))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : ZankoColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildFreePlanCard(LanguageProvider lang, bool isDark) {
    final benefits = [
      '١٠ پرسیاری ژیریی دەستکرد لە ڕۆژێکدا',
      '٣ کتێب و فایلی PDF لە مانگێکدا',
      '١٠ سکانی وێنەی دەق و کتێب (OCR)',
      '١٠ شیکاری ئەرکی ماڵەوە',
      '٥ تۆماری دەنگی کورت',
      '٥ تاقیکردنەوەی پێشبینیکراو لە مانگێکدا',
      '٥٠ مێگابایت کۆگای هەوری',
      'خێرایی ئاسایی سێرڤەر',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(ZankoRadius.card),
        border: Border.all(
          color: isDark ? ZankoColors.darkBorder : ZankoColors.border,
        ),
        boxShadow: ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'پلانی ئاسایی (FREE)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              const Text(
                '٠ دینار / هەتاهەتایە',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...benefits.map((b) => _buildCheckItem(b, false, isDark)),
        ],
      ),
    );
  }

  Widget _buildPremiumPlanCard(LanguageProvider lang, bool isDark) {
    final benefits = [
      '🚀 ٥٠٠ پرسیاری ژیریی دەستکرد لە ڕۆژێکدا (٥٠ هێندە زیاتر)',
      '📚 ١٠٠ کتێب و کورتەی فایلی گەورەی PDF لە مانگێکدا',
      '🔍 ٢٠٠ سکان و وەرگێڕانی وێنەی کتێب (OCR بێ سنوور)',
      '✍️ ٢٠٠ شیکاری ئەرکی ماڵەوە بە هەنگاو و ڕوونکردنەوەی تەواو',
      '🎙️ ١٠٠ تۆماری وانە و گۆڕینی دەنگ بۆ دەق بە کوردی',
      '🎯 ٢٠٠ تاقیکردنەوە و پرسیاری وزاری لە مانگێکدا',
      '☁️ ٥ گێگابایت کۆگای هەوری بۆ سەرجەم وانەکانت',
      '⚡ ئەولەویەتی بەرز لە سێرڤەری GPU و وەڵامدانەوەی دەستبەجێ',
      '🚫 بە تەواوی بێ ڕیکلام و بێ ئاڵۆزی',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFF023E8A), const Color(0xFF035EC2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZankoRadius.card),
        border: Border.all(color: const Color(0xFFE4D27D), width: 1.5),
        boxShadow: ZankoShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  appIcon(
                    HugeIcons.strokeRoundedCrown,
                    color: const Color(0xFFE4D27D),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'تایبەتمەندییە باڵاکانی پرێمیۆم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4D27D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'باشترین هەڵبژاردن',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...benefits.map((b) => _buildCheckItem(b, true, isDark)),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isPremiumCard, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          appIcon(
            isPremiumCard
                ? HugeIcons.strokeRoundedCheckmarkBadge01
                : HugeIcons.strokeRoundedCheckmarkCircle01,
            size: 16,
            color: isPremiumCard
                ? const Color(0xFFE4D27D)
                : const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isPremiumCard
                    ? Colors.white.withValues(alpha: 0.95)
                    : (isDark ? Colors.white70 : ZankoColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. 3 Subscription Offers Switcher & Pricing (1m 5000, 3m 12000, 9m 40000)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildBillingCycleSwitcher(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(ZankoRadius.card),
        border: Border.all(
          color: isDark ? ZankoColors.darkBorder : ZankoColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'هەڵبژاردنی ئۆفەری ئابوونە',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4D27D).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '٣ ئۆفەری تایبەت ✨',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE4D27D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final cards = [
                // 1 Month: 5,000 IQD
                _buildPricingOptionCard(
                  title: '١ مانگ',
                  price: '٥,٠٠٠ د.ع',
                  period: '٣٠ ڕۆژ',
                  isSelected:
                      _selectedPlan == SubscriptionPlanType.premiumMonthly,
                  isDark: isDark,
                  badge: null,
                  onTap: () {
                    setState(() {
                      _selectedPlan = SubscriptionPlanType.premiumMonthly;
                    });
                  },
                ),
                // 3 Months: 12,000 IQD
                _buildPricingOptionCard(
                  title: '٣ مانگ',
                  price: '١٢,٠٠٠ د.ع',
                  period: '٩٠ ڕۆژ',
                  isSelected:
                      _selectedPlan == SubscriptionPlanType.premiumQuarterly,
                  isDark: isDark,
                  badge: 'داشکاندن',
                  onTap: () {
                    setState(() {
                      _selectedPlan = SubscriptionPlanType.premiumQuarterly;
                    });
                  },
                ),
                // 9 Months: 40,000 IQD
                _buildPricingOptionCard(
                  title: '٩ مانگ',
                  price: '٤٠,٠٠٠ د.ع',
                  period: 'ساڵی خوێندن',
                  isSelected:
                      _selectedPlan == SubscriptionPlanType.premiumYearly,
                  isDark: isDark,
                  badge: 'باشترین ⭐',
                  onTap: () {
                    setState(() {
                      _selectedPlan = SubscriptionPlanType.premiumYearly;
                    });
                  },
                ),
              ];

              if (isNarrow) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 8),
                    cards[1],
                    const SizedBox(height: 8),
                    cards[2],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPricingOptionCard({
    required String title,
    required String price,
    required String period,
    required bool isSelected,
    required bool isDark,
    String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? ZankoColors.primary.withValues(alpha: 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? ZankoColors.primary
                : (isDark ? ZankoColors.darkBorder : ZankoColors.border),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? ZankoColors.primary
                        : (isDark ? Colors.white : ZankoColors.textPrimary),
                  ),
                ),
                appIcon(
                  isSelected
                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                      : HugeIcons.strokeRoundedCircle,
                  color: isSelected
                      ? ZankoColors.primary
                      : (isDark ? Colors.white38 : Colors.grey),
                  size: 18,
                ),
              ],
            ),
            if (badge != null) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : ZankoColors.textPrimary,
              ),
            ),
            Text(
              period,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : ZankoColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. Pluggable Payment Method Options (Iraqi Gateways)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildPaymentMethodOptions(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(ZankoRadius.card),
        border: Border.all(
          color: isDark ? ZankoColors.darkBorder : ZankoColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              appIcon(
                HugeIcons.strokeRoundedCreditCard,
                size: 18,
                color: ZankoColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                lang.translate('payment_method_options'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Provider Cards Grid
          ...PaymentProviderOption.values.map(
            (provider) => _buildProviderOptionTile(provider, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOptionTile(
    PaymentProviderOption provider,
    bool isDark,
  ) {
    final isSelected = _selectedProvider == provider;
    final brandColor = Color(provider.primaryColorHex);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProvider = provider;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? brandColor.withValues(alpha: 0.08)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : const Color(0xFFFAFAFA)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? brandColor
                : (isDark ? ZankoColors.darkBorder : ZankoColors.border),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: appIcon(
                  HugeIcons.strokeRoundedWallet02,
                  color: brandColor,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.kurdishName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : ZankoColors.textPrimary,
                    ),
                  ),
                  Text(
                    provider.englishName,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isDark ? Colors.white60 : ZankoColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            appIcon(
              isSelected
                  ? HugeIcons.strokeRoundedCheckmarkCircle02
                  : HugeIcons.strokeRoundedCircle,
              color: isSelected
                  ? brandColor
                  : (isDark ? Colors.white38 : Colors.grey),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 7. Security Notice (Zero Raw Card Collection)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildSecurityNotice(LanguageProvider lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          appIcon(
            HugeIcons.strokeRoundedSecurityCheck,
            size: 20,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lang.translate('secure_checkout_notice'),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 8. Action Button (Upgrade to Premium / Verify)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildActionButton(LanguageProvider lang, bool isDark) {
    final isPending = _flowState == SubscriptionFlowState.paymentPending;
    final isLoading = _flowState == SubscriptionFlowState.loading ||
        _flowState == SubscriptionFlowState.verifying;

    if (isPending) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(ZankoRadius.button),
                ),
                elevation: 2,
              ),
              icon: isLoading
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : appIcon(HugeIcons.strokeRoundedCheckmarkBadge01,
                      color: Colors.white, size: 20),
              label: Text(
                lang.translate('verify_payment'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: isLoading ? null : _manualVerifyPayment,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              setState(() {
                _flowState = SubscriptionFlowState.idle;
                _verificationPollTimer?.cancel();
              });
            },
            child: const Text('پاشگەزبوونەوە لە پارەدان'),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZankoColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZankoRadius.button),
              ),
              elevation: 3,
            ),
            onPressed: isLoading ? null : _handleUpgrade,
            child: isLoading
                ? const CupertinoActivityIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      appIcon(HugeIcons.strokeRoundedCrown,
                          size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'نوێکردنەوە بۆ پرێمیۆم (${_selectedPlan.priceIqd == 5000 ? "٥,٠٠٠" : (_selectedPlan.priceIqd == 12000 ? "١٢,٠٠٠" : "٤٠,٠٠٠")} دینار)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF10B981),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(ZankoRadius.button),
              ),
            ),
            icon: appIcon(HugeIcons.strokeRoundedWallet02,
                size: 18, color: const Color(0xFF10B981)),
            label: const Text(
              'داواکردنی ڕاستەوخۆ بە (FastPay / FIB / ZainCash)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () => VipUpgradeSheet.show(context),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

class _FeatureMetric {
  final String id;
  final String title;
  final dynamic icon;
  final int currentUsage;
  final int limit;
  final int remaining;
  final String period; // 'daily' or 'monthly'
  final DateTime? resetAt;
  final String unit;

  const _FeatureMetric({
    required this.id,
    required this.title,
    required this.icon,
    required this.currentUsage,
    required this.limit,
    required this.remaining,
    required this.period,
    this.resetAt,
    required this.unit,
  });
}
