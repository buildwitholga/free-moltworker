#!/bin/bash
# Startup script for Clawdbot in Cloudflare Sandbox
# This script configures clawdbot from environment variables and starts the gateway

set -e

CONFIG_DIR="/root/.clawdbot"
CONFIG_FILE="$CONFIG_DIR/clawdbot.json"
TEMPLATE_FILE="$CONFIG_DIR/clawdbot.json.template"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Start with the template
if [ -f "$TEMPLATE_FILE" ]; then
    cp "$TEMPLATE_FILE" "$CONFIG_FILE"
else
    # Create minimal config if template doesn't exist (new config format)
    cat > "$CONFIG_FILE" << 'EOFCONFIG'
{
  "agents": {
    "defaults": {
      "workspace": "/root/clawd",
      "model": {
        "primary": "anthropic/claude-sonnet-4-20250514"
      }
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local"
  }
}
EOFCONFIG
fi

# Use Node.js for JSON manipulation since jq might not be available
node << 'EOFNODE'
const fs = require('fs');

const configPath = '/root/.clawdbot/clawdbot.json';
let config = {};

try {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (e) {
    console.log('Starting with empty config');
}

// Ensure nested objects exist (new config format)
config.agents = config.agents || {};
config.agents.defaults = config.agents.defaults || {};
config.agents.defaults.model = config.agents.defaults.model || {};
config.gateway = config.gateway || {};
config.channels = config.channels || {};

// Gateway configuration
config.gateway.port = 18789;
config.gateway.mode = 'local';

// Set gateway token if provided (use auth.token format)
if (process.env.CLAWDBOT_GATEWAY_TOKEN) {
    config.gateway.auth = config.gateway.auth || {};
    config.gateway.auth.token = process.env.CLAWDBOT_GATEWAY_TOKEN;
}

// Telegram configuration
if (process.env.TELEGRAM_BOT_TOKEN) {
    config.channels.telegram = config.channels.telegram || {};
    config.channels.telegram.botToken = process.env.TELEGRAM_BOT_TOKEN;
    config.channels.telegram.enabled = true;
    
    // DM policy
    config.channels.telegram.dm = config.channels.telegram.dm || {};
    config.channels.telegram.dm.policy = process.env.TELEGRAM_DM_POLICY || 'pairing';
}

// Discord configuration
if (process.env.DISCORD_BOT_TOKEN) {
    config.channels.discord = config.channels.discord || {};
    config.channels.discord.token = process.env.DISCORD_BOT_TOKEN;
    config.channels.discord.enabled = true;
    
    config.channels.discord.dm = config.channels.discord.dm || {};
    config.channels.discord.dm.policy = process.env.DISCORD_DM_POLICY || 'pairing';
}

// Slack configuration
if (process.env.SLACK_BOT_TOKEN && process.env.SLACK_APP_TOKEN) {
    config.channels.slack = config.channels.slack || {};
    config.channels.slack.botToken = process.env.SLACK_BOT_TOKEN;
    config.channels.slack.appToken = process.env.SLACK_APP_TOKEN;
    config.channels.slack.enabled = true;
}

// Write updated config
fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('Configuration updated successfully');
console.log('Config:', JSON.stringify(config, null, 2));
EOFNODE

echo "Starting Clawdbot Gateway..."
echo "Gateway will be available on port 18789"

# Set API keys as environment variables (clawdbot reads them from env)
# Start the gateway (blocking)
# Use provided token or generate a random one
# Set CLAWDBOT_GATEWAY_TOKEN via wrangler secret for production
if [ -n "$CLAWDBOT_GATEWAY_TOKEN" ]; then
    GATEWAY_TOKEN="$CLAWDBOT_GATEWAY_TOKEN"
else
    GATEWAY_TOKEN=$(head -c 32 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
    echo "Gateway token (generated): $GATEWAY_TOKEN"
fi
# Bind mode: 'lan' for local dev, 'auto' for production
BIND_MODE="${CLAWDBOT_BIND_MODE:-auto}"
echo "Bind mode: $BIND_MODE"
exec clawdbot gateway --port 18789 --verbose --allow-unconfigured --bind "$BIND_MODE" --token "$GATEWAY_TOKEN"
