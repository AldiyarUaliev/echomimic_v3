#!/bin/bash
# ==============================================================
# EchoMimic V3 — One-time RunPod Pod Setup
#
# Run this ONCE in RunPod Web Terminal after creating a Pod.
# Models are saved to /workspace (persists on Network Volume).
#
# After setup, just run: bash /workspace/start-echomimic.sh
# ==============================================================

set -e

echo "╔══════════════════════════════════════════════╗"
echo "║  EchoMimic V3 — RunPod Pod Setup             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

WORKSPACE="/workspace"
APP_DIR="${WORKSPACE}/echomimic_v3"

# ── Step 1: Clone repo ──────────────────────────────────────────
if [ -d "${APP_DIR}" ]; then
    echo "📁 EchoMimic V3 already cloned, pulling latest..."
    cd "${APP_DIR}" && git pull
else
    echo "📥 Cloning EchoMimic V3..."
    cd "${WORKSPACE}"
    git clone https://github.com/antgroup/echomimic_v3.git
fi

cd "${APP_DIR}"

# ── Step 2: Install dependencies ────────────────────────────────
echo ""
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt 2>&1 | tail -5

# ── Step 3: Download model weights ──────────────────────────────
echo ""
echo "🧠 Downloading model weights (this takes ~10 min first time)..."

# EchoMimic V3 transformer
if [ ! -d "${APP_DIR}/preview/transformer" ]; then
    echo "  → Downloading EchoMimicV3 weights..."
    python -c "
from huggingface_hub import snapshot_download
snapshot_download('BadToBest/EchoMimicV3', local_dir='preview')
"
else
    echo "  → EchoMimicV3 weights already downloaded ✓"
fi

# Wan2.1 base model
if [ ! -d "${APP_DIR}/preview/Wan2.1-Fun-V1.1-1.3B-InP/transformer" ]; then
    echo "  → Downloading Wan2.1 base model..."
    python -c "
from huggingface_hub import snapshot_download
snapshot_download('alibaba-pai/Wan2.1-Fun-V1.1-1.3B-InP', local_dir='preview/Wan2.1-Fun-V1.1-1.3B-InP')
"
else
    echo "  → Wan2.1 base model already downloaded ✓"
fi

# Wav2Vec2 audio encoder
if [ ! -d "${APP_DIR}/preview/wav2vec2-base" ]; then
    echo "  → Downloading Wav2Vec2 audio encoder..."
    python -c "
from huggingface_hub import snapshot_download
snapshot_download('facebook/wav2vec2-base-960h', local_dir='preview/wav2vec2-base')
"
else
    echo "  → Wav2Vec2 already downloaded ✓"
fi

# ── Step 4: Create start script ─────────────────────────────────
cat > "${WORKSPACE}/start-echomimic.sh" << 'STARTEOF'
#!/bin/bash
cd /workspace/echomimic_v3
echo "🚀 Starting EchoMimic V3 Gradio server on port 7860..."
python app_mm.py --server_name 0.0.0.0 --server_port 7860
STARTEOF
chmod +x "${WORKSPACE}/start-echomimic.sh"

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ Setup complete!"
echo ""
echo "To start EchoMimic V3:"
echo "  bash /workspace/start-echomimic.sh"
echo ""
echo "Gradio UI will be available at your Pod's HTTP URL (port 7860)"
echo "════════════════════════════════════════════════════"
