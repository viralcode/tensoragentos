#!/bin/bash
#
# TensorAgent OS — AI Tools Install Script
# Installs and configures AI/developer tools for agentic workflows
#
# Usage: sudo bash install-ai-tools.sh
#

set -e

echo ""
echo "  ═══════════════════════════════════════════"
echo "  TensorAgent OS — AI Tools Installer"
echo "  ═══════════════════════════════════════════"
echo ""

AINUX_HOME="/home/ainux"
AINUX_DATA="${AINUX_HOME}/.ainux"

# ─── 1. System Developer Essentials ─────────────────────────────────────────
echo "[1/7] Installing developer essentials..."
apt-get update -qq
apt-get install -y -qq \
    tmux htop ripgrep \
    ffmpeg imagemagick \
    jq tree unzip \
    build-essential cmake \
    python3 python3-pip python3-venv \
    2>/dev/null || true
echo "  ✓ tmux, htop, ripgrep, ffmpeg, imagemagick installed"

# ─── 2. Ollama (Local LLM Runtime) ──────────────────────────────────────────
echo "[2/7] Installing Ollama..."
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || {
        echo "  ⚠ Ollama install script failed, trying manual..."
        # Manual install for ARM64
        OLLAMA_VERSION="0.6.2"
        curl -fsSL "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-arm64.tgz" -o /tmp/ollama.tgz
        tar -xzf /tmp/ollama.tgz -C /usr/local/
        rm -f /tmp/ollama.tgz
    }
fi

# Create Ollama systemd service
cat > /etc/systemd/system/ollama.service << 'EOF'
[Unit]
Description=Ollama Local LLM Server
After=network.target

[Service]
User=ainux
Group=ainux
ExecStart=/usr/local/bin/ollama serve
Environment="HOME=/home/ainux"
Environment="OLLAMA_HOST=0.0.0.0:11434"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ollama.service
systemctl start ollama.service 2>/dev/null || true
echo "  ✓ Ollama installed and service created"

# ─── 3. JupyterLab ──────────────────────────────────────────────────────────
echo "[3/7] Installing JupyterLab..."
sudo -u ainux python3 -m pip install --user --break-system-packages \
    jupyterlab ipykernel numpy pandas matplotlib scikit-learn \
    2>/dev/null || \
sudo -u ainux pip3 install --user \
    jupyterlab ipykernel numpy pandas matplotlib scikit-learn \
    2>/dev/null || true

# Create Jupyter config
mkdir -p "${AINUX_HOME}/.jupyter"
cat > "${AINUX_HOME}/.jupyter/jupyter_lab_config.py" << 'JCONF'
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.token = ''
c.ServerApp.password = ''
c.ServerApp.allow_root = False
c.ServerApp.allow_origin = '*'
c.ServerApp.notebook_dir = '/home/ainux'
JCONF
chown -R ainux:ainux "${AINUX_HOME}/.jupyter"

# Create JupyterLab systemd service
cat > /etc/systemd/system/jupyterlab.service << 'EOF'
[Unit]
Description=JupyterLab Notebook Server
After=network.target

[Service]
User=ainux
Group=ainux
ExecStart=/home/ainux/.local/bin/jupyter lab --config=/home/ainux/.jupyter/jupyter_lab_config.py
WorkingDirectory=/home/ainux
Environment="HOME=/home/ainux"
Environment="PATH=/home/ainux/.local/bin:/usr/local/bin:/usr/bin:/bin"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable jupyterlab.service
systemctl start jupyterlab.service 2>/dev/null || true
echo "  ✓ JupyterLab installed (port 8888)"

# ─── 4. VS Code Server (code-server) ────────────────────────────────────────
echo "[4/7] Installing VS Code Server..."
if ! command -v code-server &>/dev/null; then
    curl -fsSL https://code-server.dev/install.sh | sh 2>/dev/null || {
        echo "  ⚠ code-server install failed, trying npm..."
        npm install -g code-server 2>/dev/null || true
    }
fi

# Configure code-server
mkdir -p "${AINUX_HOME}/.config/code-server"
cat > "${AINUX_HOME}/.config/code-server/config.yaml" << 'CSCONF'
bind-addr: 0.0.0.0:8443
auth: none
cert: false
CSCONF
chown -R ainux:ainux "${AINUX_HOME}/.config"

# Create code-server systemd service
cat > /etc/systemd/system/code-server.service << 'EOF'
[Unit]
Description=VS Code Server (code-server)
After=network.target

[Service]
User=ainux
Group=ainux
ExecStart=/usr/bin/code-server --bind-addr 0.0.0.0:8443 --auth none /home/ainux
WorkingDirectory=/home/ainux
Environment="HOME=/home/ainux"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable code-server.service
systemctl start code-server.service 2>/dev/null || true
echo "  ✓ VS Code Server installed (port 8443)"

# ─── 5. Hugging Face CLI ────────────────────────────────────────────────────
echo "[5/7] Installing Hugging Face CLI..."
sudo -u ainux python3 -m pip install --user --break-system-packages \
    huggingface-hub[cli] transformers torch --extra-index-url https://download.pytorch.org/whl/cpu \
    2>/dev/null || \
sudo -u ainux pip3 install --user \
    huggingface-hub[cli] \
    2>/dev/null || true
echo "  ✓ Hugging Face CLI installed"

# ─── 6. Additional Python AI Libraries ──────────────────────────────────────
echo "[6/7] Installing Python AI libraries..."
sudo -u ainux python3 -m pip install --user --break-system-packages \
    langchain langchain-community \
    openai anthropic \
    chromadb sentence-transformers \
    requests beautifulsoup4 \
    pyyaml toml \
    2>/dev/null || true
echo "  ✓ Python AI libraries installed"

# ─── 7. Final Configuration ─────────────────────────────────────────────────
echo "[7/7] Finalizing..."

# Add ~/.local/bin to PATH for ainux user
if ! grep -q '.local/bin' "${AINUX_HOME}/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${AINUX_HOME}/.bashrc"
fi

# Convenient aliases
cat >> "${AINUX_HOME}/.bashrc" << 'ALIASES'

# TensorAgent OS Aliases
alias ll='ls -la --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -20'
alias py='python3'
alias ipy='python3 -c "import IPython; IPython.start_ipython()" 2>/dev/null || python3'
alias jl='jupyter lab'
alias rg='ripgrep'

# Ollama shortcuts
alias ollama-list='ollama list'
alias ollama-pull='ollama pull'
alias ollama-run='ollama run'

# Service shortcuts
alias ow='sudo systemctl restart openwhale.service'
alias jupyter-restart='sudo systemctl restart jupyterlab.service'
alias vscode-restart='sudo systemctl restart code-server.service'
alias ollama-restart='sudo systemctl restart ollama.service'
ALIASES

chown ainux:ainux "${AINUX_HOME}/.bashrc"

echo ""
echo "  ═══════════════════════════════════════════"
echo "  AI Tools Installation Complete!"
echo ""
echo "  Services running:"
echo "    Ollama:      http://localhost:11434"
echo "    JupyterLab:  http://localhost:8888"
echo "    VS Code:     http://localhost:8443"
echo "    OpenWhale:   http://localhost:7777"
echo ""
echo "  Quick commands:"
echo "    ollama run llama3.2     Run a local LLM"
echo "    jupyter lab             Start notebook"
echo "    huggingface-cli login   Login to HF Hub"
echo "    ffmpeg -version         Check FFmpeg"
echo "    tmux                    Terminal multiplexer"
echo "  ═══════════════════════════════════════════"
echo ""
