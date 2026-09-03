# ZankoAI Flutter & Backend Architecture Guidelines

- This project is a Flutter application targeting Android, iOS, and Web.
- Backend infrastructure relies on Cloud Firestore, Firebase Auth, Firebase Storage, and a Cloudflare Worker for push notifications (`https://zankoai.rawankurdi181.workers.dev`).
- Admin panel is deployed as a React SPA at `https://zanko-admin.vercel.app/`.
- All network connections and `HttpClient` instances in Dart must be properly closed to prevent socket leaks.
- Always check `kIsWeb` when invoking `dart:io` APIs.
