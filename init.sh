#!/bin/bash
# init.sh - Prepares the environment for the Headscale + Headplane + Caddy + CrowdSec stack

set -e

echo "Creating necessary directories for bind mounts..."
mkdir -p caddy/data
mkdir -p crowdsec/config/notifications crowdsec/data
mkdir -p headscale/config headscale/data
mkdir -p headplane/data  # ← AGGIUNTO

echo "Preparing Headscale configuration..."
if [ ! -f headscale/config/config.yaml ]; then
  echo "Downloading default Headscale config..."
  wget -qO headscale/config/config.yaml "https://raw.githubusercontent.com/juanfont/headscale/main/config-example.yaml"
  sed -i 's|db_path:.*|db_path: /var/lib/headscale/db.sqlite|' headscale/config/config.yaml
  echo "✅ Headscale config downloaded."
fi 

# ... (tutta la sezione CrowdSec invariata) ...

# ==========================================
# HEADPLANE DATA DIRECTORY
# ==========================================
echo "Preparing Headplane data directory..."
mkdir -p headplane/data
touch headplane/data/.ready  # Marker per readiness

# ==========================================
# ENV FILE GENERATION (AGGIORNATO)
# ==========================================
if [ ! -f .env ]; then
    echo "Generating .env file from .env.example..."
    cp .env.example .env
    
    BOUNCER_KEY=$(openssl rand -hex 32)
    HEADSCALE_API_KEY="hscale_$(openssl rand -hex 32)"
    HEADPLANE_JWT_SECRET=$(openssl rand -base64 48)  # ← 64 chars sicuro
    
    sed -i "s|INSERT_GENERATED_KEY_HERE|$BOUNCER_KEY|g" .env
    sed -i "s|INSERT_HEADSCALE_API_KEY|$HEADSCALE_API_KEY|g" .env
    sed -i "s|INSERT_HEADPLANE_JWT_SECRET|$HEADPLANE_JWT_SECRET|g" .env
    
    echo "✅ .env file created with secrets:"
    echo "   CROWDSEC_BOUNCER_KEY: $BOUNCER_KEY"
    echo "   HEADSCALE_API_KEY: $HEADSCALE_API_KEY"
    echo "   HEADPLANE_JWT_SECRET: ${HEADPLANE_JWT_SECRET:0:20}..."
fi

echo "Initialization complete! Edit .env (OIDC vars) and start with 'docker compose up -d'"