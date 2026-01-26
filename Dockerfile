FROM docker.io/cloudflare/sandbox:0.7.0

# Install Node.js 22 (required by clawdbot)
# The base image has Node 20, we need to replace it with Node 22
# Using direct binary download for reliability
ENV NODE_VERSION=22.13.1
RUN apt-get update && apt-get install -y xz-utils \
    && curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && node --version \
    && npm --version

# Install pnpm globally
RUN npm install -g pnpm

# Install clawdbot globally
RUN npm install -g clawdbot@latest \
    && clawdbot --version

# Create clawdbot directories
RUN mkdir -p /root/.clawdbot \
    && mkdir -p /root/clawd \
    && mkdir -p /root/clawd/skills

# Copy startup script
COPY start-clawdbot.sh /usr/local/bin/start-clawdbot.sh
RUN chmod +x /usr/local/bin/start-clawdbot.sh

# Copy default configuration template
# Build cache bust: 2026-01-26-v12
COPY clawdbot.json.template /root/.clawdbot/clawdbot.json.template

# Set working directory
WORKDIR /root/clawd

# Expose the gateway port
EXPOSE 18789
