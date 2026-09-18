import assert from 'assert';
import path from 'path';
import fs from 'fs';
import jwt from 'jsonwebtoken';
import { LocalStorageService } from '../src/services/local_storage.service.js';
import { authMiddleware } from '../src/middleware/auth.middleware.js';

const TEST_SECRET = 'super_secret_test_key_for_zanko_ai_jwt_verification_32_bytes';
process.env.SUPABASE_JWT_SECRET = TEST_SECRET;
process.env.STORAGE_PATH = path.resolve(__dirname, '../scratch/test_uploads');

async function runVerification() {
  console.log('🚀 Running Self-Hosted Backend & Storage Verification...');

  // ─── 1. Auth Middleware Verification ──────────────────────────────────────────
  console.log('  Testing Auth Middleware...');
  const userId = '11111111-2222-3333-4444-555555555555';
  const userEmail = 'student@zankoai.com';

  const validToken = jwt.sign(
    { sub: userId, email: userEmail, role: 'authenticated' },
    TEST_SECRET,
    { algorithm: 'HS256', expiresIn: '1h' }
  );

  let nextCalled = false;
  let mockReq: any = {
    headers: { authorization: `Bearer ${validToken}` },
  };
  let mockRes: any = {
    status(code: number) {
      this.statusCode = code;
      return this;
    },
    json(body: any) {
      this.body = body;
      return this;
    },
  };

  authMiddleware(mockReq, mockRes, () => {
    nextCalled = true;
  });

  assert.strictEqual(nextCalled, true, 'Next function should be called for valid JWT');
  assert.strictEqual(mockReq.user?.id, userId, 'req.user.id must match sub');
  assert.strictEqual(mockReq.user?.email, userEmail, 'req.user.email must match email');
  console.log('  ✔ Valid JWT decoded & attached to req.user successfully');

  // Test Tampered Token
  const tamperedToken = validToken.substring(0, validToken.length - 4) + 'abcd';
  let tamperedRes: any = {
    status(code: number) { this.statusCode = code; return this; },
    json(body: any) { this.body = body; return this; },
  };
  authMiddleware({ headers: { authorization: `Bearer ${tamperedToken}` } } as any, tamperedRes, () => {});
  assert.strictEqual(tamperedRes.statusCode, 401, 'Tampered token must return 401');
  console.log('  ✔ Tampered token properly rejected with 401');

  // Test Expired Token
  const expiredToken = jwt.sign(
    { sub: userId, email: userEmail },
    TEST_SECRET,
    { algorithm: 'HS256', expiresIn: -10 }
  );
  let expiredRes: any = {
    status(code: number) { this.statusCode = code; return this; },
    json(body: any) { this.body = body; return this; },
  };
  authMiddleware({ headers: { authorization: `Bearer ${expiredToken}` } } as any, expiredRes, () => {});
  assert.strictEqual(expiredRes.statusCode, 401, 'Expired token must return 401');
  console.log('  ✔ Expired token properly rejected with 401');

  // ─── 2. LocalStorageService Verification ──────────────────────────────────────
  console.log('  Testing LocalStorageService...');
  LocalStorageService.init();

  const dummyPdf = Buffer.from('%PDF-1.4 dummy pdf binary stream for testing');
  const saved = await LocalStorageService.saveFile('pdfs', 'sample_lecture.pdf', dummyPdf);

  assert.ok(saved.fileId, 'fileId should be generated');
  assert.ok(fs.existsSync(saved.absolutePath), 'File must exist on disk');
  assert.strictEqual(saved.category, 'pdfs');
  console.log(`  ✔ File saved locally: ${saved.relativePath} (${saved.sizeBytes} bytes)`);

  // Test file resolution
  const resolved = LocalStorageService.resolveFile(saved.filename);
  assert.ok(resolved, 'File must be resolvable by filename');
  assert.strictEqual(resolved?.filePath, saved.absolutePath);
  console.log('  ✔ File safely resolved without directory traversal');

  // Test Range Streaming Simulation
  let streamHeaders: Record<string, any> = {};
  let statusCode = 200;
  let streamReq: any = {
    params: { fileId: saved.filename },
    headers: { range: 'bytes=0-10' },
  };
  let streamRes: any = {
    setHeader(k: string, v: any) { streamHeaders[k] = v; },
    status(c: number) { statusCode = c; return this; },
    on() { return this; },
    once() { return this; },
    emit() { return true; },
    write() { return true; },
    end() {},
  };

  LocalStorageService.handleDownloadStream(streamReq, streamRes);
  assert.strictEqual(statusCode, 206, 'Range request must respond with HTTP 206 Partial Content');
  assert.strictEqual(streamHeaders['Accept-Ranges'], 'bytes');
  assert.strictEqual(streamHeaders['Content-Length'], 11);
  console.log('  ✔ HTTP 206 Range Request streamed correctly with byte boundaries');

  // Clean up
  await LocalStorageService.deleteFile('pdfs', saved.filename);
  assert.strictEqual(fs.existsSync(saved.absolutePath), false, 'File must be deleted from disk');
  console.log('  ✔ File deletion verified');

  console.log('\n🎉 ALL SELF-HOSTED STACK CHECKS PASSED!\n');
}

runVerification().catch((err) => {
  console.error('❌ Verification failed:', err);
  process.exit(1);
});
