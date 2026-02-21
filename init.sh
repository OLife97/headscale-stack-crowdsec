#!/bin/bash
# init.sh - Prepares the environment for the Headscale + Caddy + CrowdSec stack

set -e

echo "Creating necessary directories..."
mkdir -p caddy/config caddy/data caddy/logs
mkdir -p crowdsec/config crowdsec/data
mkdir -p headscale/config headscale/data

echo "Creating placeholder files to avoid directory bind issues..."

# Headscale: config + db
if [ ! -f headscale/config/config.yaml ]; then
  touch headscale/config/config.yaml
  echo "# headscale config.yaml (will be populated by you or defaults)" > headscale/config/config.yaml
fi

if [ ! -f headscale/data/db.sqlite ]; then
  touch headscale/data/db.sqlite
fi

# CrowdSec: acquis + profiles + base config
if [ ! -f crowdsec/acquis.yaml ]; then
  touch crowdsec/acquis.yaml
  echo "# crowdsec acquis.yaml (log sources, e.g., caddy)" > crowdsec/acquis.yaml
fi

if [ ! -f crowdsec/config/profiles.yaml ]; then
  mkdir -p crowdsec/config
  touch crowdsec/config/profiles.yaml
  echo "# crowdsec profiles.yaml (actions, bans, etc.)" > crowdsec/config/profiles.yaml
fi

if [ ! -f crowdsec/config/config.yaml ]; then
  touch crowdsec/config/config.yaml
  echo "# crowdsec config.yaml (main config, optional if using defaults)" > crowdsec/config/config.yaml
fi

# Caddy: Caddyfile
if [ ! -f caddy/Caddyfile ]; then
  touch caddy/Caddyfile
  echo "# Caddyfile (will be filled with reverse proxy config)" > caddy/Caddyfile
fi

# Environment file handling
if [ ! -f .env ]; then
    echo "Generating .env file from .env.example..."
    cp .env.example .env
    
    # Generate a random 256-bit API key for the bouncer
    BOUNCER_KEY=$(openssl rand -hex 32)
    
    # Cross-platform sed (works on Linux and macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "s/INSERT_GENERATED_KEY_HERE/$BOUNCER_KEY/g" .env
    else
      sed -i "s/INSERT_GENERATED_KEY_HERE/$BOUNCER_KEY/g" .env
    fi
    
    echo "✅ .env file created. Remember to edit it with your Domain, Email, and OIDC settings!"
else
    echo "✅ .env file already exists, skipping generation."
fi

# Set permissions for Caddy logs so CrowdSec can read them
chmod -R 755 caddy/logs

echo "Initialization complete! You can now edit the .env file and start the stack with 'docker-compose up -d'."
