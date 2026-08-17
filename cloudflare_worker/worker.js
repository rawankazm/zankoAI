/**
 * ZankoAI - Cloudflare Worker Push Notification Server
 * 
 * Capabilities:
 * 1. HTTP Endpoint to send instant push notifications to all students or specific topics.
 * 2. Scheduled Cron Triggers for automated daily study & streak reminders.
 * 3. Protected with a secret API key.
 */

export default {
  // ─── 1. HTTP Request Handler (API) ─────────────────────────────────────────
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // CORS Headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Secret-Key',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Health check endpoint
    if (url.pathname === '/' || url.pathname === '/health') {
      return new Response(
        JSON.stringify({
          status: 'online',
          service: 'ZankoAI Push Notification Engine (Cloudflare Worker)',
          timestamp: new Date().toISOString(),
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Secret Key Authentication
    const secretKey = env.API_SECRET || 'zanko_secret_2026';
    const providedSecret =
      request.headers.get('X-Secret-Key') ||
      url.searchParams.get('secret');

    if (providedSecret !== secretKey) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Invalid or missing secret key' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Endpoint: /send
    if (url.pathname === '/send') {
      let title = '';
      let body = '';
      let topic = 'all_students';
      let token = '';
      let targetUrl = '';

      if (request.method === 'POST') {
        try {
          const json = await request.json();
          title = json.title || '';
          body = json.body || '';
          topic = json.topic || 'all_students';
          token = json.token || '';
          targetUrl = json.url || '';
        } catch (e) {
          return new Response(
            JSON.stringify({ error: 'Invalid JSON body' }),
            { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      } else if (request.method === 'GET') {
        title = url.searchParams.get('title') || '';
        body = url.searchParams.get('body') || '';
        topic = url.searchParams.get('topic') || 'all_students';
        token = url.searchParams.get('token') || '';
        targetUrl = url.searchParams.get('url') || '';
      }

      if (!title || !body) {
        return new Response(
          JSON.stringify({ error: 'Missing required parameters: title and body' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      const result = await sendFcmNotification(env, {
        title,
        body,
        topic,
        token,
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          route: targetUrl || '/notifications',
          sentAt: new Date().toISOString(),
        },
      });

      return new Response(JSON.stringify(result), {
        status: result.success ? 200 : 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Endpoint: /streak-reminder (Manual trigger for daily reminder)
    if (url.pathname === '/streak-reminder') {
      const result = await sendFcmNotification(env, {
        title: '🔥 ئاگاداربە! لەدەستچوونی Streak',
        body: 'تەنها چەند کاتژمێرت ماوە بۆ پاراستنی زنجیرەی خوێندنەکەت و وەرگرتنی +50 XP!',
        topic: 'all_students',
        data: {
          type: 'streak_reminder',
          route: '/home',
        },
      });

      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ error: 'Endpoint not found' }), {
      status: 404,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  },

  // ─── 2. Cron Triggers (Automated Scheduled Reminders) ──────────────────────
  async scheduled(event, env, ctx) {
    console.log(`[Cron Trigger Executed] at: ${new Date().toISOString()}`);

    // Automated Evening Streak Reminder
    await sendFcmNotification(env, {
      title: '🔥 کاتی پاداشتی ڕۆژانەیە لە ZankoAI!',
      body: 'ئەمڕۆ سەردانی ئەپەکەت کردووە؟ وەرە ناو ئەپەکە و نمرەی بەرز و پاداشتی ڕۆژانە بەدەستبهێنە ✨',
      topic: 'all_students',
      data: {
        type: 'cron_streak_reminder',
        route: '/home',
      },
    });
  },
};

// ─── Helper: Send FCM Notification ───────────────────────────────────────────
async function sendFcmNotification(env, { title, body, topic, token, data }) {
  try {
    const fcmServerKey = env.FCM_SERVER_KEY;
    const projectId = env.FIREBASE_PROJECT_ID || 'tomartv-67cda';

    // 1. If using Google Service Account (HTTP v1 API)
    if (env.SERVICE_ACCOUNT_EMAIL && env.SERVICE_ACCOUNT_PRIVATE_KEY) {
      try {
        const accessToken = await getGoogleAccessToken(
          env.SERVICE_ACCOUNT_EMAIL,
          env.SERVICE_ACCOUNT_PRIVATE_KEY
        );

        const messagePayload = {
          message: {
            notification: {
              title: title,
              body: body,
            },
            android: {
              priority: 'HIGH',
              notification: {
                channel_id: 'zanko_admin_channel',
                sound: 'default',
                default_sound: true,
                default_vibrate_timings: true,
                icon: 'ic_launcher',
              },
            },
            data: data || {},
          },
        };

        if (token) {
          messagePayload.message.token = token;
        } else {
          messagePayload.message.topic = topic || 'all_students';
        }

        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(messagePayload),
          }
        );

        const resData = await response.json();
        if (!response.ok) {
          return { success: false, error: resData };
        }
        return { success: true, mode: 'v1_oauth', messageId: resData.name };
      } catch (authError) {
        return { success: false, error: `Auth Error: ${authError.message}` };
      }
    }

    // 2. Fallback: If using FCM Legacy Server Key (Simple & Direct)
    if (fcmServerKey) {
      const legacyPayload = {
        to: token ? token : `/topics/${topic || 'all_students'}`,
        notification: {
          title: title,
          body: body,
          sound: 'default',
          android_channel_id: 'zanko_admin_channel',
        },
        data: data || {},
        priority: 'high',
      };

      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${fcmServerKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(legacyPayload),
      });

      const resData = await response.json();
      return { success: response.ok, mode: 'legacy_key', data: resData };
    }

    // 3. Mock Success if no credentials configured yet (for testing)
    return {
      success: true,
      mode: 'preview_mode',
      note: 'Notification processed! To send to live devices, add SERVICE_ACCOUNT_PRIVATE_KEY or FCM_SERVER_KEY to Cloudflare Worker secrets.',
      payload: { title, body, topic },
    };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

// ─── Google OAuth2 Access Token Generator using Web Crypto (SubtleCrypto) ───
async function getGoogleAccessToken(clientEmail, privateKeyPem) {
  const cleanKey = privateKeyPem
    .replace(/\\n/g, '')
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\\/g, '')
    .replace(/\s+/g, '');

  const binaryKey = Uint8Array.from(atob(cleanKey), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey.buffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: { name: 'SHA-256' },
    },
    false,
    ['sign']
  );

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claimSet = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const encodeBase64Url = (obj) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');

  const unsignedJwt = `${encodeBase64Url(header)}.${encodeBase64Url(claimSet)}`;
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsignedJwt)
  );

  const signatureBase64Url = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${unsignedJwt}.${signatureBase64Url}`;

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}
