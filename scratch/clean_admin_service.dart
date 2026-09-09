import 'dart:io';

void main() {
  final file = File(r'C:\dev\zanko-admin\src\services\adminService.js');
  var text = file.readAsStringSync().replaceAll('\r\n', '\n');

  // 1. Ensure syncVipToSupabase helper is present near top
  if (!text.contains('syncVipToSupabase')) {
    const supabaseHelperHook = "const syncToSupabase = async";
    final syncVipHelper = '''// Authoritative VIP Sync to Supabase PostgreSQL profiles and subscriptions
const syncVipToSupabase = async ({ userId, plan, days, isApproved }) => {
  try {
    if (isApproved) {
      await fetch('https://kjslmvoaanoqrizawllh.supabase.co/rest/v1/rpc/sync_admin_approved_vip', {
        method: 'POST',
        headers: {
          'apikey': 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_',
          'Authorization': 'Bearer sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          p_user_id: userId,
          p_plan: plan || (days >= 250 ? 'PREMIUM_YEARLY' : 'PREMIUM_MONTHLY'),
          p_days: days || 30,
        }),
      });
    } else {
      await fetch('https://kjslmvoaanoqrizawllh.supabase.co/rest/v1/profiles?id=eq.' + userId, {
        method: 'PATCH',
        headers: {
          'apikey': 'sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_',
          'Authorization': 'Bearer sb_publishable_dPcHIdPHfjRsrYEwaiiNlg_PwY8h5U_',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          is_vip: false,
          vip_status: 'rejected',
        }),
      });
    }
  } catch (e) {
    console.warn('Supabase VIP sync notice:', e);
  }
};

''';
    text = text.replaceFirst(supabaseHelperHook, syncVipHelper + supabaseHelperHook);
    print('Added syncVipToSupabase helper');
  }

  // 2. Replace approveVipRequest implementation
  final approveRegex = RegExp(
    r'export const approveVipRequest = async \(requestId, userId, adminEmail\) => \{[\s\S]*?export const rejectVipRequest',
    multiLine: true,
  );

  const newApproveFunction = '''export const approveVipRequest = async (requestId, userId, adminEmail) => {
  let targetUserId = userId
  let reqData = null
  try {
    const reqSnap = await getDoc(doc(db, 'vip_requests', requestId))
    if (reqSnap.exists()) {
      reqData = reqSnap.data()
      if (!targetUserId || targetUserId === 'undefined') {
        targetUserId = reqData.userId
      }
    }
  } catch (e) {
    console.warn('Error fetching vip_requests doc:', e)
  }

  if (!targetUserId) {
    console.error('Cannot approve VIP: missing userId')
    return
  }

  // Calculate plan duration dynamically based on plan, planDays, durationMonths, or price
  let planDays = 30
  if (reqData) {
    if (reqData.planDays) {
      planDays = Number(reqData.planDays)
    } else if (reqData.durationMonths) {
      planDays = Number(reqData.durationMonths) * 30
    } else if (reqData.plan) {
      const p = String(reqData.plan).toLowerCase()
      if (p.includes('9') || p.includes('annual') || p.includes('academic') || p.includes('year')) planDays = 270
      else if (p.includes('3') || p.includes('semester') || p.includes('quarter')) planDays = 90
    } else if (reqData.price) {
      if (reqData.price >= 35000) planDays = 270
      else if (reqData.price >= 10000) planDays = 90
    }
  }

  const batch = writeBatch(db)
  const expiresAt = Timestamp.fromDate(new Date(Date.now() + planDays * 24 * 60 * 60 * 1000))

  batch.set(doc(db, 'vip_requests', requestId), {
    status: 'approved',
    reviewedAt: Timestamp.now(),
    reviewedBy: adminEmail,
    expiresAt,
    approvedDays: planDays,
  }, { merge: true })

  batch.set(doc(db, 'users', targetUserId), {
    isVip: true,
    vipStatus: 'approved',
    vipExpiresAt: expiresAt,
    vipDurationDays: planDays,
    plan: reqData?.plan || (planDays >= 250 ? 'PREMIUM_YEARLY' : 'PREMIUM_MONTHLY'),
  }, { merge: true })

  // Commit Firestore batch (strictly only vip_requests + users, zero notification collection writes)
  await batch.commit()

  const title = '🎉 پیرۆزە! بەشداربوونی VIPی تۆ پەسەندکرا'
  const message = 'پیرۆزە! هەژمارەکەت لە ZankoAI بە سەرکەوتوویی بوو بە VIP 👑. ئێستا دەتوانیت سوود لە سەرجەم تایبەتمەندییە بێسنوورەکان و دەنگە زیرەکەکان و کورتکراوەکان وەربگریت.'
  const appUserId = reqData?.appUserId || reqData?.userId || targetUserId

  // 1. Authoritative VIP Sync to Supabase PostgreSQL
  await syncVipToSupabase({
    userId: appUserId || targetUserId,
    plan: reqData?.plan,
    days: planDays,
    isApproved: true,
  })

  // 2. Dual sync to Supabase Realtime notifications
  await syncToSupabase({
    title,
    body: message,
    type: 'vip_approved',
    userId: appUserId || targetUserId,
    adminEmail,
  })

  // 3. Trigger Real FCM Push via Cloudflare Worker (Single official notification)
  try {
    const userSnap = await getDoc(doc(db, 'users', targetUserId))
    let token = reqData?.fcmToken || (userSnap.exists() ? userSnap.data()?.fcmToken : null)

    if (token) {
      await triggerFcmPush({
        title,
        body: message,
        token,
        topic: null,
      })
    } else {
      await triggerFcmPush({
        title,
        body: message,
        token: null,
        topic: `user_\${appUserId || targetUserId}`,
      })
    }
  } catch (e) {
    console.warn('FCM Push warning:', e)
  }
}

export const rejectVipRequest''';

  text = text.replaceFirst(approveRegex, newApproveFunction);
  print('Replaced approveVipRequest');

  // 3. Replace rejectVipRequest implementation
  final rejectRegex = RegExp(
    r'export const rejectVipRequest = async \(requestId, userId, adminEmail, reason = \x27\x27\) => \{[\s\S]*?export const subscribeUsers',
    multiLine: true,
  );

  const newRejectFunction = '''export const rejectVipRequest = async (requestId, userId, adminEmail, reason = '') => {
  let targetUserId = userId
  let reqData = null
  try {
    const reqSnap = await getDoc(doc(db, 'vip_requests', requestId))
    if (reqSnap.exists()) {
      reqData = reqSnap.data()
      if (!targetUserId || targetUserId === 'undefined') {
        targetUserId = reqData.userId
      }
    }
  } catch (e) {
    console.warn('Error fetching vip_requests doc:', e)
  }

  if (!targetUserId) {
    console.error('Cannot reject VIP: missing userId')
    return
  }

  const batch = writeBatch(db)
  batch.set(doc(db, 'vip_requests', requestId), {
    status: 'rejected',
    reviewedAt: Timestamp.now(),
    reviewedBy: adminEmail,
    rejectionReason: reason,
  }, { merge: true })

  batch.set(doc(db, 'users', targetUserId), {
    isVip: false,
    vipStatus: 'rejected',
  }, { merge: true })

  // Commit Firestore batch (strictly only vip_requests + users, zero notification collection writes)
  await batch.commit()

  const title = '⚠️ ئاگاداری سەبارەت بە داواکاری VIP'
  const message = reason && reason.trim().length > 0
    ? `داواکارییەکەت بۆ VIP پەسەند نەکرا. هۆکارەکەی لەلایەن ئەدمینەوە: "\${reason.trim()}"`
    : 'داواکارییەکەت بۆ VIP پەسەند نەکرا. تکایە لە دروستی ژمارەی پسوولە و وێنەی وەسڵەکە دڵنیابەرەوە و دووبارە داوا بنێرەوە.'

  const appUserId = reqData?.appUserId || reqData?.userId || targetUserId

  // 1. Authoritative VIP Sync to Supabase PostgreSQL
  await syncVipToSupabase({
    userId: appUserId || targetUserId,
    isApproved: false,
  })

  // 2. Dual sync to Supabase Realtime notifications
  await syncToSupabase({
    title,
    body: message,
    type: 'vip_rejected',
    userId: appUserId || targetUserId,
    adminEmail,
  })

  // 3. Trigger Real FCM Push via Cloudflare Worker (Single official notification)
  try {
    const userSnap = await getDoc(doc(db, 'users', targetUserId))
    let token = reqData?.fcmToken || (userSnap.exists() ? userSnap.data()?.fcmToken : null)

    if (token) {
      await triggerFcmPush({
        title,
        body: message,
        token,
        topic: null,
      })
    } else {
      await triggerFcmPush({
        title,
        body: message,
        token: null,
        topic: `user_\${appUserId || targetUserId}`,
      })
    }
  } catch (e) {
    console.warn('FCM Push warning:', e)
  }
}

// ─── Users ───────────────────────────────────────────────────────────────────

export const subscribeUsers''';

  text = text.replaceFirst(rejectRegex, newRejectFunction);
  print('Replaced rejectVipRequest');

  // 4. Replace setUserVipStatus implementation
  final setUserVipRegex = RegExp(
    r'export const setUserVipStatus = async \(userId, isVip, days = 30, adminEmail = \x27admin\x27\) => \{[\s\S]*?export const deleteUserData',
    multiLine: true,
  );

  const newSetUserVipFunction = '''export const setUserVipStatus = async (userId, isVip, days = 30, adminEmail = 'admin') => {
  const expiresAt = isVip ? Timestamp.fromDate(new Date(Date.now() + days * 24 * 60 * 60 * 1000)) : null

  await setDoc(doc(db, 'users', userId), {
    isVip: !!isVip,
    vipStatus: isVip ? 'active' : 'none',
    vipExpiresAt: expiresAt,
    updatedAt: Timestamp.now(),
  }, { merge: true })

  // 1. Authoritative VIP Sync to Supabase PostgreSQL
  await syncVipToSupabase({
    userId,
    plan: days >= 250 ? 'PREMIUM_YEARLY' : 'PREMIUM_MONTHLY',
    days,
    isApproved: !!isVip,
  })

  if (isVip) {
    const title = '🎉 پیرۆزە! بەشداربوونی VIPی تۆ پەسەندکرا'
    const message = `پیرۆزە! هەژمارەکەت لە ZankoAI بۆ ماوەی \${days} ڕۆژ بوو بە VIP 👑. ئێستا دەتوانیت سوود لە سەرجەم تایبەتمەندییە بێسنوورەکان وەربگریت.`

    // 2. Dual sync to Supabase Realtime notifications
    await syncToSupabase({
      title,
      body: message,
      type: 'vip_approved',
      userId,
      adminEmail,
    })

    // 3. Trigger Real FCM Push via Cloudflare Worker
    await triggerFcmPush({
      title,
      body: message,
      topic: `user_\${userId}`,
      token: null,
    })
  }
}

export const deleteUserData''';

  text = text.replaceFirst(setUserVipRegex, newSetUserVipFunction);
  print('Replaced setUserVipStatus');

  file.writeAsStringSync(text);
  print('Successfully saved C:\\dev\\zanko-admin\\src\\services\\adminService.js');
}
