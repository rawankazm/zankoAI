# ZankoAI GitHub Secrets Management & Client/Server Isolation

This guide outlines how to configure **GitHub Repository Secrets** for **ZankoAI** with strict isolation boundaries between the Flutter client and the backend server.

---

## 1. Golden Security Rules

> [!CAUTION]
> 1. **Never Commit Secrets to Git**: `.env`, `.env.production`, `.key`, and `.pem` files are strictly git-ignored.
> 2. **Strict Client / Server Isolation**:
>    - Flutter client builds must **NEVER** receive server secrets.
>    - `SUPABASE_SERVICE_ROLE_KEY`, AI provider API keys, and payment gateway secrets belong **exclusively** on the backend.
> 3. **Least Privilege Principle**: The deployment SSH user (`zanko_deploy`) only has permissions to restart Docker containers and manage `/var/www/zankoAI`.

---

## 2. GitHub Secrets Setup Table

Navigate to your GitHub Repository -> **Settings** -> **Secrets and variables** -> **Actions** -> Click **New repository secret** for each item below:

### Category 1: Supabase Secrets
| Secret Name | Intended Scope | Description |
| :--- | :--- | :--- |
| `SUPABASE_URL` | Shared (Flutter & Backend) | Public project URL (e.g. `https://xyz.supabase.co`). |
| `SUPABASE_PUBLISHABLE_KEY` | **Client & Backend** | Safe anonymous public API key (used by Flutter client). |
| `SUPABASE_SERVICE_ROLE_KEY` | **BACKEND ONLY** | Privileged admin key with RLS bypass. **MUST NEVER be given to Flutter!** |
| `SUPABASE_JWT_SECRET` | **BACKEND ONLY** | Secret used to verify and decode user session JWT tokens. |

---

### Category 2: AI Provider Keys (Backend Only)
| Secret Name | Intended Scope | Description |
| :--- | :--- | :--- |
| `GEMINI_API_KEY` | **BACKEND ONLY** | Google Gemini API key for lecture notes, OCR, and AI Teacher. |
| `OPENAI_API_KEY` | **BACKEND ONLY** | OpenAI API key for backup LLM completions. |
| `ANTHROPIC_API_KEY` | **BACKEND ONLY** | Anthropic Claude API key for high-reasoning fallback. |

---

### Category 3: Payment Provider Keys (Backend Only)
| Secret Name | Intended Scope | Description |
| :--- | :--- | :--- |
| `FIB_CLIENT_ID` | **BACKEND ONLY** | First Iraqi Bank merchant OAuth client ID. |
| `FIB_CLIENT_SECRET` | **BACKEND ONLY** | First Iraqi Bank merchant OAuth client secret. |
| `ZAINCASH_MSISDN` | **BACKEND ONLY** | ZainCash merchant wallet phone number (e.g. `9647800000000`). |
| `ZAINCASH_MERCHANT_ID` | **BACKEND ONLY** | ZainCash merchant identifier. |
| `ZAINCASH_SECRET` | **BACKEND ONLY** | ZainCash HMAC SHA-256 secret. |

---

### Category 4: DigitalOcean Deployment & Infrastructure
| Secret Name | Intended Scope | Description |
| :--- | :--- | :--- |
| `DO_DROPLET_HOST` | CI/CD Pipeline | Public IPv4 address of your DigitalOcean Droplet. |
| `DO_SSH_USER` | CI/CD Pipeline | Non-root deployment user (set to `zanko_deploy`). |
| `DO_SSH_PRIVATE_KEY` | CI/CD Pipeline | Private Ed25519/RSA SSH key authorized on the Droplet. |
| `REDIS_PASSWORD` | **BACKEND ONLY** | Strong 64-character hex password for internal Redis cluster. |
| `BACKUP_ENCRYPTION_KEY` | **BACKEND ONLY** | AES-256 symmetric vault key for encrypted database backups. |

---

## 3. How CI/CD Enforces Secret Isolation

During production deployment in `.github/workflows/deploy-production.yml`:
1. The GitHub Actions runner connects over SSH to the Droplet.
2. It writes `backend/.env.production` directly on the server filesystem.
3. It sets `chmod 600 backend/.env.production` so only `zanko_deploy` and root can read it.
4. The Flutter build process compiles client binaries using only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
5. Under no circumstances are `SUPABASE_SERVICE_ROLE_KEY` or AI/Payment keys included in Flutter assets or environment defines.
