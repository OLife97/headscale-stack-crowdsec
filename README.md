# 🛡️ Headscale + Caddy + CrowdSec Stack

A production-ready, minimal, and fully environment-driven Docker Compose stack for self-hosting
[Headscale](https://headscale.net) — the open-source, self-hosted implementation of the Tailscale
control server — secured by [CrowdSec](https://www.crowdsec.net) and reverse-proxied through
[Caddy](https://caddyserver.com) with automatic TLS, Cloudflare Dynamic DNS, MaxMind GeoIP filtering, and OIDC authentication.

---

## ✨ Features

- **Headscale** — Self-hosted Tailscale control plane with embedded DERP and STUN server
- **Caddy** — Automatic HTTPS (Let's Encrypt), Cloudflare DNS challenge, HTTP/3 (QUIC)
- **CrowdSec** — Active intrusion prevention via Caddy bouncer plugin
- **MaxMind GeoIP** — Native country-based IP filtering before requests even reach Headscale
- **Push Notifications** — Real-time CrowdSec ban alerts via NTFY, Gotify, or any HTTP webhook
- **Cloudflare DDNS** — Automatic public IP update via caddy-dynamicdns module
- **OIDC Authentication** — Support for Google, Authentik, Keycloak, etc., with granular Access Control
- **Version Pinning** — Define exactly which image tags to pull via `.env`
- **Git-safe** — `.gitignore` is pre-configured to exclude all secrets and runtime data
- **Automated init script** — Safely creates files, generates secrets, and downloads the GeoIP DB

---

## 📦 Stack

| Service   | Image                                     | Role                         |
|-----------|-------------------------------------------|------------------------------|
| Headscale | `headscale/headscale:${VERSION}`          | VPN Control Plane            |
| Caddy     | `ghcr.io/olife97/dhi-caddy-cloudflare`    | Reverse Proxy + TLS + DDNS   |
| CrowdSec  | `crowdsecurity/crowdsec:${VERSION}`       | IPS / Threat Intelligence    |

---

## ⚙️ Prerequisites

- Docker Engine **v24+** and Docker Compose **v2+**
- A domain name with **Cloudflare DNS** management
- A **Cloudflare API Token** with `Zone:DNS:Edit` permissions
- **DNS Record:** You must manually create the initial `A` (and/or `AAAA`) record for your subdomain in the Cloudflare dashboard. Caddy's DDNS module updates the IP of an *existing* record, but it will not create a new one from scratch.
- A Google Cloud **OAuth 2.0 Client ID** (or any OIDC provider)
- Ports **80**, **443** (TCP + UDP), and **3478/UDP** open on your firewall/router

---

## 🚀 Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/olife97/headscale-stack-crowdsec.git && cd headscale-stack-crowdsec
```

### 2. Run the initialization script

This will:
- Create all required directories and placeholder files
- Download the latest **MaxMind GeoLite2-Country** database (and prompt for updates if already present)
- Auto-generate the CrowdSec `acquis.yaml`, `profiles.yaml`, and `http.yaml` notification templates
- Auto-generate a secure 256-bit key for the CrowdSec bouncer
- Copy `.env.example` to `.env`

```bash
chmod +x init.sh && ./init.sh
```
<details>
<summary><b>🛠️ Curious what <code>init.sh</code> actually does? (Click to expand)</b></summary>

For transparency and security, here is exactly what the initialization script automates:

1. **Directory Creation:** Safely creates the necessary local directories for bind mounts (`headscale/config`, `headscale/data`, `crowdsec/...`) *before* Docker starts, preventing permission issues.
2. **Headscale Config Provisioning:** Downloads the latest official `config-example.yaml` from the Headscale repository and strictly adjusts the `db_path` to match our Docker container environment.
3. **CrowdSec Provisioning:** Auto-generates three critical YAML files if they don't exist:
   - `acquis.yaml` (Instructs CrowdSec to read Caddy's JSON logs).
   - `http.yaml` (Sets up the payload format for NTFY/Gotify push notifications).
   - `profiles.yaml` (Ties IP bans to the HTTP notification trigger).
4. **MaxMind GeoIP Database:** Downloads the free `GeoLite2-Country.mmdb`.
5. **Secure `.env` Generation:** Copies `.env.example` to `.env` and uses `openssl rand -hex 32` to automatically generate a highly secure cryptographic token for the `CROWDSEC_BOUNCER_KEY`.

> **Safe to run multiple times!**
> It checks for the existence of your config files before creating them, meaning it **will never overwrite** your custom `.env` or YAML configurations.
> 
> You can (and should) **re-run `./init.sh` anytime** to check the age of your MaxMind GeoIP database. If it's older than 30 days, the script will automatically prompt you to download the latest updates.

</details>


### 3. Configure the environment

Open `.env` and fill in your values. Pay special attention to the OIDC Whitelist, GeoIP Countries, and Notification sections.

```bash
nano .env
```
### 4. Generate Secrets

#### Cloudflare API Token
- Go to [Cloudflare Dashboard → Profile → API Tokens](https://dash.cloudflare.com/profile/api-tokens)
- Click **Create Token** → **Edit zone DNS** template
- Under **Zone Resources**, select your domain
- Copy the token into `CF_API_TOKEN` in `.env`

#### Google OAuth2 Credentials (OIDC)
- Go to [Google Cloud Console → APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
- Click **Create Credentials → OAuth 2.0 Client ID** (Web application)
- Add the following **Authorized redirect URI**:
   ```
   https://subdomain.domain.tld/oidc/callback
   ```
- Copy **Client ID** and **Client Secret** into `.env`

> [!WARNING]
> The redirect URI in Google Console must match **exactly** the Headscale `server_url` + `/oidc/callback`.

### 5. Start the stack

```bash
docker compose up -d
```

> [!NOTE]
> On first run, CrowdSec will download its collections and Caddy will request a TLS certificate
> from Let's Encrypt. Give the stack ~30 seconds to fully stabilize.

---

## 🌍 GeoIP Filtering & Notifications

### MaxMind GeoIP
The stack automatically filters traffic based on geolocation. In your `.env` file, edit the `ALLOWED_COUNTRIES` variable using ISO 3166-1 alpha-2 codes (space-separated). Connections from any other country will be silently dropped by Caddy.
```env
ALLOWED_COUNTRIES="IT SM VA CH"
```

### Push Notifications (NTFY / Gotify)
You can receive push notifications on your phone whenever CrowdSec bans a malicious IP. Configure the webhook in `.env`:
```env
# Example for NTFY:
CROWDSEC_NOTIFY_URL=https://ntfy.sh/your_secret_topic
CROWDSEC_NOTIFY_AUTH_HEADER=Authorization
CROWDSEC_NOTIFY_AUTH_TOKEN="Bearer optional_token"

# Example for Gotify:
CROWDSEC_NOTIFY_URL=https://gotify.yourdomain.com/message
CROWDSEC_NOTIFY_AUTH_HEADER=X-Gotify-Key
CROWDSEC_NOTIFY_AUTH_TOKEN="your_app_token"
```
Test notifications:
```bash
docker exec crowdsec cscli notifications test http_default
```
---

## 🛂 OIDC Access Control (Whitelist)

Headscale allows you to restrict who can join your VPN network. In the `.env` file, you **must choose one** of the following three methods:

1. **`HEADSCALE_OIDC_ALLOWED_USERS`** 
   - **Best for:** Families, small teams (e.g., `"user1@gmail.com user2@gmail.com"`)
2. **`HEADSCALE_OIDC_ALLOWED_DOMAINS`**
   - **Best for:** Companies with custom IdPs (e.g., `"yourcompany.com"`)
   - *(⚠️ WARNING: Never use public domains like `gmail.com` here!)*
3. **`HEADSCALE_OIDC_ALLOWED_GROUPS`**
   - **Best for:** Homelabs using Authentik or Keycloak (e.g., `"vpn-users"`)

---

## 🔑 Environment Variables Reference

| Variable                                       | Description                                                                 |
|------------------------------------------------|-----------------------------------------------------------------------------|
| `*_VERSION`                                    | Docker image tags (defaults to `latest`)                                    |
| `TZ`                                           | Timezone (e.g., `Europe/Rome`)                                              |
| `DOMAIN` / `SUBDOMAIN`                         | Root domain and subdomain (e.g., `example.com` and `vpn`)                   |
| `CF_API_TOKEN`                                 | Cloudflare API token with `Zone:DNS:Edit` permissions                       |
| `ALLOWED_COUNTRIES`                            | ISO country codes allowed to access the server (e.g., `IT US`)              |
| `CROWDSEC_NOTIFY_*`                            | Webhook URL and Auth tokens for ban alerts                                  |
| `HEADSCALE_OIDC_ISSUER`                        | OIDC issuer URL (e.g., `https://accounts.google.com`)                       |
| `HEADSCALE_OIDC_CLIENT_ID`                     | OAuth2 Client ID                                                            |

---

## 🧰 Management Commands

### Headscale
```bash
# Create a new user (namespace)
docker exec -it headscale headscale users create <username>

# Generate a pre-auth key (24h expiry)
docker exec -it headscale headscale preauthkeys create -e 24h -u <userID>
```

### CrowdSec
```bash
# Check if the Caddy bouncer is registered
docker exec -it crowdsec cscli bouncers list

# View active decisions (bans)
docker exec -it crowdsec cscli decisions list

# Manually ban an IP (permanent)
docker exec -it crowdsec cscli decisions add --ip <IP_ADDRESS> --type ban --duration 0

# Unban an IP
docker exec -it crowdsec cscli decisions delete --ip <IP_ADDRESS>
```

### Updating

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate

# Remove old dangling images
docker image prune -f
```
---

## 🔒 Security Notes

- **Zero hardcoded secrets**: All secrets are passed via `.env`, for easy setup and replication.
- **Read-only mounts**: Config files use `:ro` (read-only) wherever possible.
- **Active IPS & GeoIP**: CrowdSec analyzes JSON logs in real-time, while Caddy drops unauthorized countries at the edge.

---

## 🗄️ Backup Recommendations

The following paths contain **persistent state** and should be backed up regularly:

| Path                        | Contents                              |
|-----------------------------|---------------------------------------|
| `headscale/data/db.sqlite`  | All nodes, users, preauthkeys, routes |
| `headscale/data/*.key`      | Private keys (loss = full re-enrollment of all clients) |
| `.env`                      | All secrets (store encrypted)         |


### 🛑 Crucial Backup Rule: Stop the Stack First
Because Headscale uses a SQLite database (`db.sqlite`), copying the file while the container is actively writing to it can lead to severe database corruption.
**Always stop the stack before running your backup script:**
```bash
docker compose down
# Run your rsync / tar / backup command here
docker compose up -d
```

### 💡  Note on Storage Architecture (Bind Mounts vs Volumes)
By design, this stack uses **Bind Mounts** (e.g., `./headscale/data:/var/lib/headscale`) for persistent data instead of native Docker Named Volumes. 
This was a deliberate choice to make backups extremely simple for homelab users, you can just `tar` or `rsync` the project folder without having to dive into `/var/lib/docker/volumes/` as the `root` user.

However, if you are an advanced sysadmin migrating to a production environment (or running on a specialized filesystem like ZFS), you can easily convert these to Docker Named Volumes by editing the `compose.yaml`:
1. Change `./headscale/data:/var/lib/headscale` to `headscale_data:/var/lib/headscale`
2. Declare `headscale_data:` under the top-level `volumes:` block.

> [!CAUTION]
> Loss of `noise_private.key` or `private.key` from `headscale/data/` requires
> **all clients to re-enroll**. Treat these files as you would SSH private keys.


## 🙏 Acknowledgments
This stack is made possible by the incredible work of the open-source community. A huge thank you to:
- [juanfont/headscale](https://github.com/juanfont/headscale) — The amazing open-source Tailscale control server
- [caddyserver/caddy](https://github.com/caddyserver/caddy) — The Go-based web server with automatic HTTPS
- [crowdsecurity/crowdsec](https://github.com/crowdsecurity/crowdsec) — The open-source IPS/IDS engine
- [hslatman/caddy-crowdsec-bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer) — CrowdSec plugin for Caddy
- [mholt/caddy-dynamicdns](https://github.com/mholt/caddy-dynamicdns) — Dynamic DNS module for Caddy
- [P3TERX/GeoLite.mmdb](https://github.com/P3TERX/GeoLite.mmdb) — Free automated MaxMind GeoLite2 databases
- [OLife97/dhi-caddy-cloudflare](https://github.com/OLife97/dhi-caddy-cloudflare) — My pre-built Caddy image with Cloudflare, CrowdSec and GeoIP modules 

## 📄 License
### Upstream Licenses Disclaimer
This repository orchestrates several open-source projects. By using this stack, you are also subject to their respective licenses:
- **[Headscale](https://github.com/juanfont/headscale)** is licensed under the [BSD 3-Clause License](https://github.com/juanfont/headscale/blob/main/LICENSE).
- **[Caddy](https://github.com/caddyserver/caddy)** is licensed under the [Apache License 2.0](https://github.com/caddyserver/caddy/blob/master/LICENSE).
- **[CrowdSec](https://github.com/crowdsecurity/crowdsec)** is licensed under the [MIT License](https://github.com/crowdsecurity/crowdsec/blob/master/LICENSE).

**Note on MaxMind GeoIP:**
This product includes GeoLite2 data created by MaxMind, available from [https://www.maxmind.com](https://www.maxmind.com).
If you use the GeoIP module, you must comply with the MaxMind End User License Agreement (EULA).
This project is licensed under the **MIT License**.

---

<p align="center">
  Made with ❤️ for self-hosters who believe their infrastructure should be fully under their control.
  This README and some-other parts of this repo are Vibe-coded.
</p>

---
