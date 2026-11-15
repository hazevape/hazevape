# KeyForge — Roblox license portal

GitHub Pages frontend + Cloudflare Worker API + Cloudflare D1 database. Includes account registration/login, 14-day sessions, admin-generated lifetime or time-limited license keys, redemption, revocation, Roblox UserId binding, and a sample Roblox game script.

## 1. Set up the secure backend

1. Create a free Cloudflare account and install Node.js locally.
2. In a terminal, go into the `worker` directory.
3. Run `npx wrangler login` and sign into Cloudflare.
4. Run `npx wrangler d1 create roblox-licenses`.
5. Copy the **database_id** from its output into `worker/wrangler.toml` replacing `REPLACE_WITH_DATABASE_ID`.
6. In `worker/wrangler.toml`, change `SITE_ORIGIN` to your final GitHub Pages **origin** (no path). Example: `https://yourname.github.io`. For custom domains, use `https://yourdomain.com`.
7. Run `npx wrangler d1 execute roblox-licenses --remote --file=schema.sql` to create the database tables.
8. Run `npx wrangler deploy`. Copy the resulting `https://roblox-license-api.<subdomain>.workers.dev` URL.

`wrangler.toml` must be in `worker` when running these commands. For local development, use Wrangler's dev mode, but adjust CORS to the local site's origin. Do NOT put your Cloudflare credentials in GitHub.

## 2. Publish the GitHub Pages site

1. In `site/config.js`, replace the example URL with your deployed Worker URL (do not include `/api` or a trailing slash).
2. Create a new GitHub repository and upload the contents of the `site` directory **to the repository root** (`index.html`, `app.js`, `style.css`, `config.js`).
3. In GitHub repository Settings → Pages → Build and deployment, choose **Deploy from a branch**, branch `main`, folder `/ (root)`.
4. Open `https://YOUR_USERNAME.github.io/YOUR_REPOSITORY/` (or use your custom domain). Make sure `SITE_ORIGIN` in Wrangler matches `https://YOUR_USERNAME.github.io` without repository path.
5. Register an account using your email and a 12+ character password.

**Important:** GitHub Pages cannot run a database or protect backend secrets. Only publish the `site` files there; keep `worker` and the SQL schema in your local project or a private backend repo if desired. The backend uses no email verification or password reset: do not use an important personal password and consider adding those features before public launch.

## 3. Make yourself an admin

After you create your account, in your terminal from `worker` run:

```bash
npx wrangler d1 execute roblox-licenses --remote --command="UPDATE users SET is_admin=1 WHERE email='you@example.com';"
```

Replace `you@example.com` with the email you registered. **Only promote your own trusted account.** Log out and log in again. The admin panel is now accessible.

## 4. Create and distribute keys

- **Lifetime:** select `Lifetime`; the key never expires unless revoked.
- **Expiring:** enter days (e.g. 30). Its expiration clock begins **when redeemed**.
- Each key can be redeemed **once by one website account**.
- Keys bind to the **first Roblox UserId that verifies the redeemed key**. Another Roblox account cannot use that key.
- Revocation takes effect on the next verification. Full keys are shown **only at generation**; copy them securely.
- The dashboard shows key prefixes only, not full keys. A user must keep their redeemed key for the Roblox entry UI.

## 5. Connect your Roblox experience

1. Enable `Allow HTTP Requests` in your Roblox experience's Security settings.
2. Copy `roblox/ServerLicenseExample.lua` to `ServerScriptService`, changing `API_URL` to the deployed Worker endpoint.
3. Copy `roblox/ClientLicenseUI.lua` to `StarterPlayer > StarterPlayerScripts` as a **LocalScript**.
4. Start the game, enter a key previously redeemed on the dashboard and verify it.
5. Put all actual paid/restricted gameplay logic **on the server**. A client UI or client script cannot be trusted to enforce licensing.

### Security limitations / launch checklist

- Authentication passwords are salted and PBKDF2-hashed; access tokens are randomly generated and their SHA-256 hashes are stored in D1. Tokens are stored in browser **sessionStorage** and expire after 14 days.
- API endpoints include rudimentary per-IP/per-account rate limiting; for public production launch, add Cloudflare WAF/bot protection, monitoring, email verification, recovery/reset, admin audit logs, abuse controls and appropriate privacy/terms disclosures.
- `/api/verify` is public by design; randomized high-entropy keys and rate limiting protect against guessing. It binds to the first verifying Roblox user, so users should not share redeemed keys. The endpoint receives Roblox UserIds and stores them for licensing; disclose this appropriately.
- The sample Roblox UI is intentionally simple. The key input is transmitted to Roblox game servers; users should only enter keys in trusted games.
- GitHub Pages is static and CORS origin matching does **not** itself make an API secure; authorization checks happen inside the Worker.
- For public licensed Roblox scripts distributed to client devices, determined users may bypass local checks. This sample is for **server-authoritative Roblox experiences**, not tamper-proof client-script DRM.
