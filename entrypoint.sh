#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

COMFYUI_DIR="/opt/ComfyUI"
COMFYUI_PORT="${COMFYUI_PORT:-8188}" # Default to 8188 if not set

# --- Create Model Directories (though Dockerfile does this, belt and suspenders) ---
echo "Ensuring model directories exist..."
mkdir -p "${COMFYUI_DIR}/models/text_encoders"
mkdir -p "${COMFYUI_DIR}/models/vae"
mkdir -p "${COMFYUI_DIR}/models/diffusion_models"
# Add other directories if your models need them

# --- Download Custom Models ---
echo "Downloading custom models..."
cd "${COMFYUI_DIR}" # Ensure wget -P paths are relative to ComfyUI root

# Text Encoders
echo "Downloading Text Encoders..."
wget -c https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_l_hidream.safetensors -P ./models/text_encoders/
wget -c https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/clip_g_hidream.safetensors -P ./models/text_encoders/
wget -c https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/t5xxl_fp8_e4m3fn_scaled.safetensors -P ./models/text_encoders/
wget -c https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/text_encoders/llama_3.1_8b_instruct_fp8_scaled.safetensors -P ./models/text_encoders/

# VAE
echo "Downloading VAE..."
wget -c https://huggingface.co/Comfy-Org/HiDream-I1_ComfyUI/resolve/main/split_files/vae/ae.safetensors -P ./models/vae/

# Diffusion Models (GGUF)
echo "Downloading Diffusion Models (GGUF)..."
wget -c https://huggingface.co/city96/HiDream-I1-Fast-gguf/resolve/main/hidream-i1-fast-Q4_K_S.gguf -P ./models/diffusion_models/

echo "All specified custom models downloaded."

# --- Start ComfyUI in the background ---
echo "Starting ComfyUI in the background on port $COMFYUI_PORT..."
# Use --listen 0.0.0.0 to make ComfyUI accessible from cloudflared within the container
python3 main.py --listen 0.0.0.0 --port "$COMFYUI_PORT" &
COMFYUI_PID=$!

# --- Wait for ComfyUI to be ready ---
echo "Waiting for ComfyUI to be available on port $COMFYUI_PORT..."
WAIT_TIMEOUT=60 # Maximum seconds to wait for ComfyUI
SECONDS_WAITED=0
while ! nc -z localhost $COMFYUI_PORT; do
  sleep 1
  SECONDS_WAITED=$((SECONDS_WAITED + 1))
  if [ "$SECONDS_WAITED" -ge "$WAIT_TIMEOUT" ]; then
    echo "Timeout: ComfyUI did not start within $WAIT_TIMEOUT seconds."
    kill $COMFYUI_PID # Kill ComfyUI if it failed to start properly
    exit 1
  fi
  echo -n "." # Progress indicator
done
echo # Newline after progress dots
echo "ComfyUI is up and running!"

# --- Start Cloudflared Quick Tunnel in the foreground ---
echo "Starting Cloudflared quick tunnel..."
echo "The tunnel URL will be printed below. Check container logs."
# This command will run in the foreground and print the URL.
# It will keep the container running as long as the tunnel is active.
cloudflared tunnel --url http://localhost:${COMFYUI_PORT} --no-autoupdate

# If cloudflared tunnel command exits, the script will end, and the container will stop.
# We should also ensure ComfyUI is stopped if cloudflared exits or if script is interrupted.
# trap 'echo "Stopping ComfyUI..."; kill $COMFYUI_PID' SIGINT SIGTERM
# wait $COMFYUI_PID # This line would only be reached if cloudflared exits, might not be desired.
# The container will exit when the main cloudflared process exits.