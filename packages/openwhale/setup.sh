#!/bin/bash
#
# OpenWhale First-Boot Setup
# Called by openwhale.service ExecStartPre
# Idempotent — safe to run on every boot
#

OPENWHALE_DIR="/opt/ainux/openwhale"
AINUX_DATA="/home/ainux/.ainux"
MARKER="${AINUX_DATA}/.openwhale-initialized"

# Already initialized?
if [ -f "${MARKER}" ]; then
    echo "[openwhale-setup] Already initialized, skipping."
    exit 0
fi

echo "[openwhale-setup] Running first-boot setup..."

# Ensure directories exist
mkdir -p "${AINUX_DATA}"

# If OpenWhale wasn't bundled in the image, clone it
if [ ! -f "${OPENWHALE_DIR}/openwhale.mjs" ]; then
    echo "[openwhale-setup] Cloning OpenWhale..."
    git clone https://github.com/viralcode/openwhale.git "${OPENWHALE_DIR}"
    cd "${OPENWHALE_DIR}"
    npm install -g pnpm
    pnpm install
    pnpm approve-builds
fi

# Create default .env if it doesn't exist
if [ ! -f "${OPENWHALE_DIR}/.env" ]; then
    echo "[openwhale-setup] Creating default .env..."
    cat > "${OPENWHALE_DIR}/.env" << 'EOF'
# AInux Default Configuration
# Add your API keys below

PORT=7777
NODE_ENV=production

# AI Providers (uncomment and add keys)
# ANTHROPIC_API_KEY=
# OPENAI_API_KEY=
# GOOGLE_API_KEY=

# Ollama (local, no key needed)
OLLAMA_HOST=http://localhost:11434

# AInux mode
AINUX_MODE=true
EOF
fi

# Initialize the database
cd "${OPENWHALE_DIR}"
node -e "
const Database = require('better-sqlite3');
const path = require('path');
const dbPath = path.join('${AINUX_DATA}', 'openwhale.db');
const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
console.log('[openwhale-setup] Database initialized at', dbPath);
db.close();
" 2>/dev/null || echo "[openwhale-setup] Database will be initialized on first run"

# Mark as initialized
touch "${MARKER}"
echo "[openwhale-setup] First-boot setup complete!"
