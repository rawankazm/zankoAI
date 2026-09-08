// ==============================================================================
// ZankoAI Premium Subscription Models
// ==============================================================================

typedef SubscriptionModel = UserSubscriptionModel;

/// Subscription Plans supported in ZankoAI
enum SubscriptionPlanType {
  free,
  premiumMonthly,
  premiumYearly,
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
      case SubscriptionPlanType.premiumYearly:
        return 'PREMIUM_YEARLY';
      case SubscriptionPlanType.student:
        return 'STUDENT';
      case SubscriptionPlanType.university:
        return 'UNIVERSITY';
      case SubscriptionPlanType.team:
        return 'TEAM';
    }
  }

  String get labelKu {
    switch (this) {
      case SubscriptionPlanType.free:
        return 'بەخۆڕایی (Free)';
      case SubscriptionPlanType.premiumMonthly:
        return 'پریمیۆمی مانگانە (Monthly)';
      case SubscriptionPlanType.premiumYearly:
        return 'پریمیۆمی ساڵانە (Yearly)';
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
      case 'PREMIUM':
        return SubscriptionPlanType.premiumMonthly;
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
    final rawIsActive = json['is_active'] == true ||
        json['hasActiveSubscription'] == true ||
        rawStatus.toLowerCase() == 'active';
    final rawIsPremium = json['is_premium'] == true ||
        json['isPremium'] == true ||
        rawPlan.toUpperCase().contains('PREMIUM');

    return UserSubscriptionModel(
      hasActiveSubscription: rawIsActive,
      isPremium: rawIsPremium,
      plan: SubscriptionPlanTypeExt.fromString(rawPlan),
      status: SubscriptionStatusTypeExt.fromString(rawStatus),
      currentPeriodStart: json['currentPeriodStart'] != null || json['current_period_start'] != null
          ? DateTime.tryParse((json['currentPeriodStart'] ?? json['current_period_start']).toString())
          : null,
      currentPeriodEnd: json['currentPeriodEnd'] != null || json['current_period_end'] != null
          ? DateTime.tryParse((json['currentPeriodEnd'] ?? json['current_period_end']).toString())
          : null,
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true || json['cancel_at_period_end'] == true,
      inGracePeriod: json['inGracePeriod'] == true || json['in_grace_period'] == true,
      gracePeriodEnd: json['gracePeriodEnd'] != null || json['grace_period_end'] != null
          ? DateTime.tryParse((json['gracePeriodEnd'] ?? json['grace_period_end']).toString())
          : null,
      autoRenew: json['autoRenew'] == true || json['auto_renew'] == true,
      provider: (json['provider'])?.toString(),
      daysRemaining: ((json['daysRemaining'] ?? json['days_remaining']) as num?)?.toInt() ?? 0,
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
    };
  }
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
