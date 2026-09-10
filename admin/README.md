# ZankoAI Admin Dashboard

Production administration web dashboard for ZankoAI educational platform.

## Architecture
- **Framework**: Vite + React 18 + Tailwind CSS
- **Authentication**: Supabase Auth (`@supabase/supabase-js`)
- **Backend API**: DigitalOcean Dedicated Node.js / Express / TypeScript API (`api.zankoai.com`)
- **Role Control**: Backend-enforced `admin` role validation with HTTP Bearer tokens
- **Styling**: Modern Glassmorphic Dark UI with Kurdish RTL (`Noto Kufi Arabic` / `Vazirmatn`)

## Connected Features with Flutter App
1. **Users, Teachers & Students**: Instant role assignment, account status suspension/activation, VIP plan upgrades.
2. **Academic Hierarchy**: Real-time management of Universities, Faculties, Departments, and Courses with automated cache invalidation.
3. **Subscriptions & Payments**: Financial telemetry, VIP subscription request review, transaction verification.
4. **AI Cost & Limits**: Server-side enforced quotas per plan, real-time token tracking, budget alerting.
5. **Broadcast Notifications**: Global and target-specific announcements dispatched to in-app notification bell and FCM devices.
6. **Security & Audit Logs**: Immutable tamper-proof logging of all administrative actions.
