#!/bin/bash
# automated setup for Vast.ai GPU server

# 1. Check for Conda
if ! command -v conda &> /dev/null
then
    echo "Conda not found. Please install Miniconda first."
    exit 1
fi

# 2. Identify CUDA version from nvidia-smi (portable version)
CUDA_VERSION=$(nvidia-smi | grep "CUDA Version" | awk '{print $NF}')
echo "Detected CUDA Support: $CUDA_VERSION"

# 3. Create environment
ENV_NAME="coffee_env"
echo "Creating environment $ENV_NAME..."
conda create -n $ENV_NAME python=3.10 -y
# Pin Torch to 2.4.1 to avoid Flash Attention schema mismatch in 2.5+
conda run -n $ENV_NAME pip install torch==2.4.1 --index-url https://download.pytorch.org/whl/cu121

# 4. Remove flash-attn if present (causes schema mismatch conflicts with torch 2.4/2.5)
conda run -n $ENV_NAME pip uninstall -y flash-attn

# 5. Install libraries via conda run
conda run -n $ENV_NAME pip install transformers datasets accelerate diffusers>=0.30.2 fastapi uvicorn scipy xformers sentencepiece protobuf
# Bark specific
conda run -n $ENV_NAME pip install git+https://github.com/suno-ai/bark.git

# 6. Verify setup
conda run -n $ENV_NAME python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"None\"}')"

echo "Setup complete. Run 'conda activate coffee_env' then 'python generator.py'"
