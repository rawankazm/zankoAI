# ZankoAI Flutter & Backend Architecture Guidelines

- This project is a Flutter application targeting Android, iOS, and Web.
- Backend infrastructure relies on Supabase Auth, Supabase PostgreSQL with RLS, Supabase Storage, and a dedicated DigitalOcean API server (Node.js/Express/TypeScript + Redis + BullMQ) with AI microservices.
- Admin panel is deployed as a React SPA at `https://zanko-admin.vercel.app/`.
- All network connections and `HttpClient` instances in Dart must be properly closed to prevent socket leaks.
- Always check `kIsWeb` when invoking `dart:io` APIs.
