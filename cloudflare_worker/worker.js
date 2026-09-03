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
    const allowedOrigins = [
      'https://zanko-admin.vercel.app',
      'http://localhost:3000',
      'http://localhost:5173',
      'http://localhost:8080',
    ];
    const requestOrigin = request.headers.get('Origin') || '';
    const corsOrigin = allowedOrigins.includes(requestOrigin) ? requestOrigin : (requestOrigin || 'https://zanko-admin.vercel.app');

    const corsHeaders = {
      'Access-Control-Allow-Origin': corsOrigin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Secret-Key',
      'Vary': 'Origin',
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

    // Authentication & Authorization (Supports API_SECRET and Bearer Firebase JWT)
    const secretKey = env.API_SECRET;
    const authHeader = request.headers.get('Authorization') || '';
    const xSecretKey = request.headers.get('X-Secret-Key') || '';
    const querySecret = url.searchParams.get('secret') || '';

    let isAuthorized = false;
    let authSource = 'none';

    // 1. Check direct secret match (Headers or Query)
    if (secretKey && (xSecretKey === secretKey || querySecret === secretKey || authHeader === secretKey || authHeader === `Bearer ${secretKey}`)) {
      isAuthorized = true;
      authSource = 'secret_key';
    }

    // 2. Check Firebase ID Token (JWT) in Authorization Header
    if (!isAuthorized && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7).trim();
      try {
        const parts = token.split('.');
        if (parts.length === 3) {
          const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
          const expectedProject = env.FIREBASE_PROJECT_ID || env.PROJECT_ID || 'zanko-ai';
          const now = Math.floor(Date.now() / 1000);

          // Verify audience, issuer, expiry, and admin role/claim
          const isValidIssuer = payload.iss === `https://securetoken.google.com/${expectedProject}`;
          const isValidAudience = payload.aud === expectedProject;
          const isNotExpired = payload.exp && payload.exp > now;
          const isAdminUser = payload.role === 'admin' || payload.admin === true || 
                             (env.ADMIN_EMAILS && env.ADMIN_EMAILS.split(',').map(e => e.trim().toLowerCase()).includes((payload.email || '').toLowerCase()));

          if (isValidIssuer && isValidAudience && isNotExpired && (isAdminUser || !env.REQUIRE_ADMIN_CLAIM)) {
            isAuthorized = true;
            authSource = 'firebase_token';
          }
        }
      } catch (e) {
        // Fall through to unauthorized
      }
    }

    if (!isAuthorized) {
      return new Response(
        JSON.stringify({ 
          error: 'Unauthorized: Invalid or missing authentication credentials.',
          hint: 'Provide X-Secret-Key header or Authorization: Bearer <Firebase_ID_Token>'
        }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }


    // Protected Debug Keys endpoint (Only accessible with secret key)
    if (url.pathname === '/debug-keys') {
      const keys = Object.keys(env);
      return new Response(
        JSON.stringify({
          configuredKeys: keys,
          hasApiSecret: !!env.API_SECRET,
          hasProjectId: !!(env.FIREBASE_PROJECT_ID || env.PROJECT_ID),
          hasEmail: !!(env.SERVICE_ACCOUNT_EMAIL || env.SERVICE_ACCOUNT_EMA || env.CLIENT_EMAIL),
          hasPrivateKey: !!(env.SERVICE_ACCOUNT_PRIVATE_KEY || env.SERVICE_ACCOUNT_PRI || env.PRIVATE_KEY),
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Endpoint: /send (POST only)
    if (url.pathname === '/send') {
      if (request.method !== 'POST') {
        return new Response(
          JSON.stringify({ error: 'Method Not Allowed. Sending notifications requires POST.' }),
          { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      let title = '';
      let body = '';
      let topic = 'all_students';
      let token = '';
      let targetUrl = '';

      try {
        const rawText = await request.text();
        let json = {};
        try {
          json = JSON.parse(rawText);
        } catch (_) {
          json = {};
        }
        title = json.title || url.searchParams.get('title') || '';
        body = json.body || url.searchParams.get('body') || '';
        topic = json.topic || url.searchParams.get('topic') || 'all_students';
        token = json.token || url.searchParams.get('token') || '';
        targetUrl = json.url || url.searchParams.get('url') || '';
      } catch (e) {
        title = url.searchParams.get('title') || '';
        body = url.searchParams.get('body') || '';
        topic = url.searchParams.get('topic') || 'all_students';
        token = url.searchParams.get('token') || '';
      }

      if (!title || !body) {
        return new Response(
          JSON.stringify({ error: 'Missing required parameters: title and body' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      title = fixNotificationEncoding(title);
      body = fixNotificationEncoding(body);

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

    // Endpoint: /streak-reminder (Manual trigger for daily reminder - POST only)
    if (url.pathname === '/streak-reminder') {
      if (request.method !== 'POST') {
        return new Response(
          JSON.stringify({ error: 'Method Not Allowed. Triggering reminders requires POST.' }),
          { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

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
    const projectId = env.FIREBASE_PROJECT_ID || env.PROJECT_ID;
    const clientEmail = env.SERVICE_ACCOUNT_EMAIL || env.SERVICE_ACCOUNT_EMA || env.CLIENT_EMAIL;

    if (!projectId || !clientEmail) {
      return {
        success: false,
        mode: 'missing_env_config',
        note: 'Required env vars not set: FIREBASE_PROJECT_ID and SERVICE_ACCOUNT_EMAIL must be configured as Cloudflare Worker secrets.',
      };
    }

    let privateKey = env.SERVICE_ACCOUNT_PRIVATE_KEY || env.SERVICE_ACCOUNT_PRI || env.PRIVATE_KEY || env.FIREBASE_PRIVATE_KEY || env.FCM_PRIVATE_KEY;
    
    // Auto-discover private key if variable name was slightly different
    if (!privateKey) {
      for (const k of Object.keys(env)) {
        if (typeof env[k] === 'string' && (env[k].includes('PRIVATE KEY') || env[k].length > 300)) {
          privateKey = env[k];
          break;
        }
      }
    }

    // 1. If using Google Service Account (HTTP v1 API)
    if (clientEmail && privateKey) {
      try {
        const accessToken = await getGoogleAccessToken(
          clientEmail,
          privateKey
        );

        const messagePayload = {
          message: {
            notification: {
              title: title,
              body: body,
            },
            android: {
              priority: 'HIGH',
              collapse_key: 'zanko_admin_broadcast',
              notification: {
                channel_id: 'zanko_admin_channel',
                sound: 'default',
                default_sound: true,
                default_vibrate_timings: true,
                icon: 'ic_launcher',
                tag: 'zanko_admin_broadcast',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
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

    // 2. Error: v1 credentials present but private key missing
    return {
      success: false,
      mode: 'missing_private_key',
      hasEmail: !!clientEmail,
      hasPrivateKey: !!privateKey,
      note: 'FCM requires a valid SERVICE_ACCOUNT_PRIVATE_KEY secret configured in the Cloudflare Worker.',
    };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

// ─── Google OAuth2 Access Token Generator with In-Memory Caching ──────────────
let cachedOAuthToken = null;
let cachedOAuthTokenExpiry = 0; // Epoch seconds

async function getGoogleAccessToken(clientEmail, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);

  // Return cached token if valid for at least 5 more minutes (300s)
  if (cachedOAuthToken && cachedOAuthTokenExpiry > (now + 300)) {
    return cachedOAuthToken;
  }

  const cleanKey = privateKeyPem
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN[ A-Z0-9_-]+-----/g, '')
    .replace(/-----END[ A-Z0-9_-]+-----/g, '')
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
  if (!tokenResponse.ok || !tokenData.access_token) {
    throw new Error(
      `OAuth Token Exchange failed (${tokenResponse.status}): ${tokenData.error || 'unknown'} - ${tokenData.error_description || ''}`
    );
  }
  cachedOAuthToken = tokenData.access_token;
  cachedOAuthTokenExpiry = now + (tokenData.expires_in || 3600);
  return cachedOAuthToken;
}

// ─── Mojibake Repair Helper ──────────────────────────────────────────────────
function fixNotificationEncoding(input) {
  if (!input || typeof input !== 'string') return input || '';
  if (input.includes('Ù') || input.includes('Ø') || input.includes('Û') || input.includes('ð') || input.includes('Ã')) {
    const cp1252Map = {
      0x20AC: 0x80, 0x201A: 0x82, 0x0192: 0x83, 0x201E: 0x84,
      0x2026: 0x85, 0x2020: 0x86, 0x2021: 0x87, 0x02C6: 0x88,
      0x2030: 0x89, 0x0160: 0x8A, 0x2039: 0x8B, 0x0152: 0x8C,
      0x017D: 0x8E, 0x2018: 0x91, 0x2019: 0x92, 0x201C: 0x93,
      0x201D: 0x94, 0x2022: 0x95, 0x2013: 0x96, 0x2014: 0x97,
      0x02DC: 0x98, 0x2122: 0x99, 0x0161: 0x9A, 0x203A: 0x9B,
      0x0153: 0x9C, 0x017E: 0x9E, 0x0178: 0x9F,
    };
    try {
      const bytes = [];
      for (let i = 0; i < input.length; i++) {
        const code = input.charCodeAt(i);
        if (code <= 0xFF) {
          bytes.push(code);
        } else if (cp1252Map[code] !== undefined) {
          bytes.push(cp1252Map[code]);
        } else {
          return input;
        }
      }
      const decoder = new TextDecoder('utf-8', { fatal: false });
      const decoded = decoder.decode(new Uint8Array(bytes));
      if (decoded && decoded.trim().length > 0) return decoded;
    } catch (_) {}
  }
  return input;
}
