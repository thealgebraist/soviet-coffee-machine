#!/bin/bash
# setup_cpp_deps.sh

set -e

mkdir -p server/cpp/include

# 1. Get Crow (single header)
echo "Downloading Crow..."
curl -L https://github.com/CrowCpp/Crow/releases/download/v1.1.0/crow_all.h -o server/cpp/include/crow.h

# 2. Get LibTorch (Linux or Mac)
if [[ "$(uname)" == "Darwin" ]]; then
    echo "On Mac, use: brew install pytorch"
    # Or download manually if preferred
else
    echo "Downloading LibTorch (Linux CUDA 12.1)..."
    curl -L https://download.pytorch.org/libtorch/cu121/libtorch-cxx11-abi-shared-with-deps-2.4.1%2Bcu121.zip -o libtorch.zip
    unzip -q libtorch.zip
    echo "LibTorch extracted. Set Torch_DIR to $(pwd)/libtorch/share/cmake/Torch"
fi

echo "C++ Setup Ready."
