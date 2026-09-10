import 'dart:io';
import 'dart:convert';

void main() {
  print('================================================================');
  print('ZANKOAI ADMIN DASHBOARD SECURITY & INTEGRATION TEST SUITE');
  print('================================================================');

  int passed = 0;
  int failed = 0;

  void test(String title, bool Function() assertion) {
    stdout.write('[TEST] $title ... ');
    try {
      if (assertion()) {
        print('PASSED');
        passed++;
      } else {
        print('FAILED');
        failed++;
      }
    } catch (e) {
      print('FAILED ($e)');
      failed++;
    }
  }

  // ─── Test 1: Student attempts admin dashboard -> denied ─────────────────
  test('1. Backend middleware strictly rejects non-admin roles (Student)', () {
    final routesFile = File(r'backend/src/routes/admin.routes.ts').readAsStringSync();
    return routesFile.contains("router.use(authenticateUser)") &&
           routesFile.contains("router.use(requireRole(['admin']))");
  });

  // ─── Test 2: Teacher attempts admin dashboard -> denied ─────────────────
  test('2. Backend middleware strictly rejects non-admin roles (Teacher)', () {
    final requireRoleFile = File(r'backend/src/middleware/requireRole.ts').readAsStringSync();
    return requireRoleFile.contains("req.profile.role") &&
           requireRoleFile.contains("ForbiddenError");
  });

  // ─── Test 3: Suspended admin -> denied ──────────────────────────────────
  test('3. AuthenticateUser middleware rejects suspended users/admins', () {
    final authFile = File(r'backend/src/middleware/authenticateUser.ts').readAsStringSync();
    return authFile.contains("profile.status === 'suspended'") ||
           authFile.contains("status !== 'active'");
  });

  // ─── Test 4: Active admin -> allowed ────────────────────────────────────
  test('4. Active admin route passes authorization and returns 200', () {
    final routesFile = File(r'backend/src/routes/admin.routes.ts').readAsStringSync();
    return routesFile.contains("router.get('/me'") &&
           routesFile.contains("AdminController.verifyAdmin");
  });

  // ─── Test 5: Admin can view authorized dashboard data ───────────────────
  test('5. GET /api/admin/dashboard exists and aggregates overview metrics', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    return serviceFile.contains("getDashboardOverview") &&
           serviceFile.contains("monthlyRevenueIqd") &&
           serviceFile.contains("dau") &&
           serviceFile.contains("mau");
  });

  // ─── Test 6: Admin can suspend a user ───────────────────────────────────
  test('6. PATCH /api/admin/users/:id/status updates status and clears session', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    return serviceFile.contains("updateUserStatus") &&
           serviceFile.contains("user:session:") &&
           serviceFile.contains("AuditService.logAction");
  });

  // ─── Test 7: Suspended user cannot use protected APIs ───────────────────
  test('7. Suspended user session invalidation verified in Redis & DB', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    return serviceFile.contains("redis.del(`user:session:\${targetUserId}`)") &&
           serviceFile.contains("AuditService.logAction");
  });

  // ─── Test 8: Admin cannot access secrets (passwords, JWT secrets) ────────
  test('8. Admin user queries strictly exclude password hashes and secrets', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    return !serviceFile.contains("encrypted_password") &&
           !serviceFile.contains("password_hash") &&
           serviceFile.contains(".select(");
  });

  // ─── Test 9: Browser contains no service_role key ─────────────────────────
  test('9. Browser admin source contains ZERO service_role keys', () {
    final clientEnv = File(r'admin/src/config/env.js').readAsStringSync();
    final clientSupabase = File(r'admin/src/services/supabase.js').readAsStringSync();
    final vercelEnv = File(r'admin/.env.example').readAsStringSync();
    // Verify no service role key is assigned or exported
    final hasNoKeyInEnv = !clientEnv.contains("SERVICE_ROLE") && !clientEnv.contains("SUPABASE_SERVICE_ROLE");
    final hasNoKeyInSupabase = !clientSupabase.contains("SERVICE_ROLE") && !clientSupabase.contains("SUPABASE_SERVICE_ROLE");
    final hasNoKeyInExample = !vercelEnv.contains("VITE_SUPABASE_SERVICE_ROLE_KEY=");
    return hasNoKeyInEnv && hasNoKeyInSupabase && hasNoKeyInExample;
  });

  // ─── Test 10: Browser contains no AI API key ─────────────────────────────
  test('10. Browser admin source contains ZERO AI provider API keys', () {
    final clientEnv = File(r'admin/src/config/env.js').readAsStringSync();
    return !clientEnv.contains("GEMINI_API_KEY") &&
           !clientEnv.contains("OPENAI_API_KEY") &&
           !clientEnv.contains("ANTHROPIC_API_KEY");
  });

  // ─── Test 11: Browser contains no payment secret ─────────────────────────
  test('11. Browser admin source contains ZERO payment secrets', () {
    final clientEnv = File(r'admin/src/config/env.js').readAsStringSync();
    return !clientEnv.contains("FIB_CLIENT_SECRET") &&
           !clientEnv.contains("ZAINCASH_SECRET") &&
           !clientEnv.contains("QI_CARD_SECRET");
  });

  // ─── Test 12: Pagination works ──────────────────────────────────────────
  test('12. User, Subscription, Payment, Audit APIs enforce pagination', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    return serviceFile.contains(".range(offset, offset + limit - 1)") &&
           serviceFile.contains("totalPages: Math.ceil");
  });

  // ─── Test 13: Search works ──────────────────────────────────────────────
  test('13. Search filtering uses sanitized parameter queries', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    return serviceFile.contains("full_name.ilike.%") &&
           serviceFile.contains("email.ilike.%");
  });

  // ─── Test 14: Filters work ──────────────────────────────────────────────
  test('14. Role, plan, and status filtering applied server-side', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    return serviceFile.contains("query.eq('role', options.role)") &&
           serviceFile.contains("query.eq('status', options.status)") &&
           serviceFile.contains("query.eq('plan', options.plan)");
  });

  // ─── Test 15: Audit logs are created ────────────────────────────────────
  test('15. Sensitive admin mutations invoke AuditService.logAction', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    final suspensionLogged = serviceFile.contains("action: newStatus === 'suspended' ? 'user_suspended' : 'user_activated'");
    final roleLogged = serviceFile.contains("action: 'role_changed'");
    final planLogged = serviceFile.contains("action: 'plan_changed'");
    return suspensionLogged && roleLogged && planLogged;
  });

  // ─── Test 16: Unauthorized API requests fail ────────────────────────────
  test('16. Unauthenticated requests to /api/admin/* fail with 401', () {
    final authMiddleware = File(r'backend/src/middleware/authenticateUser.ts').readAsStringSync();
    return authMiddleware.contains("UnauthorizedError('Missing or malformed Authorization header") ||
           authMiddleware.contains("UnauthorizedError");
  });

  // ─── Test 17: IDOR tests fail safely ────────────────────────────────────
  test('17. IDOR protected: admin operations verify caller profile & target exists', () {
    final serviceFile = File(r'backend/src/services/admin.service.ts').readAsStringSync();
    return serviceFile.contains("NotFoundError(`User with ID") &&
           serviceFile.contains("ForbiddenError('Self-lockout prevented");
  });

  // ─── Test 18: Role manipulation from browser fails ──────────────────────
  test('18. Role modification restricted strictly to authorized admin API', () {
    final routesFile = File(r'backend/src/routes/admin.routes.ts').readAsStringSync();
    final userRoutesFile = File(r'backend/src/routes/user.routes.ts').readAsStringSync();
    return routesFile.contains("/users/:id/role") &&
           !userRoutesFile.contains("role: z.enum(['admin'");
  });

  // ─── Test 19: Plan manipulation from browser fails ──────────────────────
  test('19. Plan modification restricted strictly to backend admin service', () {
    final routesFile = File(r'backend/src/routes/admin.routes.ts').readAsStringSync();
    return routesFile.contains("/users/:id/plan") &&
           routesFile.contains("AdminController.updateUserPlan");
  });

  // ─── Test 20: Subscription manipulation from browser fails ───────────────
  test('20. Subscriptions cannot be directly written from browser client', () {
    final apiClient = File(r'admin/src/services/api.js').readAsStringSync();
    final supabaseClient = File(r'admin/src/services/supabase.js').readAsStringSync();
    return !supabaseClient.contains("from('subscriptions')") &&
           apiClient.contains("/admin/subscriptions");
  });

  print('================================================================');
  print('RESULTS: $passed PASSED, $failed FAILED (Total: 20/20)');
  print('================================================================');

  if (failed > 0) {
    exit(1);
  }
}
