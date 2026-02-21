# 🛡️ Headscale + Caddy + CrowdSec Stack

A production-ready, minimal, and fully environment-driven Docker Compose stack for self-hosting
[Headscale](https://headscale.net) — the open-source, self-hosted implementation of the Tailscale
control server — secured by [CrowdSec](https://www.crowdsec.net) and reverse-proxied through
[Caddy](https://caddyserver.com) with automatic TLS, Cloudflare Dynamic DNS, and OIDC authentication.

---

## ✨ Features

- **Headscale** — Self-hosted Tailscale control plane with embedded DERP and STUN server
- **Caddy** — Automatic HTTPS (Let's Encrypt), Cloudflare DNS challenge, HTTP/3 (QUIC)
- **CrowdSec** — Active intrusion prevention via Caddy bouncer plugin
- **Cloudflare DDNS** — Automatic public IP update via caddy-dynamicdns module
- **OIDC Authentication** — Support for Google, Authentik, Keycloak, etc., with granular Access Control (Users, Domains, or Groups)
- **Fully `.env` driven** — Zero secrets in the Compose file or config files
- **Git-safe** — `.gitignore` is pre-configured to exclude all secrets and runtime data
- **Idempotent init script** — Safe to re-run; never overwrites existing configs

---

## 📦 Stack

| Service   | Image                                     | Role                         |
|-----------|-------------------------------------------|------------------------------|
| Headscale | `headscale/headscale:latest`              | VPN Control Plane            |
| Caddy     | `ghcr.io/olife97/dhi-caddy-cloudflare`   | Reverse Proxy + TLS + DDNS   |
| CrowdSec  | `crowdsecurity/crowdsec:latest`           | IPS / Threat Intelligence    |

---

## 📁 Directory Structure

```
headscale-stack/
├── compose.yaml
├── .env                        # ← NOT committed (generated from .env.example)
├── .env.example                # Template with all required variables
├── .gitignore
├── init.sh                     # Initialization script
├── README.md
│
├── caddy/
│   ├── Caddyfile               # Reverse proxy + DDNS + CrowdSec config
│   ├── config/                 # Caddy runtime config (not committed)
│   ├── data/                   # Caddy TLS certificates (not committed)
│   └── logs/                   # Access logs read by CrowdSec (not committed)
│
├── crowdsec/
│   ├── acquis.yaml             # Log acquisition sources
│   ├── config/                 # CrowdSec runtime config (not committed)
│   └── data/                   # CrowdSec database (not committed)
│
└── headscale/
    ├── config/
    │   └── config.yaml         # Headscale base config (OIDC managed via ENV)
    └── data/                   # SQLite DB, private keys (not committed)
```

---

## ⚙️ Prerequisites

- Docker Engine **v24+** and Docker Compose **v2+**
- A domain name with **Cloudflare DNS** management
- A **Cloudflare API Token** with `Zone:DNS:Edit` permissions
- A Google Cloud **OAuth 2.0 Client ID** (or any OIDC provider)
- Ports **80**, **443** (TCP + UDP), and **3478/UDP** open on your firewall/router

---

## 🚀 Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/headscale-stack.git
cd headscale-stack
```

### 2. Run the initialization script

This will:
- Create all required directories and placeholder files
- Prevent Docker from creating directories in place of bind-mounted files
- Copy `.env.example` to `.env`
- Auto-generate a secure 256-bit key for the CrowdSec bouncer

```bash
chmod +x init.sh
./init.sh
```

### 3. Configure the environment

Open `.env` and fill in your values. Pay special attention to the OIDC Whitelist section.

```bash
nano .env
```

### 4. Start the stack

```bash
docker compose up -d
```

> [!NOTE]
> On first run, CrowdSec will download its collections and Caddy will request a TLS certificate
> from Let's Encrypt. Give the stack ~30 seconds to fully stabilize.

---

## 🛂 OIDC Access Control (Whitelist)

Headscale allows you to restrict who can join your VPN network. In the `.env` file, you **must choose one** of the following three methods depending on your setup. Uncomment the one you need and leave the others commented out:

1. **`HEADSCALE_OIDC_ALLOWED_USERS`** 
   - **Best for:** Families, small teams, or when using public IdPs (like Google or Microsoft).
   - **Example:** `"user1@gmail.com,user2@gmail.com"`
   - **Behavior:** Only exact email matches are allowed.

2. **`HEADSCALE_OIDC_ALLOWED_DOMAINS`**
   - **Best for:** Companies using Google Workspace or custom domain IdPs.
   - **Example:** `"yourcompany.com"`
   - **Behavior:** Anyone with an `@yourcompany.com` email can join. *(⚠️ WARNING: Never use public domains like `gmail.com` here!)*

3. **`HEADSCALE_OIDC_ALLOWED_GROUPS`**
   - **Best for:** Advanced homelabs using Authentik, Keycloak, or Authelia.
   - **Example:** `"headscale-admins,vpn-users"`
   - **Behavior:** Users must belong to the specified groups in your IdP.

---

## 🔑 Environment Variables Reference

| Variable                                       | Description                                                                 |
|------------------------------------------------|-----------------------------------------------------------------------------|
| `TZ`                                           | Timezone (e.g., `Europe/Rome`)                                              |
| `DOMAIN`                                       | Your root domain (e.g., `example.com`)                                      |
| `SUBDOMAIN`                                    | Subdomain for Headscale (e.g., `vpn`) → results in `vpn.example.com`       |
| `CF_API_TOKEN`                                 | Cloudflare API token with `Zone:DNS:Edit` permissions                       |
| `CROWDSEC_BOUNCER_KEY`                         | Auto-generated by `init.sh`. Do not change after first start                |
| `HEADSCALE_DNS_BASE_DOMAIN`                    | Base domain for MagicDNS (e.g., `ts.net` or your own)                      |
| `HEADSCALE_OIDC_ONLY_START_IF_OIDC_IS_AVAILABLE` | If `true`, Headscale refuses to start if the OIDC provider is unreachable   |
| `HEADSCALE_OIDC_ISSUER`                        | OIDC issuer URL (e.g., `https://accounts.google.com`)                       |
| `HEADSCALE_OIDC_CLIENT_ID`                     | OAuth2 Client ID                                                            |
| `HEADSCALE_OIDC_CLIENT_SECRET`                 | OAuth2 Client Secret                                                        |
| `HEADSCALE_OIDC_ALLOWED_*`                     | Whitelist control variable (Users, Domains, or Groups. Choose one)          |

---

## 🔐 Generating Secrets

### Cloudflare API Token
1. Go to [Cloudflare Dashboard → Profile → API Tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click **Create Token** → **Edit zone DNS** template
3. Under **Zone Resources**, select your domain
4. Copy the token into `CF_API_TOKEN` in `.env`

### Google OAuth2 Credentials (OIDC)
1. Go to [Google Cloud Console → APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials)
2. Click **Create Credentials → OAuth 2.0 Client ID** (Web application)
3. Add the following **Authorized redirect URI**:
   ```
   https://SUBDOMAIN.DOMAIN/oidc/callback
   ```
4. Copy **Client ID** and **Client Secret** into `.env`

> [!WARNING]
> The redirect URI in Google Console must match **exactly** the Headscale `server_url` + `/oidc/callback`. Any mismatch will result in a `redirect_uri_mismatch` error.

---

## 🧰 Management Commands

### Headscale
```bash
# Create a new user (namespace)
docker exec -it headscale headscale users create <username>

# Generate a pre-auth key (24h expiry)
docker exec -it headscale headscale preauthkeys create -e 24h -u <user-id>

# List all nodes
docker exec -it headscale headscale nodes list
```

### CrowdSec
```bash
# Check if the Caddy bouncer is registered
docker exec -it crowdsec cscli bouncers list

# View active decisions (bans)
docker exec -it crowdsec cscli decisions list

# Manually ban an IP (permanent)
docker exec -it crowdsec cscli decisions add --ip <IP_ADDRESS> --type ban --duration 0
```

### Caddy
```bash
# Reload Caddyfile without downtime
docker exec -it caddy caddy reload --config /etc/caddy/Caddyfile
```

---

## 🔒 Security Notes

- **Zero hardcoded secrets**: All secrets are passed via `.env`, for easy setup and replication.
- **Read-only mounts**: Config files use `:ro` (read-only) wherever possible.
- **Active IPS**: CrowdSec analyzes Caddy's JSON access logs in real-time and blocks malicious IPs before they reach Headscale.
- **Embedded DERP**: Reduces latency for peer-to-peer connections without relying on Tailscale's external infrastructure.

---

## 🗄️ Backup Recommendations

The following paths contain **persistent state** and should be backed up regularly:

| Path                        | Contents                              |
|-----------------------------|---------------------------------------|
| `headscale/data/db.sqlite`  | All nodes, users, preauthkeys, routes |
| `headscale/data/*.key`      | Private keys (loss = full re-enrollment of all clients) |
| `.env`                      | All secrets (store encrypted)         |

> [!CAUTION]
> Loss of `noise_private.key` or `private.key` from `headscale/data/` requires
> **all clients to re-enroll**. Treat these files as you would SSH private keys.

---

## 🔄 Updating

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate

# Remove old dangling images
docker image prune -f
```
## 🙏 Acknowledgments
This stack is made possible by the incredible work of the open-source community. A huge thank you to:
- [juanfont/headscale](https://github.com/juanfont/headscale) — The amazing open-source Tailscale control server
- [caddyserver/caddy](https://github.com/caddyserver/caddy) — The Go-based web server with automatic HTTPS
- [crowdsecurity/crowdsec](https://github.com/crowdsecurity/crowdsec) — The open-source IPS/IDS engine
- [hslatman/caddy-crowdsec-bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer) — CrowdSec plugin for Caddy
- [mholt/caddy-dynamicdns](https://github.com/mholt/caddy-dynamicdns) — Dynamic DNS module for Caddy
- [OLife97/dhi-caddy-cloudflare](https://github.com/OLife97/dhi-caddy-cloudflare) — Pre-built Caddy image with Cloudflare + CrowdSec modules (check other modules for GeoIp Filtering!)

## 📄 License
### Upstream Licenses Disclaimer
This repository orchestrates several open-source projects. By using this stack, you are also subject to their respective licenses:
- **[Headscale](https://github.com/juanfont/headscale)** is licensed under the [BSD 3-Clause License](https://github.com/juanfont/headscale/blob/main/LICENSE).
- **[Caddy](https://github.com/caddyserver/caddy)** is licensed under the [Apache License 2.0](https://github.com/caddyserver/caddy/blob/master/LICENSE).
- **[CrowdSec](https://github.com/crowdsecurity/crowdsec)** is licensed under the [MIT License](https://github.com/crowdsecurity/crowdsec/blob/master/LICENSE).
This project is licensed under the **MIT License**.


```
MIT License

Copyright (c) 2026 Gennaro Palumbo

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

---

<p align="center">
  Made with ❤️ for self-hosters who believe their infrastructure should be fully under their control.
</p>

---