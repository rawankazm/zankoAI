import assert from 'node:assert';
import { createApp } from '../src/app.js';
import { checkResourceOwner } from '../src/middleware/membershipGuard.js';
import { QueryHelper } from '../src/utils/queryBuilder.js';

// Setup test environment
process.env.NODE_ENV = 'test';
process.env.PORT = '4002';

console.log('🧪 Starting ZankoAI Secure Data Access Integration Test Suite...\n');

let passedTests = 0;
let totalTests = 0;

const runTest = async (name: string, fn: () => Promise<void> | void) => {
  totalTests++;
  try {
    await fn();
    console.log(`  ✅ PASSED: ${name}`);
    passedTests++;
  } catch (error: any) {
    console.error(`  ❌ FAILED: ${name}`);
    console.error(`     Error: ${error.message}`);
  }
};

const main = async () => {
  const app = createApp();
  const server = app.listen(4002);

  try {
    // ─── 1. Unauthorized User Tests ───
    await runTest('Unauthorized request to protected endpoints returns HTTP 401', async () => {
      const endpoints = [
        'http://localhost:4002/api/calendar',
        'http://localhost:4002/api/notifications',
        'http://localhost:4002/api/teacher/courses',
        'http://localhost:4002/api/admin/users',
      ];

      for (const url of endpoints) {
        const res = await fetch(url);
        assert.strictEqual(res.status, 401, `Expected 401 for ${url}`);
        const json: any = await res.json();
        assert.strictEqual(json.success, false);
        assert.strictEqual(json.error.code, 'UNAUTHORIZED');
      }
    });

    await runTest('Public academic directories (Universities) are accessible without token', async () => {
      const res = await fetch('http://localhost:4002/api/universities');
      assert.strictEqual(res.status, 200);
      const json: any = await res.json();
      assert.strictEqual(json.success, true);
      assert.ok(Array.isArray(json.data.items));
    });

    await runTest('Student attempting admin operations is rejected with HTTP 403 Forbidden', async () => {
      // Mock request handler testing requireRole directly
      const { requireRole } = await import('../src/middleware/requireRole.js');
      const adminOnlyMiddleware = requireRole(['admin']);

      const studentReq: any = {
        profile: { id: 'student-id-1', role: 'student' },
      };

      let errorEncountered: any = null;
      adminOnlyMiddleware(studentReq, {} as any, (err?: any) => {
        errorEncountered = err;
      });

      assert.ok(errorEncountered, 'Expected student to be blocked from admin route');
      assert.strictEqual(errorEncountered.statusCode, 403);
      assert.strictEqual(errorEncountered.code, 'FORBIDDEN');
    });

    // ─── 2. Non-Member Course Access Tests ───
    await runTest('Non-member student attempting to access course content is blocked with 403', async () => {
      const { enforceCourseMember } = await import('../src/middleware/membershipGuard.js');
      const membershipMiddleware = enforceCourseMember('courseId');

      // Request for a course the student is not enrolled in
      const nonMemberReq: any = {
        user: { id: '00000000-0000-0000-0000-000000000099' },
        profile: { id: '00000000-0000-0000-0000-000000000099', role: 'student' },
        params: { courseId: '10000000-0000-0000-0000-000000000001' },
      };

      let errorEncountered: any = null;
      await membershipMiddleware(nonMemberReq, {} as any, (err?: any) => {
        errorEncountered = err;
      });

      assert.ok(errorEncountered, 'Expected non-member to be rejected');
      assert.ok(errorEncountered.statusCode === 403 || errorEncountered.statusCode === 404);
    });

    // ─── 3. Wrong Owner Security Tests ───
    await runTest('Wrong owner attempting to modify or delete another user resource is blocked with 403', () => {
      const ownerId = '00000000-0000-0000-0000-000000000001';
      const attackerId = '00000000-0000-0000-0000-000000000002';

      // Case A: Attacker tries to modify owner resource
      assert.throws(
        () => {
          checkResourceOwner(ownerId, attackerId, 'student');
        },
        (err: any) => {
          assert.strictEqual(err.statusCode, 403);
          assert.strictEqual(err.code, 'FORBIDDEN');
          return true;
        }
      );

      // Case B: Actual owner can modify their resource
      assert.doesNotThrow(() => {
        checkResourceOwner(ownerId, ownerId, 'student');
      });

      // Case C: Admin can manage any resource
      assert.doesNotThrow(() => {
        checkResourceOwner(ownerId, attackerId, 'admin');
      });
    });

    // ─── 4. Input Validation (Zod DTO) Tests ───
    await runTest('Invalid input payloads are rejected with HTTP 400 and validation details', async () => {
      const { validateRequest } = await import('../src/middleware/validateRequest.js');
      const { createUniversitySchema } = await import('../src/validators/academic.validators.js');

      const validator = validateRequest({ body: createUniversitySchema });

      // Malformed payload (missing name and city)
      const malformedReq: any = {
        body: {
          website_url: 'not-a-valid-url',
        },
      };

      let validationError: any = null;
      await validator(malformedReq, {} as any, (err?: any) => {
        validationError = err;
      });

      assert.ok(validationError, 'Expected validation error for malformed input');
      assert.strictEqual(validationError.statusCode, 400);
      assert.strictEqual(validationError.code, 'BAD_REQUEST');
      assert.ok(Array.isArray(validationError.details));
      assert.ok(validationError.details.length >= 2, 'Expected multiple field errors (name, city)');
    });

    // ─── 5. Pagination, Sorting Allowlist & Search Tests ───
    await runTest('QueryHelper enforces allowlisted sort fields and safe pagination limits', () => {
      // Case A: Unallowlisted sort field should be rejected and fall back safely
      const maliciousReq: any = {
        query: {
          page: '2',
          limit: '5',
          sort: 'password_hash;DROP TABLE users:desc', // SQL injection probe
        },
      };

      const parsed = QueryHelper.parse(maliciousReq, {
        allowedSortFields: ['name', 'created_at'],
        defaultSortField: 'created_at',
      });

      assert.strictEqual(parsed.page, 2);
      assert.strictEqual(parsed.limit, 5);
      assert.strictEqual(parsed.offset, 5);
      assert.strictEqual(parsed.sortField, 'created_at', 'Unallowlisted field must fall back to safe default');
      assert.strictEqual(parsed.sortAsc, false);

      // Case B: Allowed sort field
      const validReq: any = {
        query: {
          sort: 'name:asc',
        },
      };

      const parsedValid = QueryHelper.parse(validReq, {
        allowedSortFields: ['name', 'created_at'],
      });
      assert.strictEqual(parsedValid.sortField, 'name');
      assert.strictEqual(parsedValid.sortAsc, true);

      // Case C: Exceeding maxLimit is clamped
      const highLimitReq: any = {
        query: {
          limit: '10000',
        },
      };
      const parsedHigh = QueryHelper.parse(highLimitReq, {
        allowedSortFields: ['name'],
        maxLimit: 100,
      });
      assert.strictEqual(parsedHigh.limit, 100, 'Limit should be clamped to maxLimit');
    });

    await runTest('QueryHelper formats consistent pagination envelopes', () => {
      const items = [{ id: 1 }, { id: 2 }];
      const total = 45;
      const formatted = QueryHelper.formatResult(items, total, 2, 10);

      assert.deepStrictEqual(formatted.items, items);
      assert.strictEqual(formatted.total, 45);
      assert.strictEqual(formatted.page, 2);
      assert.strictEqual(formatted.limit, 10);
      assert.strictEqual(formatted.totalPages, 5);
    });

    // ─── 6. Teacher Role Operations ───
    await runTest('Teacher can create course and assignments', async () => {
      const { requireRole } = await import('../src/middleware/requireRole.js');
      const teacherMiddleware = requireRole(['teacher', 'admin']);

      const teacherReq: any = {
        profile: { id: 'teacher-123', role: 'teacher' },
      };

      let error: any = null;
      teacherMiddleware(teacherReq, {} as any, (err?: any) => {
        error = err;
      });

      assert.strictEqual(error, undefined, 'Teacher should be allowed through teacher middleware');
    });

    // ─── 7. Users Domain & Ownership Protection ───
    await runTest('Unauthorized request to /api/users returns HTTP 401', async () => {
      const res = await fetch('http://localhost:4002/api/users');
      assert.strictEqual(res.status, 401);
    });

    await runTest('User cannot update another user profile', async () => {
      const { UserController } = await import('../src/controllers/user.controller.js');
      const req: any = {
        params: { id: 'target-user-456' },
        user: { id: 'attacker-user-123' },
        profile: { id: 'attacker-user-123', role: 'student' },
        body: { full_name: 'Hacked Name' },
      };
      const res: any = {};

      await assert.rejects(
        async () => {
          await UserController.updateUser(req, res);
        },
        /You can only update your own profile/
      );
    });
  } finally {
    server.close();
  }

  console.log(`\n=========================================`);
  console.log(`🏁 Integration Test Results: ${passedTests}/${totalTests} tests passed`);
  console.log(`=========================================\n`);

  if (passedTests !== totalTests) {
    process.exit(1);
  }
};

main().catch((err) => {
  console.error('Test runner failed:', err);
  process.exit(1);
});
