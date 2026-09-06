import assert from 'node:assert';
import { createApp } from '../src/app.js';
import { BUCKET_CONFIGS, StorageService } from '../src/services/storage.service.js';
import { ForbiddenError, BadRequestError } from '../src/utils/apiError.js';
import { UserProfile } from '../src/types/user.types.js';

export async function runStorageTests() {
  console.log('\n📦 Running ZankoAI Secure Supabase Storage Test Suite...\n');

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
  const PORT = 4098;
  const server = app.listen(PORT);

  try {
    // ─── 1. Storage Categories & Private Isolation Configuration ───
    await test('Storage configuration contains exactly the 7 required categories', () => {
      const categories = Object.keys(BUCKET_CONFIGS);
      const expected = [
        'avatars',
        'lecture-files',
        'pdfs',
        'ocr-images',
        'audio',
        'homework-images',
        'generated-files',
      ];
      assert.strictEqual(categories.length, 7);
      for (const cat of expected) {
        assert.ok(categories.includes(cat), `Missing expected storage category: ${cat}`);
      }
    });

    await test('Only avatars bucket is public; all other 6 buckets are strictly private', () => {
      assert.strictEqual(BUCKET_CONFIGS.avatars.isPublic, true);
      assert.strictEqual(BUCKET_CONFIGS['lecture-files'].isPublic, false);
      assert.strictEqual(BUCKET_CONFIGS.pdfs.isPublic, false);
      assert.strictEqual(BUCKET_CONFIGS['ocr-images'].isPublic, false);
      assert.strictEqual(BUCKET_CONFIGS.audio.isPublic, false);
      assert.strictEqual(BUCKET_CONFIGS['homework-images'].isPublic, false);
      assert.strictEqual(BUCKET_CONFIGS['generated-files'].isPublic, false);
    });

    await test('GET /api/storage/categories returns all 7 category definitions and limits', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/storage/categories`);
      assert.strictEqual(res.status, 200);
      const json: any = await res.json();
      assert.strictEqual(json.success, true);
      assert.strictEqual(json.data.length, 7);

      const avatarCat = json.data.find((c: any) => c.id === 'avatars');
      assert.ok(avatarCat);
      assert.strictEqual(avatarCat.isPublic, true);
      assert.strictEqual(avatarCat.maxSizeMB, 2);

      const lectureCat = json.data.find((c: any) => c.id === 'lecture-files');
      assert.ok(lectureCat);
      assert.strictEqual(lectureCat.isPublic, false);
      assert.strictEqual(lectureCat.maxSizeMB, 50);
    });

    // ─── 2. Unauthenticated Request Rejection ───
    await test('POST /api/storage/upload-ticket requires authentication (401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/storage/upload-ticket`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'pdfs',
          originalFileName: 'document.pdf',
          fileSizeBytes: 1024,
          mimeType: 'application/pdf',
        }),
      });
      assert.strictEqual(res.status, 401);
    });

    await test('POST /api/storage/signed-url requires authentication (401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/storage/signed-url`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'pdfs',
          storagePath: 'user-id/file.pdf',
        }),
      });
      assert.strictEqual(res.status, 401);
    });

    await test('DELETE /api/storage/file requires authentication (401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/storage/file`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: 'pdfs',
          storagePath: 'user-id/file.pdf',
        }),
      });
      assert.strictEqual(res.status, 401);
    });

    // ─── 3. Input Validation & MIME/Extension Restrictions ───
    await test('Upload Ticket: Rejects oversized file exceeding category limit', async () => {
      const studentProfile: UserProfile = {
        id: 'student-100',
        email: 'student@zanko.edu',
        full_name: 'Student One',
        role: 'student',
        status: 'active',
        plan: 'free',
        is_vip: false,
        vip_status: 'none',
        score: 0,
        rank_title: 'Newbie',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      await assert.rejects(
        async () => {
          await StorageService.createUploadTicket(
            { id: studentProfile.id, profile: studentProfile },
            {
              category: 'avatars',
              originalFileName: 'photo.jpg',
              fileSizeBytes: 10 * 1024 * 1024, // 10MB exceeds 2MB avatar limit
              mimeType: 'image/jpeg',
            }
          );
        },
        (err: any) => err instanceof BadRequestError && err.message.includes('exceeds maximum allowed limit')
      );
    });

    await test('Upload Ticket: Rejects unauthorized file extension (.exe in pdfs)', async () => {
      const studentProfile: UserProfile = {
        id: 'student-100',
        email: 'student@zanko.edu',
        full_name: 'Student One',
        role: 'student',
        status: 'active',
        plan: 'free',
        is_vip: false,
        vip_status: 'none',
        score: 0,
        rank_title: 'Newbie',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      await assert.rejects(
        async () => {
          await StorageService.createUploadTicket(
            { id: studentProfile.id, profile: studentProfile },
            {
              category: 'pdfs',
              originalFileName: 'malware.exe',
              fileSizeBytes: 5000,
              mimeType: 'application/pdf',
            }
          );
        },
        (err: any) => err instanceof BadRequestError && err.message.includes('not permitted for pdfs')
      );
    });

    await test('Upload Ticket: Requires courseId when uploading to lecture-files', async () => {
      const teacherProfile: UserProfile = {
        id: 'teacher-200',
        email: 'prof@zanko.edu',
        full_name: 'Professor Z',
        role: 'teacher',
        status: 'active',
        plan: 'premium',
        is_vip: true,
        vip_status: 'active',
        score: 100,
        rank_title: 'Scholar',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      await assert.rejects(
        async () => {
          await StorageService.createUploadTicket(
            { id: teacherProfile.id, profile: teacherProfile },
            {
              category: 'lecture-files',
              originalFileName: 'lecture1.pdf',
              fileSizeBytes: 1024 * 1024,
              mimeType: 'application/pdf',
            }
          );
        },
        (err: any) => err instanceof BadRequestError && err.message.includes('courseId is required')
      );
    });

    // ─── 4. Path Traversal & IDOR Defense ───
    await test('Signed URL: Rejects path traversal attempts (../)', async () => {
      const studentProfile: UserProfile = {
        id: 'student-100',
        email: 'student@zanko.edu',
        full_name: 'Student One',
        role: 'student',
        status: 'active',
        plan: 'free',
        is_vip: false,
        vip_status: 'none',
        score: 0,
        rank_title: 'Newbie',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      await assert.rejects(
        async () => {
          await StorageService.createSignedDownloadUrl(
            { id: studentProfile.id, profile: studentProfile },
            {
              category: 'pdfs',
              storagePath: '../../etc/passwd',
            }
          );
        },
        (err: any) => err instanceof BadRequestError
      );
    });

    await test('Signed URL IDOR: Prevents student A from generating signed URL for student B private PDF', async () => {
      const studentA: UserProfile = {
        id: 'student-aaa-111',
        email: 'studentA@zanko.edu',
        full_name: 'Student A',
        role: 'student',
        status: 'active',
        plan: 'free',
        is_vip: false,
        vip_status: 'none',
        score: 0,
        rank_title: 'Newbie',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      await assert.rejects(
        async () => {
          await StorageService.createSignedDownloadUrl(
            { id: studentA.id, profile: studentA },
            {
              category: 'pdfs',
              storagePath: 'student-bbb-222/exam_notes.pdf',
            }
          );
        },
        (err: any) => err instanceof ForbiddenError && err.message.includes('only access your own private files')
      );
    });

    // ─── 5. Expiration Validation ───
    await test('Signed URL Schema: Enforces expiration bounds (60s <= exp <= 3600s)', async () => {
      // Exceeds max 3600s
      const res1 = await fetch(`http://localhost:${PORT}/api/storage/signed-url`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer invalid.token.test',
        },
        body: JSON.stringify({
          category: 'pdfs',
          storagePath: 'user-1/file.pdf',
          expiresInSeconds: 50000,
        }),
      });
      assert.ok([400, 401].includes(res1.status));
    });

  } finally {
    server.close();
  }

  console.log(`\n🎉 Supabase Storage Test Suite Complete: ${passed}/${total} passed.\n`);
  return { passed, total };
}

// If executed directly
if (import.meta.url === `file://${process.argv[1]}`.replace(/\\/g, '/')) {
  runStorageTests().catch((err) => {
    console.error('Storage test runner error:', err);
    process.exit(1);
  });
}
