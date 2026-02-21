#!/bin/bash
# init.sh - Prepares the environment for the Headscale + Caddy + CrowdSec stack

set -e

echo "Creating necessary directories..."
mkdir -p caddy/config caddy/data caddy/logs
mkdir -p crowdsec/config/notifications crowdsec/data
mkdir -p headscale/config headscale/data

echo "Creating placeholder files to avoid directory bind issues..."

if [ ! -f headscale/config/config.yaml ]; then
  touch headscale/config/config.yaml
fi

if [ ! -f headscale/data/db.sqlite ]; then
  touch headscale/data/db.sqlite
fi

if [ ! -f caddy/Caddyfile ]; then
  touch caddy/Caddyfile
fi

# CROWDSEC CONFIGURATIONS (Only if missing)
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

# Http.yaml (Notice the 'EOF' with quotes: no backslashes needed anymore!)
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

# GEOIP MAXMIND: DOWNLOAD DATABASE
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

# ENV FILE GENERATION
if [ ! -f .env ]; then
    echo "Generating .env file from .env.example..."
    cp .env.example .env
    BOUNCER_KEY=$(openssl rand -hex 32)
    sed -i "s/INSERT_GENERATED_KEY_HERE/$BOUNCER_KEY/g" .env
    echo "✅ .env file created."
fi

chmod -R 755 caddy/logs
echo "Initialization complete! Edit .env and start with 'docker compose up -d'"
