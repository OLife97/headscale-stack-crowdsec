#!/bin/bash
# init.sh - Prepares the environment for the Headscale + Caddy + CrowdSec stack

set -e

echo "Creating necessary directories for bind mounts..."
# We only create directories that are explicitly bind-mounted in compose.yaml.
# Caddy's config and logs are  handled natively by Docker Volumes.
mkdir -p caddy/data
mkdir -p crowdsec/config/notifications crowdsec/data
mkdir -p headscale/config headscale/data

echo "Preparing Headscale configuration..."
# Headscale crashes if config.yaml is empty. We download the official template
if [ ! -f headscale/config/config.yaml ]; then
  echo "Downloading default Headscale config..."
  wget -qO headscale/config/config.yaml "https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml"
  
  sed -i 's|db_path:.*|db_path: /var/lib/headscale/db.sqlite|' headscale/config/config.yaml
  echo "✅ Headscale config downloaded."
fi  

  # Set the correct SQLite database path for our Docker container
echo "Preparing CrowdSec configurations..."
# ==========================================
# CROWDSEC CONFIGURATIONS (Only if missing)
# ==========================================

# Acquis.yaml
if [ ! -f crowdsec/acquis.yaml ]; then
cat << 'EOF' > crowdsec/acquis.yaml
filenames:
  - /var/log/caddy/*.log
labels:
  type: caddy
poll_without_inotify: true
EOF
fi

# Http.yaml (Notification template for NTFY/Gotify)
if [ ! -f crowdsec/config/notifications/http.yaml ]; then
cat << 'EOF' > crowdsec/config/notifications/http.yaml
type: http
name: http_default
log_level: info

# Accumulate alerts for 30 seconds before sending to avoid notification flood
group_wait: 30s

format: |
  {{range . -}}
  {{$alert := . -}}
  {{range .Decisions -}}
  🚨 CrowdSec Ban
  IP: {{.Value}}
  Duration: {{.Duration}}
  Scenario: {{$alert.Scenario}}
  {{end -}}
  {{end -}}

url: ${CROWDSEC_NOTIFY_URL}
method: POST

# --- Choose your provider and comment the other ---
#
# NTFY: uncomment these two lines
headers:
  Authorization: ${CROWDSEC_NOTIFY_AUTH_TOKEN}
  Title: "CrowdSec Alert"
  Tags: "warning,skull"
#
# GOTIFY: comment the block above and uncomment these two lines
# headers:
#   X-Gotify-Key: ${CROWDSEC_NOTIFY_AUTH_TOKEN}
EOF
fi

# Profiles.yaml
if [ ! -f crowdsec/config/profiles.yaml ]; then
cat << 'EOF' > crowdsec/config/profiles.yaml
name: default_ip_remediation
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
  - type: ban
    duration: 4h
notifications:
  - http_default
on_success: break
EOF
fi

# ==========================================
# GEOIP MAXMIND: DOWNLOAD DATABASE
# ==========================================
GEOIP_DB="caddy/data/GeoLite2-Country.mmdb"
GEOIP_URL="https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb"

# check if file exists
if [ -f "$GEOIP_DB" ]; then
    FILE_AGE_DAYS=$(( ($(date +%s) - $(stat -c %Y "$GEOIP_DB")) / 86400 ))
    if [ $FILE_AGE_DAYS -gt 30 ]; then
        echo "⚠️  GeoIP DB exists but is $FILE_AGE_DAYS days old. Update available."
        read -p "Download latest MaxMind GeoLite2-Country DB? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            wget -qO "$GEOIP_DB" "$GEOIP_URL"
            echo "✅ GeoIP DB updated."
        else
            echo "Skipped GeoIP update."
        fi
    else
        echo "✅ GeoIP DB is recent ($FILE_AGE_DAYS days old)."
    fi
else
    echo "Downloading MaxMind GeoLite2-Country DB..."
    wget -qO "$GEOIP_DB" "$GEOIP_URL"
    echo "✅ GeoIP DB downloaded."
fi

# ==========================================
# ENV FILE GENERATION
# ==========================================
if [ ! -f .env ]; then
    echo "Generating .env file from .env.example..."
    cp .env.example .env
    BOUNCER_KEY=$(openssl rand -hex 32)
    sed -i "s/INSERT_GENERATED_KEY_HERE/$BOUNCER_KEY/g" .env
    echo "✅ .env file created."
fi

echo "Initialization complete! Edit .env and start with 'docker compose up -d'"
