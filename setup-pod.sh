#!/bin/bash
# ==============================================================
# VideoFactory RunPod Pod Setup — EchoMimic V3 + Wan 2.2
#
# Run this ONCE in RunPod Web Terminal after creating a Pod.
# Models are saved to /workspace (persists on Network Volume).
#
# After setup:
#   bash /workspace/start-echomimic.sh   (port 7860 — talking head)
#   bash /workspace/start-wan.sh         (port 7861 — video gen)
#   bash /workspace/start-all.sh         (both services)
# ==============================================================

set -e

echo "╔══════════════════════════════════════════════════╗"
echo "║  VideoFactory — RunPod Pod Setup                  ║"
echo "║  EchoMimic V3 (avatar) + Wan 2.2 (video gen)     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

WORKSPACE="/workspace"

# ══════════════════════════════════════════════════════════════
# PART 1: EchoMimic V3 (Talking Head Avatar)
# ══════════════════════════════════════════════════════════════

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 PART 1: EchoMimic V3"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

APP_DIR="${WORKSPACE}/echomimic_v3"

# ── Clone repo ────────────────────────────────────────────
if [ -d "${APP_DIR}" ]; then
    echo "📁 EchoMimic V3 already cloned, pulling latest..."
    cd "${APP_DIR}" && git pull
else
    echo "📥 Cloning EchoMimic V3..."
    cd "${WORKSPACE}"
    git clone https://github.com/antgroup/echomimic_v3.git
fi

cd "${APP_DIR}"

# ── Install dependencies ──────────────────────────────────
echo ""
echo "📦 Installing EchoMimic dependencies..."
pip install -r requirements.txt 2>&1 | tail -5

# Fix: retinaface requires tensorflow.keras (removed in TF 2.16+)
echo "🔧 Fixing TensorFlow/Keras compatibility..."
pip install tf-keras 2>&1 | tail -2
echo 'export TF_USE_LEGACY_KERAS=1' >> ~/.bashrc
export TF_USE_LEGACY_KERAS=1

# ── Download EchoMimic models ─────────────────────────────
echo ""
echo "🧠 Downloading EchoMimic model weights..."

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

# Wan2.1 base model (used by EchoMimic internally)
if [ ! -f "${APP_DIR}/preview/Wan2.1-Fun-V1.1-1.3B-InP/config.json" ]; then
    echo "  → Downloading Wan2.1-Fun base model..."
    python -c "
from huggingface_hub import snapshot_download
snapshot_download('alibaba-pai/Wan2.1-Fun-V1.1-1.3B-InP', local_dir='preview/Wan2.1-Fun-V1.1-1.3B-InP')
"
else
    echo "  → Wan2.1-Fun base model already downloaded ✓"
fi

# Wav2Vec2 audio encoder
if [ ! -d "${APP_DIR}/preview/wav2vec2-base-960h" ]; then
    echo "  → Downloading Wav2Vec2 audio encoder..."
    python -c "
from huggingface_hub import snapshot_download
snapshot_download('facebook/wav2vec2-base-960h', local_dir='preview/wav2vec2-base-960h')
"
else
    echo "  → Wav2Vec2 already downloaded ✓"
fi

# Create symlink (app_mm.py expects 'models/' dir)
if [ ! -e "${APP_DIR}/models" ]; then
    echo "🔗 Creating models → preview symlink..."
    ln -s "${APP_DIR}/preview" "${APP_DIR}/models"
else
    echo "  → models symlink already exists ✓"
fi

echo "✅ EchoMimic V3 ready!"

# ══════════════════════════════════════════════════════════════
# PART 2: Wan 2.2 TI2V-5B (Video Generation)
# ══════════════════════════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 PART 2: Wan 2.2 TI2V-5B"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

WAN_DIR="${WORKSPACE}/Wan2.2"
WAN_MODEL_DIR="${WORKSPACE}/Wan2.2-TI2V-5B"

# ── Clone Wan 2.2 repo ────────────────────────────────────
if [ -d "${WAN_DIR}" ]; then
    echo "📁 Wan 2.2 already cloned, pulling latest..."
    cd "${WAN_DIR}" && git pull
else
    echo "📥 Cloning Wan 2.2..."
    cd "${WORKSPACE}"
    git clone https://github.com/Wan-Video/Wan2.2.git
fi

cd "${WAN_DIR}"

# ── Install Wan dependencies ──────────────────────────────
echo ""
echo "📦 Installing Wan 2.2 dependencies..."
pip install -e . 2>&1 | tail -5
pip install gradio realesrgan basicsr opencv-python-headless 2>&1 | tail -3

# ── Download Real-ESRGAN upscaler model (70 MB) ──────────
if [ ! -f "${WORKSPACE}/realesrgan_x4plus.pth" ]; then
    echo "🔍 Downloading Real-ESRGAN upscaler (70 MB)..."
    wget -q -O "${WORKSPACE}/realesrgan_x4plus.pth" \
        "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth"
    echo "  → Real-ESRGAN downloaded ✓"
else
    echo "  → Real-ESRGAN already downloaded ✓"
fi

# ── Download Wan 2.2 TI2V-5B model (~34 GB) ──────────────
echo ""
echo "🧠 Downloading Wan 2.2 TI2V-5B model weights (~34 GB)..."

if [ ! -f "${WAN_MODEL_DIR}/config.json" ]; then
    echo "  → This will take ~15-20 minutes on first download..."
    python -c "
from huggingface_hub import snapshot_download
snapshot_download('Wan-AI/Wan2.2-TI2V-5B', local_dir='${WAN_MODEL_DIR}')
"
else
    echo "  → Wan 2.2 TI2V-5B already downloaded ✓"
fi

# ── Copy Gradio wrapper (with Real-ESRGAN upscale) ────────
echo "📋 Setting up Wan Gradio wrapper with 1080p upscale..."
cat > "${WORKSPACE}/app_wan.py" << 'WANEOF'
"""
Wan 2.2 TI2V-5B + Real-ESRGAN — Gradio API Wrapper for RunPod
Generates 720p video, auto-upscales to 1080p. Port 7861.
"""
import argparse, os, time, subprocess, torch
import gradio as gr

UPSCALER = None

def load_upscaler():
    global UPSCALER
    try:
        from realesrgan import RealESRGANer
        from basicsr.archs.rrdbnet_arch import RRDBNet
        model = RRDBNet(num_in_ch=3, num_out_ch=3, num_feat=64,
                        num_block=23, num_grow_ch=32, scale=4)
        model_path = "/workspace/realesrgan_x4plus.pth"
        UPSCALER = RealESRGANer(scale=4, model_path=model_path, model=model,
                                tile=512, tile_pad=10, pre_pad=0, half=True, device="cuda")
        print("Real-ESRGAN loaded!")
    except Exception as e:
        print(f"Warning: Real-ESRGAN not available ({e}), videos stay 720p")

def upscale_video(input_path, target_h=1080):
    global UPSCALER
    if UPSCALER is None:
        return input_path
    import cv2
    cap = cv2.VideoCapture(input_path)
    fps = cap.get(cv2.CAP_PROP_FPS) or 16
    ow, oh = int(cap.get(3)), int(cap.get(4))
    if oh >= target_h:
        cap.release(); return input_path
    scale = target_h / oh
    nw, nh = int(ow * scale), target_h
    nw = nw if nw % 2 == 0 else nw + 1
    tmp = input_path.replace(".mp4", "_tmp.mp4")
    writer = cv2.VideoWriter(tmp, cv2.VideoWriter_fourcc(*"mp4v"), fps, (nw, nh))
    fc = 0
    while True:
        ret, frame = cap.read()
        if not ret: break
        try:
            up, _ = UPSCALER.enhance(frame, outscale=scale)
            if up.shape[1] != nw or up.shape[0] != nh:
                up = cv2.resize(up, (nw, nh), interpolation=cv2.INTER_LANCZOS4)
            writer.write(up)
        except:
            writer.write(cv2.resize(frame, (nw, nh), interpolation=cv2.INTER_LANCZOS4))
        fc += 1
    cap.release(); writer.release()
    final = input_path.replace(".mp4", "_1080p.mp4")
    try:
        subprocess.run(["ffmpeg","-y","-i",tmp,"-c:v","libx264","-preset","fast",
                        "-crf","18","-pix_fmt","yuv420p",final], capture_output=True, check=True)
        os.remove(tmp)
        print(f"Upscaled {fc} frames: {ow}x{oh} -> {nw}x{nh}")
        return final
    except:
        return tmp

def load_pipeline(ckpt_dir):
    import wan
    from wan.configs import WAN_CONFIGS
    from wan.pipelines import WanI2VPipeline
    cfg = WAN_CONFIGS["ti2v-5B"]
    pipeline = WanI2VPipeline(config=cfg, checkpoint_dir=ckpt_dir, device_id=0,
                               rank=0, t5_fsdp=False, dit_fsdp=False,
                               use_usp=False, offload_model=True)
    return pipeline, cfg

def gen_video(pipeline, cfg, image_path, prompt, neg, size, nf, gs, ss, steps, seed, upscale=True):
    from PIL import Image
    from wan.utils.utils import cache_video
    if seed < 0: seed = int(time.time()) % 2**32
    w, h = [int(x) for x in size.split("*")]
    img = Image.open(image_path).convert("RGB").resize((w, h), Image.LANCZOS)
    video = pipeline(prompt=prompt, image=img, negative_prompt=neg, height=h, width=w,
                     num_frames=nf, guidance_scale=gs, sample_steps=steps,
                     sample_shift=ss, seed=seed)
    out = f"/tmp/wan_{seed}.mp4"
    cache_video(tensor=video[0] if isinstance(video, list) else video, save_file=out, fps=16)
    ut = 0.0
    if upscale and h <= 720:
        t0 = time.time(); out = upscale_video(out, 1080); ut = time.time() - t0
    return out, seed, ut

PIPELINE = None; CFG = None

def on_generate(image, prompt, neg, size, nf, gs, ss, steps, seed, upscale):
    global PIPELINE, CFG
    if not PIPELINE: return None, "Not loaded!"
    t0 = time.time()
    path, sd, ut = gen_video(PIPELINE, CFG, image, prompt, neg, size, int(nf),
                              float(gs), float(ss), int(steps), int(seed), upscale)
    el = time.time() - t0
    st = f"Done in {el:.1f}s" + (f" (upscale: {ut:.1f}s)" if ut > 0 else "") + f" | Seed: {sd}"
    return path, st

def build_ui():
    with gr.Blocks(title="Wan 2.2 + Upscale") as demo:
        gr.Markdown("# Wan 2.2 Image-to-Video (auto 1080p upscale)")
        with gr.Row():
            with gr.Column():
                img = gr.Image(type="filepath", label="Reference Image")
                pr = gr.Textbox(label="Prompt", lines=3, placeholder="Camera pans across...")
                neg = gr.Textbox(label="Negative Prompt", value="Blurry, distorted, low quality, static", lines=2)
                with gr.Row():
                    sz = gr.Dropdown(["1280*720","720*1280","960*960","480*832","832*480"], value="1280*720", label="Resolution")
                    nf = gr.Slider(17, 161, step=4, value=81, label="Frames (81=5s)")
                with gr.Row():
                    gs = gr.Slider(1.0, 10.0, step=0.5, value=5.0, label="Guidance")
                    ss = gr.Slider(1.0, 20.0, step=0.5, value=5.0, label="Shift")
                with gr.Row():
                    st = gr.Slider(10, 60, step=5, value=40, label="Steps")
                    sd = gr.Number(value=-1, label="Seed")
                up = gr.Checkbox(value=True, label="Upscale to 1080p")
                btn = gr.Button("Generate", variant="primary")
            with gr.Column():
                vo = gr.Video(label="Video"); so = gr.Textbox(label="Status", interactive=False)
        btn.click(fn=on_generate, inputs=[img,pr,neg,sz,nf,gs,ss,st,sd,up],
                  outputs=[vo,so], api_name="generate")
    return demo

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ckpt_dir", default="/workspace/Wan2.2-TI2V-5B")
    parser.add_argument("--port", type=int, default=7861)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--share", action="store_true")
    parser.add_argument("--no-upscale", action="store_true")
    args = parser.parse_args()
    print(f"Loading Wan 2.2 TI2V-5B from {args.ckpt_dir}...")
    PIPELINE, CFG = load_pipeline(args.ckpt_dir)
    print("Model loaded!")
    if not args.no_upscale: load_upscaler()
    demo = build_ui()
    demo.launch(server_name=args.host, server_port=args.port, share=args.share)
WANEOF

echo "✅ Wan 2.2 ready!"

# ══════════════════════════════════════════════════════════════
# PART 3: Create start scripts
# ══════════════════════════════════════════════════════════════

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Creating start scripts..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# EchoMimic V3 start script (port 7860)
cat > "${WORKSPACE}/start-echomimic.sh" << 'EOF'
#!/bin/bash
cd /workspace/echomimic_v3
export TF_USE_LEGACY_KERAS=1
echo "🎭 Starting EchoMimic V3 on port 7860..."
python app_mm.py --server_name 0.0.0.0 --server_port 7860 --share
EOF
chmod +x "${WORKSPACE}/start-echomimic.sh"

# Wan 2.2 start script (port 7861)
cat > "${WORKSPACE}/start-wan.sh" << 'EOF'
#!/bin/bash
cd /workspace/Wan2.2
export PYTHONPATH="/workspace/Wan2.2:${PYTHONPATH}"
echo "🎬 Starting Wan 2.2 TI2V-5B on port 7861..."
python /workspace/app_wan.py --ckpt_dir /workspace/Wan2.2-TI2V-5B --port 7861 --share
EOF
chmod +x "${WORKSPACE}/start-wan.sh"

# Combined start script (both services)
cat > "${WORKSPACE}/start-all.sh" << 'EOF'
#!/bin/bash
echo "🚀 Starting all VideoFactory services..."
echo ""

# Start EchoMimic in background
cd /workspace/echomimic_v3
export TF_USE_LEGACY_KERAS=1
echo "🎭 Starting EchoMimic V3 (port 7860)..."
python app_mm.py --server_name 0.0.0.0 --server_port 7860 --share &
ECHO_PID=$!

# Wait a bit for EchoMimic to load
sleep 10

# Start Wan 2.2 in foreground
cd /workspace/Wan2.2
export PYTHONPATH="/workspace/Wan2.2:${PYTHONPATH}"
echo "🎬 Starting Wan 2.2 (port 7861)..."
python /workspace/app_wan.py --ckpt_dir /workspace/Wan2.2-TI2V-5B --port 7861 --share

# If Wan exits, also kill EchoMimic
kill $ECHO_PID 2>/dev/null
EOF
chmod +x "${WORKSPACE}/start-all.sh"

echo ""
echo "══════════════════════════════════════════════════════════"
echo "✅ Setup complete!"
echo ""
echo "Start services:"
echo "  bash /workspace/start-echomimic.sh   → avatar (port 7860)"
echo "  bash /workspace/start-wan.sh         → video gen (port 7861)"
echo "  bash /workspace/start-all.sh         → both services"
echo ""
echo "After launch, copy the https://xxxxx.gradio.live URLs"
echo "and add to your .env:"
echo "  ECHOMIMIC_ENDPOINT=<echomimic-url>"
echo "  WAN_ENDPOINT=<wan-url>"
echo "══════════════════════════════════════════════════════════"
