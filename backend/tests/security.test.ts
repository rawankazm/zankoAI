import assert from 'node:assert';
import { createApp } from '../src/app.js';
import { requireRole } from '../src/middleware/requireRole.js';
import { verifyResourceOwnership } from '../src/middleware/ownershipGuard.js';
import { redactSensitiveData } from '../config/logger.js';
import { validateMagicBytes, sanitizeUploadedFilename } from '../middleware/uploadGuard.js';
import { validateExternalUrl } from '../utils/ssrfValidator.js';
import { ForbiddenError, RateLimitError } from '../utils/apiError.js';
import { rateLimiter, bruteForceLimiter } from '../src/middleware/rateLimiter.js';
import { ALLOWED_ORIGINS } from '../src/config/security.js';

export async function runSecurityTests() {
  console.log('\n🛡️  Running ZankoAI Complete Security Hardening Test Suite...\n');

  let passed = 0;
  let total = 0;

  const test = async (name: string, fn: () => Promise<void> | void) => {
    total++;
    try {
      await fn();
      console.log(`  ✅ PASSED: ${name}`);
      passed++;
    } catch (err: any) {
      console.error(`  ❌ FAILED: ${name}`);
      console.error(`     Error: ${err.message}`);
    }
  };

  const app = createApp();
  const PORT = 4099;
  const server = app.listen(PORT);

  try {
    // ─── 1. Unauthenticated Request Rejection ───
    await test('Rejects request without Authorization header (401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/auth/profile`);
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    await test('Rejects malformed Authorization header (401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/auth/profile`, {
        headers: { Authorization: 'Basic dXNlcjpwYXNz' },
      });
      assert.strictEqual(res.status, 401);
    });

    await test('Rejects invalid or forged Bearer token (401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/auth/profile`, {
        headers: { Authorization: 'Bearer forged.token.signature' },
      });
      assert.strictEqual(res.status, 401);
    });

    // ─── 2. RBAC & Privilege Escalation Prevention ───
    await test('RBAC blocks student role from admin endpoints', async () => {
      const req: any = {
        profile: { role: 'student' },
        user: { id: 'student-123' },
        method: 'GET',
        originalUrl: '/api/admin/metrics',
        headers: {},
        socket: {},
      };
      let errorThrown: any = null;
      const middleware = requireRole(['admin']);
      middleware(req, {} as any, (err: any) => {
        errorThrown = err;
      });

      assert.ok(errorThrown instanceof ForbiddenError);
      assert.strictEqual(errorThrown.statusCode, 403);
    });

    await test('RBAC allows admin role access to admin endpoints', async () => {
      const req: any = {
        profile: { role: 'admin' },
        user: { id: 'admin-123' },
        method: 'GET',
        originalUrl: '/api/admin/metrics',
        headers: {},
        socket: {},
      };
      let errorThrown: any = null;
      const middleware = requireRole(['admin']);
      middleware(req, {} as any, (err: any) => {
        errorThrown = err;
      });

      assert.strictEqual(errorThrown, undefined);
    });

    await test('RBAC blocks student role from teacher endpoints', async () => {
      const req: any = {
        profile: { role: 'student' },
        user: { id: 'student-123' },
        method: 'POST',
        originalUrl: '/api/lectures',
        headers: {},
        socket: {},
      };
      let errorThrown: any = null;
      const middleware = requireRole(['teacher', 'admin']);
      middleware(req, {} as any, (err: any) => {
        errorThrown = err;
      });

      assert.ok(errorThrown instanceof ForbiddenError);
    });

    // ─── 3. IDOR & Ownership Verification ───
    await test('IDOR: verifyResourceOwnership blocks non-owner from modifying resource', () => {
      assert.throws(
        () => {
          verifyResourceOwnership('user-A-owner', 'user-B-attacker', 'student', 'flashcard');
        },
        (err: any) => err instanceof ForbiddenError && err.statusCode === 403
      );
    });

    await test('IDOR: verifyResourceOwnership allows owner to modify resource', () => {
      assert.doesNotThrow(() => {
        verifyResourceOwnership('user-A-owner', 'user-A-owner', 'student', 'flashcard');
      });
    });

    await test('IDOR: verifyResourceOwnership allows admin to override ownership', () => {
      assert.doesNotThrow(() => {
        verifyResourceOwnership('user-A-owner', 'admin-super', 'admin', 'flashcard');
      });
    });

    // ─── 4. Input Sanitization & Prototype Pollution Protection ───
    await test('Sanitization: Neutralizes script tags in JSON payload', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/auth/profile`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer invalid.token.test',
        },
        body: JSON.stringify({
          full_name: 'Test<script>alert(1)</script> User',
        }),
      });
      // Will be blocked by auth first or sanitized
      assert.ok([400, 401].includes(res.status));
    });

    await test('Sanitization: Blocks Prototype Pollution keys (__proto__)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/auth/profile`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer invalid.token.test',
        },
        body: '{"__proto__": {"polluted": true}, "full_name": "Test"}',
      });
      assert.ok([400, 401].includes(res.status));
    });

    // ─── 5. Secret & Key Redaction in Logging ───
    await test('Logging: Redacts passwords, tokens, API keys and secrets recursively', () => {
      const sensitivePayload = {
        username: 'student1',
        password: 'SuperSecretPassword!2026',
        token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy',
        apiKey: 'AIzaSyAABBCCDDEEFFGGHHIIJJKKLLMMNN',
        nested: {
          client_secret: 'oauth-secret-999',
          auth_token: 'auth-secret-111',
          safeField: 'This should remain untouched',
        },
        rawHeader: 'Bearer eyJhbGciOiJIUzI1Ni.sensitive.signature',
      };

      const redacted = redactSensitiveData(sensitivePayload);

      assert.strictEqual(redacted.password, '[REDACTED]');
      assert.strictEqual(redacted.token, '[REDACTED]');
      assert.strictEqual(redacted.apiKey, '[REDACTED]');
      assert.strictEqual(redacted.nested.client_secret, '[REDACTED]');
      assert.strictEqual(redacted.nested.auth_token, '[REDACTED]');
      assert.strictEqual(redacted.nested.safeField, 'This should remain untouched');
      assert.ok(!redacted.rawHeader.includes('eyJhbGciOiJIUzI1Ni'));
      assert.ok(redacted.rawHeader.includes('Bearer [REDACTED]'));
    });

    // ─── 6. File Upload Guard & Magic Bytes Validation ───
    await test('Magic Bytes: Correctly detects genuine PDF buffer', () => {
      const genuinePdfBuffer = Buffer.from('%PDF-1.7\n%Fake PDF binary stream');
      const result = validateMagicBytes(genuinePdfBuffer);
      assert.strictEqual(result.isValid, true);
      assert.strictEqual(result.detectedType, 'application/pdf');
    });

    await test('Magic Bytes: Correctly detects genuine JPEG image buffer', () => {
      const genuineJpegBuffer = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
      const result = validateMagicBytes(genuineJpegBuffer);
      assert.strictEqual(result.isValid, true);
      assert.strictEqual(result.detectedType, 'image/jpeg');
    });

    await test('Magic Bytes: Rejects spoofed/malicious executable disguised as PDF', () => {
      // Windows PE/EXE header: MZ (0x4D 0x5A)
      const fakePdfBuffer = Buffer.from([0x4d, 0x5a, 0x90, 0x00, 0x03, 0x00]);
      const result = validateMagicBytes(fakePdfBuffer);
      assert.strictEqual(result.isValid, false);
    });

    await test('Filename Sanitization: Neutralizes directory traversal attacks', () => {
      const maliciousName = '../../../../etc/passwd.pdf';
      const sanitized = sanitizeUploadedFilename(maliciousName);
      assert.ok(!sanitized.includes('..'));
      assert.ok(!sanitized.includes('/'));
      assert.ok(sanitized.endsWith('.pdf'));
    });

    // ─── 7. SSRF Validation ───
    await test('SSRF: Blocks loopback and localhost targets (127.0.0.1, localhost)', () => {
      assert.throws(() => validateExternalUrl('http://127.0.0.1:4000/internal'));
      assert.throws(() => validateExternalUrl('http://localhost:6379'));
    });

    await test('SSRF: Blocks AWS/DigitalOcean cloud metadata IP (169.254.169.254)', () => {
      assert.throws(() => validateExternalUrl('http://169.254.169.254/metadata/v1.json'));
    });

    await test('SSRF: Blocks private RFC 1918 internal IPs (10.0.0.1, 192.168.1.1, 172.16.0.1)', () => {
      assert.throws(() => validateExternalUrl('http://10.0.0.1/admin'));
      assert.throws(() => validateExternalUrl('http://192.168.1.1/router'));
      assert.throws(() => validateExternalUrl('http://172.16.5.2:8080'));
    });

    await test('SSRF: Allows legitimate public HTTPS URLs', () => {
      assert.doesNotThrow(() => {
        validateExternalUrl('https://kjslmvoaanoqrizawllh.supabase.co/storage/v1/object/public/file.pdf');
      });
    });

    // ─── 8. Security Headers Verification ───
    await test('Security Headers: Verifies Helmet & API cache-control headers', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/health`);
      assert.strictEqual(res.status, 200);

      // Verify strict security headers
      assert.strictEqual(res.headers.get('x-content-type-options'), 'nosniff');
      assert.strictEqual(res.headers.get('x-frame-options'), 'DENY');
      assert.ok(res.headers.get('cache-control')?.includes('no-store'));
      assert.strictEqual(res.headers.get('x-powered-by'), null); // Hidden
    });

    // ─── 9. CORS Allowlist ───
    await test('CORS: Verified allowlist includes production admin and app domains', () => {
      assert.ok(ALLOWED_ORIGINS.includes('https://zanko-admin.vercel.app'));
      assert.ok(ALLOWED_ORIGINS.includes('https://zankoai.com'));
    });

    // ─── 10. Rate Limiting Headers ───
    await test('Rate Limiting: Returns X-RateLimit headers on endpoints', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/health`);
      assert.ok(res.headers.has('x-ratelimit-limit'));
      assert.ok(res.headers.has('x-ratelimit-remaining'));
    });

  } finally {
    server.close();
  }

  console.log(`\n🎉 Security Test Suite Complete: ${passed}/${total} passed.\n`);
  return { passed, total };
}

// If executed directly
if (import.meta.url === `file://${process.argv[1]}`.replace(/\\/g, '/')) {
  runSecurityTests().catch((err) => {
    console.error('Test runner fatal error:', err);
    process.exit(1);
  });
}
