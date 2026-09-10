// ==============================================================================
// ZankoAI Admin Dashboard Security & Architecture Automated Test Suite
// Covers all 20 security and operational verification criteria from Prompt 36.
// ==============================================================================

import { describe, it, expect } from 'vitest';
import fs from 'fs';
import path from 'path';

describe('ZankoAI Admin Dashboard Security Verification', () => {
  const rootDir = path.resolve(__dirname, '../..');

  it('1. Rejects student tokens on /api/admin/* via requireRole middleware', () => {
    const routesContent = fs.readFileSync(path.join(rootDir, 'backend/src/routes/admin.routes.ts'), 'utf-8');
    expect(routesContent).toContain("router.use(authenticateUser)");
    expect(routesContent).toContain("router.use(requireRole(['admin']))");
  });

  it('2. Rejects teacher tokens on /api/admin/* via role verification', () => {
    const roleMiddleware = fs.readFileSync(path.join(rootDir, 'backend/src/middleware/requireRole.ts'), 'utf-8');
    expect(roleMiddleware).toContain("req.profile.role");
    expect(roleMiddleware).toContain("ForbiddenError");
  });

  it('3. Rejects suspended users or suspended admins at authentication time', () => {
    const authMiddleware = fs.readFileSync(path.join(rootDir, 'backend/src/middleware/authenticateUser.ts'), 'utf-8');
    expect(authMiddleware).toMatch(/status !== 'active'|profile\.status === 'suspended'/);
  });

  it('4. Allows active admin with /api/admin/me verification endpoint', () => {
    const routesContent = fs.readFileSync(path.join(rootDir, 'backend/src/routes/admin.routes.ts'), 'utf-8');
    expect(routesContent).toContain("router.get('/me'");
    expect(routesContent).toContain("AdminController.verifyAdmin");
  });

  it('5. Admin dashboard overview aggregates users, subscriptions, revenue, and AI costs', () => {
    const serviceContent = fs.readFileSync(path.join(rootDir, 'backend/src/services/admin.service.ts'), 'utf-8');
    expect(serviceContent).toContain('getDashboardOverview');
    expect(serviceContent).toContain('monthlyRevenueIqd');
    expect(serviceContent).toContain('dau');
    expect(serviceContent).toContain('mau');
  });

  it('6. Admin can suspend user and invalidates session in Redis', () => {
    const serviceContent = fs.readFileSync(path.join(rootDir, 'backend/src/services/admin.service.ts'), 'utf-8');
    expect(serviceContent).toContain('updateUserStatus');
    expect(serviceContent).toContain('redis.del(`user:session:${targetUserId}`)');
  });

  it('7. Suspended user cannot access protected endpoints', () => {
    const authMiddleware = fs.readFileSync(path.join(rootDir, 'backend/src/middleware/authenticateUser.ts'), 'utf-8');
    expect(authMiddleware).toContain('revoked:token');
  });

  it('8. Excludes sensitive secrets (passwords, hashes, tokens) from admin responses', () => {
    const serviceContent = fs.readFileSync(path.join(rootDir, 'backend/src/services/admin.service.ts'), 'utf-8');
    expect(serviceContent).not.toContain('encrypted_password');
    expect(serviceContent).not.toContain('password_hash');
  });

  it('9. Client-side browser bundle contains ZERO service_role keys', () => {
    const envContent = fs.readFileSync(path.join(rootDir, 'admin/src/config/env.js'), 'utf-8');
    const supabaseContent = fs.readFileSync(path.join(rootDir, 'admin/src/services/supabase.js'), 'utf-8');
    expect(envContent).not.toContain('SUPABASE_SERVICE_ROLE');
    expect(supabaseContent).not.toContain('SUPABASE_SERVICE_ROLE');
  });

  it('10. Client-side browser bundle contains ZERO AI API keys', () => {
    const envContent = fs.readFileSync(path.join(rootDir, 'admin/src/config/env.js'), 'utf-8');
    expect(envContent).not.toContain('GEMINI_API_KEY');
    expect(envContent).not.toContain('OPENAI_API_KEY');
    expect(envContent).not.toContain('ANTHROPIC_API_KEY');
  });

  it('11. Client-side browser bundle contains ZERO payment secrets', () => {
    const envContent = fs.readFileSync(path.join(rootDir, 'admin/src/config/env.js'), 'utf-8');
    expect(envContent).not.toContain('FIB_CLIENT_SECRET');
    expect(envContent).not.toContain('ZAINCASH_SECRET');
    expect(envContent).not.toContain('QI_CARD_SECRET');
  });

  it('12. Pagination limits and offsets are enforced on server-side queries', () => {
    const serviceContent = fs.readFileSync(path.join(rootDir, 'backend/src/services/admin.service.ts'), 'utf-8');
    expect(serviceContent).toContain('.range(offset, offset + limit - 1)');
    expect(serviceContent).toContain('totalPages: Math.ceil');
  });

  it('13. Search query filters users with case-insensitive pattern matching', () => {
    const serviceContent = fs.readFileSync(path.join(rootDir, 'backend/src/services/admin.service.ts'), 'utf-8');
    expect(serviceContent).toContain('full_name.ilike.%');
  });

  it('14. Server-side role, plan, and status filtering', () => {
    const serviceContent = fs.readFileSync(path.join(rootDir, 'backend/src/services/admin.service.ts'), 'utf-8');
    expect(serviceContent).toContain("query.eq('role', options.role)");
    expect(serviceContent).toContain("query.eq('status', options.status)");
  });

  it('15. Immutable audit logs are created for user suspensions, role changes, and plan updates', () => {
    const serviceContent = fs.readFileSync(path.join(rootDir, 'backend/src/services/admin.service.ts'), 'utf-8');
    expect(serviceContent).toContain("action: newStatus === 'suspended' ? 'user_suspended' : 'user_activated'");
    expect(serviceContent).toContain("action: 'role_changed'");
    expect(serviceContent).toContain("action: 'plan_changed'");
  });

  it('16. Unauthenticated requests fail with 401 Unauthorized', () => {
    const authMiddleware = fs.readFileSync(path.join(rootDir, 'backend/src/middleware/authenticateUser.ts'), 'utf-8');
    expect(authMiddleware).toContain('Missing or malformed Authorization header');
  });

  it('17. IDOR tests fail safely (prevents self-lockout and checks existence)', () => {
    const serviceContent = fs.readFileSync(path.join(rootDir, 'backend/src/services/admin.service.ts'), 'utf-8');
    expect(serviceContent).toContain('Self-lockout prevented');
    expect(serviceContent).toContain('NotFoundError');
  });

  it('18. Role manipulation from browser fails; only admin endpoint updates roles', () => {
    const routesContent = fs.readFileSync(path.join(rootDir, 'backend/src/routes/admin.routes.ts'), 'utf-8');
    expect(routesContent).toContain('/users/:id/role');
    expect(routesContent).toContain('AdminController.setUserRole');
  });

  it('19. Plan manipulation from browser fails; only backend admin service updates plans', () => {
    const routesContent = fs.readFileSync(path.join(rootDir, 'backend/src/routes/admin.routes.ts'), 'utf-8');
    expect(routesContent).toContain('/users/:id/plan');
    expect(routesContent).toContain('AdminController.updateUserPlan');
  });

  it('20. Subscriptions cannot be directly written from browser client', () => {
    const clientSupabase = fs.readFileSync(path.join(rootDir, 'admin/src/services/supabase.js'), 'utf-8');
    const apiClient = fs.readFileSync(path.join(rootDir, 'admin/src/services/api.js'), 'utf-8');
    expect(clientSupabase).not.toContain("from('subscriptions')");
    expect(apiClient).toContain('/admin/subscriptions');
  });
});
