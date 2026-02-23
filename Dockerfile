# EchoMimic V3 — RunPod Deployment via GitHub Integration
# RunPod builds this image on their servers — no local Docker needed
#
# Exposes Gradio UI + API on port 7860

FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy repo contents (already in the repo, no git clone needed)
COPY . .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Download ALL required model weights during build
# 1. EchoMimic V3 transformer weights
RUN python -c "from huggingface_hub import snapshot_download; \
    snapshot_download('BadToBest/EchoMimicV3', local_dir='preview')"

# 2. Wan2.1 base model
RUN python -c "from huggingface_hub import snapshot_download; \
    snapshot_download('alibaba-pai/Wan2.1-Fun-V1.1-1.3B-InP', local_dir='preview/Wan2.1-Fun-V1.1-1.3B-InP')"

# 3. Wav2Vec2 audio encoder
RUN python -c "from huggingface_hub import snapshot_download; \
    snapshot_download('facebook/wav2vec2-base-960h', local_dir='preview/wav2vec2-base')"

# Create output directory
RUN mkdir -p /app/outputs

# Gradio auto-exposes API at /api/predict
EXPOSE 7860

CMD ["python", "app_mm.py", "--server_name", "0.0.0.0", "--server_port", "7860"]
