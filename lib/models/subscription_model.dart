// ==============================================================================
// ZankoAI Premium Subscription Models
// ==============================================================================

typedef SubscriptionModel = UserSubscriptionModel;

/// Subscription Plans supported in ZankoAI
enum SubscriptionPlanType {
  free,
  premiumMonthly, // 1 Month - 5,000 IQD
  premiumQuarterly, // 3 Months - 12,000 IQD
  premiumYearly, // 9 Months - 40,000 IQD
  student,
  university,
  team,
}

extension SubscriptionPlanTypeExt on SubscriptionPlanType {
  String get value {
    switch (this) {
      case SubscriptionPlanType.free:
        return 'FREE';
      case SubscriptionPlanType.premiumMonthly:
        return 'PREMIUM_MONTHLY';
      case SubscriptionPlanType.premiumQuarterly:
        return 'PREMIUM_3_MONTHS';
      case SubscriptionPlanType.premiumYearly:
        return 'PREMIUM_9_MONTHS';
      case SubscriptionPlanType.student:
        return 'STUDENT';
      case SubscriptionPlanType.university:
        return 'UNIVERSITY';
      case SubscriptionPlanType.team:
        return 'TEAM';
    }
  }

  int get priceIqd {
    switch (this) {
      case SubscriptionPlanType.premiumMonthly:
        return 5000;
      case SubscriptionPlanType.premiumQuarterly:
        return 12000;
      case SubscriptionPlanType.premiumYearly:
        return 40000;
      case SubscriptionPlanType.free:
      default:
        return 0;
    }
  }

  int get durationDays {
    switch (this) {
      case SubscriptionPlanType.premiumMonthly:
        return 30;
      case SubscriptionPlanType.premiumQuarterly:
        return 90;
      case SubscriptionPlanType.premiumYearly:
        return 270;
      case SubscriptionPlanType.free:
      default:
        return 0;
    }
  }

  String get labelKu {
    switch (this) {
      case SubscriptionPlanType.free:
        return 'بەخۆڕایی (Free)';
      case SubscriptionPlanType.premiumMonthly:
        return 'پلانی ١ مانگ (5,000 د.ع)';
      case SubscriptionPlanType.premiumQuarterly:
        return 'پلانی ٣ مانگ (12,000 د.ع)';
      case SubscriptionPlanType.premiumYearly:
        return 'پلانی ٩ مانگ (40,000 د.ع)';
      case SubscriptionPlanType.student:
        return 'داشکاندنی قوتابی (Student)';
      case SubscriptionPlanType.university:
        return 'پلانی زانکۆیی (University)';
      case SubscriptionPlanType.team:
        return 'پلانی گروپ (Team)';
    }
  }

  static SubscriptionPlanType fromString(String raw) {
    switch (raw.toUpperCase()) {
      case 'PREMIUM_MONTHLY':
      case 'MONTHLY':
      case 'PREMIUM_1_MONTH':
      case '1_MONTH':
      case 'PREMIUM':
        return SubscriptionPlanType.premiumMonthly;
      case 'PREMIUM_3_MONTHS':
      case '3_MONTHS':
      case 'QUARTERLY':
      case 'PREMIUM_QUARTERLY':
        return SubscriptionPlanType.premiumQuarterly;
      case 'PREMIUM_9_MONTHS':
      case '9_MONTHS':
      case 'PREMIUM_YEARLY':
      case 'YEARLY':
        return SubscriptionPlanType.premiumYearly;
      case 'STUDENT':
        return SubscriptionPlanType.student;
      case 'UNIVERSITY':
        return SubscriptionPlanType.university;
      case 'TEAM':
        return SubscriptionPlanType.team;
      case 'FREE':
      default:
        return SubscriptionPlanType.free;
    }
  }
}

/// Official Subscription Statuses
enum SubscriptionStatusType {
  trialing,
  active,
  pastDue,
  canceled,
  expired,
  incomplete,
}

extension SubscriptionStatusTypeExt on SubscriptionStatusType {
  String get value {
    switch (this) {
      case SubscriptionStatusType.trialing:
        return 'trialing';
      case SubscriptionStatusType.active:
        return 'active';
      case SubscriptionStatusType.pastDue:
        return 'past_due';
      case SubscriptionStatusType.canceled:
        return 'canceled';
      case SubscriptionStatusType.expired:
        return 'expired';
      case SubscriptionStatusType.incomplete:
        return 'incomplete';
    }
  }

  static SubscriptionStatusType fromString(String raw) {
    switch (raw.toLowerCase()) {
      case 'trialing':
        return SubscriptionStatusType.trialing;
      case 'active':
        return SubscriptionStatusType.active;
      case 'past_due':
        return SubscriptionStatusType.pastDue;
      case 'canceled':
        return SubscriptionStatusType.canceled;
      case 'expired':
        return SubscriptionStatusType.expired;
      case 'incomplete':
      default:
        return SubscriptionStatusType.incomplete;
    }
  }
}

/// Authoritative server-verified user subscription model
class UserSubscriptionModel {
  final bool hasActiveSubscription;
  final bool isPremium;
  final SubscriptionPlanType plan;
  final SubscriptionStatusType status;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final bool inGracePeriod;
  final DateTime? gracePeriodEnd;
  final bool autoRenew;
  final String? provider;
  final int daysRemaining;
  final UserUsageSummaryModel? usage;

  const UserSubscriptionModel({
    required this.hasActiveSubscription,
    required this.isPremium,
    required this.plan,
    required this.status,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.inGracePeriod = false,
    this.gracePeriodEnd,
    this.autoRenew = false,
    this.provider,
    this.daysRemaining = 0,
    this.usage,
  });

  /// STRICT RULE: If current_period_end < now, user cannot be treated as Premium
  bool get canAccessPremiumFeatures =>
      isPremium &&
      (status == SubscriptionStatusType.active ||
          status == SubscriptionStatusType.trialing) &&
      (currentPeriodEnd == null || currentPeriodEnd!.isAfter(DateTime.now()));

  bool get isActive =>
      hasActiveSubscription ||
      isPremium ||
      status == SubscriptionStatusType.active ||
      status == SubscriptionStatusType.trialing;

  SubscriptionPlanType get planType => plan;

  bool get isExpired =>
      status == SubscriptionStatusType.expired ||
      (currentPeriodEnd != null && currentPeriodEnd!.isBefore(DateTime.now()));

  factory UserSubscriptionModel.fromJson(Map<String, dynamic> json) {
    final rawPlan = (json['plan_type'] ?? json['plan'] ?? 'FREE').toString();
    final rawStatus = (json['status'] ?? 'expired').toString();

    final rawIsActive = json.containsKey('hasActiveSubscription')
        ? json['hasActiveSubscription'] == true
        : (json['is_active'] == true || rawStatus.toLowerCase() == 'active');

    final rawIsPremium = json.containsKey('isPremium')
        ? json['isPremium'] == true
        : json.containsKey('is_premium')
        ? json['is_premium'] == true
        : (rawPlan.toUpperCase().contains('PREMIUM') && rawIsActive);

    return UserSubscriptionModel(
      hasActiveSubscription: rawIsActive,
      isPremium: rawIsPremium,
      plan: SubscriptionPlanTypeExt.fromString(rawPlan),
      status: SubscriptionStatusTypeExt.fromString(rawStatus),
      currentPeriodStart:
          json['currentPeriodStart'] != null ||
              json['current_period_start'] != null
          ? DateTime.tryParse(
              (json['currentPeriodStart'] ?? json['current_period_start'])
                  .toString(),
            )
          : null,
      currentPeriodEnd:
          json['currentPeriodEnd'] != null || json['current_period_end'] != null
          ? DateTime.tryParse(
              (json['currentPeriodEnd'] ?? json['current_period_end'])
                  .toString(),
            )
          : null,
      cancelAtPeriodEnd:
          json['cancelAtPeriodEnd'] == true ||
          json['cancel_at_period_end'] == true,
      inGracePeriod:
          json['inGracePeriod'] == true || json['in_grace_period'] == true,
      gracePeriodEnd:
          json['gracePeriodEnd'] != null || json['grace_period_end'] != null
          ? DateTime.tryParse(
              (json['gracePeriodEnd'] ?? json['grace_period_end']).toString(),
            )
          : null,
      autoRenew: json['autoRenew'] == true || json['auto_renew'] == true,
      provider: (json['provider'])?.toString(),
      daysRemaining:
          ((json['daysRemaining'] ?? json['days_remaining']) as num?)
              ?.toInt() ??
          0,
      usage: json['usage'] is Map<String, dynamic>
          ? UserUsageSummaryModel.fromJson(
              json['usage'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hasActiveSubscription': hasActiveSubscription,
      'isPremium': isPremium,
      'plan': plan.value,
      'status': status.value,
      'currentPeriodStart': currentPeriodStart?.toIso8601String(),
      'currentPeriodEnd': currentPeriodEnd?.toIso8601String(),
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'inGracePeriod': inGracePeriod,
      'gracePeriodEnd': gracePeriodEnd?.toIso8601String(),
      'autoRenew': autoRenew,
      'provider': provider,
      'daysRemaining': daysRemaining,
      'usage': usage?.toJson(),
    };
  }
}

/// Feature quota & live usage tracking model
class FeatureUsageModel {
  final String feature;
  final String periodType; // 'daily' or 'monthly'
  final int currentUsage;
  final int limit;
  final int remaining;
  final DateTime? resetAt;
  final String? description;

  const FeatureUsageModel({
    required this.feature,
    required this.periodType,
    required this.currentUsage,
    required this.limit,
    required this.remaining,
    this.resetAt,
    this.description,
  });

  bool get isUnlimited => limit <= 0;
  double get progressRatio =>
      isUnlimited || limit == 0 ? 0.0 : (currentUsage / limit).clamp(0.0, 1.0);
  bool get isExhausted => !isUnlimited && remaining <= 0;

  factory FeatureUsageModel.fromJson(
    Map<String, dynamic> json, [
    String? featureKey,
  ]) {
    return FeatureUsageModel(
      feature: (json['feature'] ?? featureKey ?? '').toString(),
      periodType: (json['period_type'] ?? json['periodType'] ?? 'daily')
          .toString(),
      currentUsage:
          ((json['current_usage'] ?? json['currentUsage']) as num?)?.toInt() ??
          0,
      limit: ((json['limit'] ?? json['limit_value']) as num?)?.toInt() ?? 0,
      remaining: ((json['remaining']) as num?)?.toInt() ?? 0,
      resetAt: json['reset_at'] != null || json['resetAt'] != null
          ? DateTime.tryParse((json['reset_at'] ?? json['resetAt']).toString())
          : null,
      description: (json['description'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'feature': feature,
      'period_type': periodType,
      'current_usage': currentUsage,
      'limit': limit,
      'remaining': remaining,
      'reset_at': resetAt?.toIso8601String(),
      'description': description,
    };
  }
}

/// Aggregated user usage summary model
class UserUsageSummaryModel {
  final String plan;
  final bool isVip;
  final Map<String, FeatureUsageModel> features;
  final DateTime? queriedAt;

  const UserUsageSummaryModel({
    required this.plan,
    required this.isVip,
    required this.features,
    this.queriedAt,
  });

  FeatureUsageModel? getFeature(String name) => features[name];

  factory UserUsageSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final parsedMap = <String, FeatureUsageModel>{};

    if (rawFeatures is Map<String, dynamic>) {
      rawFeatures.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          parsedMap[key] = FeatureUsageModel.fromJson(val, key);
        }
      });
    }

    return UserUsageSummaryModel(
      plan: (json['plan'] ?? 'free').toString(),
      isVip: json['is_vip'] == true || json['isVip'] == true,
      features: parsedMap,
      queriedAt: json['queried_at'] != null || json['queriedAt'] != null
          ? DateTime.tryParse(
              (json['queried_at'] ?? json['queriedAt']).toString(),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan': plan,
      'is_vip': isVip,
      'features': features.map((k, v) => MapEntry(k, v.toJson())),
      'queried_at': queriedAt?.toIso8601String(),
    };
  }
}

/// Pluggable payment provider option with visual branding
enum PaymentProviderOption {
  fastpay('fastpay', 'FastPay', 'فاست پەی (FastPay)', 0xFFE00613),
  fib('fib', 'First Iraqi Bank', 'بانکی یەکەمی عێراقی (FIB)', 0xFF104E35),
  zaincash('zaincash', 'ZainCash', 'زەین کاش (ZainCash)', 0xFFE1007A),
  qiCard(
    'qi_card',
    'Qi Card / Mastercard',
    'کی کارت / ماستەرکارت (Qi Card)',
    0xFF005BAC,
  );

  final String id;
  final String englishName;
  final String kurdishName;
  final int primaryColorHex;

  const PaymentProviderOption(
    this.id,
    this.englishName,
    this.kurdishName,
    this.primaryColorHex,
  );

  static PaymentProviderOption fromString(String val) {
    switch (val.toLowerCase()) {
      case 'fastpay':
        return PaymentProviderOption.fastpay;
      case 'fib':
        return PaymentProviderOption.fib;
      case 'zaincash':
        return PaymentProviderOption.zaincash;
      case 'qi_card':
      case 'qicard':
      case 'mastercard':
      case 'visa':
        return PaymentProviderOption.qiCard;
      default:
        return PaymentProviderOption.fastpay;
    }
  }
}

/// Subscription flow state machine for the UI
enum SubscriptionFlowState {
  idle,
  loading,
  paymentPending,
  verifying,
  paymentSuccessful,
  paymentFailed,
}

/// Checkout session response model from POST /api/subscription/checkout
class SubscriptionCheckoutModel {
  final String checkoutId;
  final String? checkoutUrl;
  final String? qrPayload;
  final String provider;
  final SubscriptionPlanType plan;
  final int amount;
  final String currency;
  final DateTime? expiresAt;

  const SubscriptionCheckoutModel({
    required this.checkoutId,
    this.checkoutUrl,
    this.qrPayload,
    required this.provider,
    required this.plan,
    required this.amount,
    required this.currency,
    this.expiresAt,
  });

  factory SubscriptionCheckoutModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionCheckoutModel(
      checkoutId: (json['checkoutId'] ?? '').toString(),
      checkoutUrl: json['checkoutUrl']?.toString(),
      qrPayload: json['qrPayload']?.toString(),
      provider: (json['provider'] ?? 'fib').toString(),
      plan: SubscriptionPlanTypeExt.fromString(
        (json['plan'] ?? 'PREMIUM_MONTHLY').toString(),
      ),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      currency: (json['currency'] ?? 'IQD').toString(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkoutId': checkoutId,
      'checkoutUrl': checkoutUrl,
      'qrPayload': qrPayload,
      'provider': provider,
      'plan': plan.value,
      'amount': amount,
      'currency': currency,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}
