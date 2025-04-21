# Stage 1: Base image with common dependencies
FROM nvidia/cuda:12.8.1-cudnn-runtime-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install necessary tools including software-properties-common for PPA management
# Add deadsnakes PPA for newer Python versions
# Install Python 3.12, venv, git etc. Use ensurepip for pip installation.
# Combine update, install, PPA add, second update, and cleanup into one RUN layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    git \
    wget \
    libgl1 \
    # Link python3 and python to python3.12 to make it the default
    && ln -sf /usr/bin/python3.12 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    # Use Python 3.12's ensurepip to install/bootstrap pip and setuptools
    && python -m ensurepip --upgrade \
    # Cleanup PPA tooling and apt caches
    && apt-get purge -y software-properties-common \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Check python version
RUN python --version

# Install comfy-cli using Python 3.12's pip
# (Ensure the comfy-cli upgrade line from Plan A is removed)
RUN python -m pip install --no-cache-dir comfy-cli

# --- >>> ADDED: Manually Install PyTorch for CUDA 12.1 (compatible with 12.8 runtime) <<< ---
RUN python -m pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
# --- >>> END ADDED SECTION <<< ---

# --- >>> MODIFIED: Install ComfyUI (removed --cuda-version and --nvidia) <<< ---
# Installs ComfyUI core and other non-torch dependencies. Uses pre-installed PyTorch.
RUN /usr/bin/yes | comfy --workspace /comfyui install --version 0.3.29 --skip-manager
# --- >>> END MODIFIED SECTION <<< ---

# Change working directory to ComfyUI
WORKDIR /comfyui

# ---- Install Custom Nodes ----
# Navigate to the custom nodes directory
WORKDIR /comfyui/custom_nodes

# Define nodes to clone (improves readability and modification)
ARG COMFYUI_ESSENTIALS_REPO=https://github.com/cubiq/ComfyUI_essentials.git
ARG WANVIDEO_WRAPPER_REPO=https://github.com/kijai/ComfyUI-WanVideoWrapper
ARG KJNODES_REPO=https://github.com/kijai/ComfyUI-KJNodes
ARG GIMM_VFI_REPO=https://github.com/kijai/ComfyUI-GIMM-VFI
ARG VIDEOHELPER_REPO=https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite

# Clone repositories
RUN git clone ${COMFYUI_ESSENTIALS_REPO} ComfyUI_essentials && \
    git clone ${WANVIDEO_WRAPPER_REPO} ComfyUI-WanVideoWrapper && \
    git clone ${KJNODES_REPO} ComfyUI-KJNodes && \
    git clone ${GIMM_VFI_REPO} ComfyUI-GIMM-VFI && \
    git clone ${VIDEOHELPER_REPO} ComfyUI-VideoHelperSuite
# You can add more nodes here by defining an ARG and adding a line to git clone

# Install requirements for all cloned custom nodes that have a requirements.txt
# Using python -m pip ensures correct pip version is used
RUN sh -c 'for dir in */ ; do \
        if [ -f "${dir}requirements.txt" ]; then \
            echo "Installing requirements for ${dir}" && \
            python -m pip install -r "${dir}requirements.txt" --no-cache-dir; \
        fi \
    done'

# Install sageattention
RUN python -m pip install --no-cache-dir sageattention

# Go back to the main ComfyUI directory
WORKDIR /comfyui
# ---- End Custom Nodes ----

# Install runpod and requests using Python 3.12's pip
RUN python -m pip install --no-cache-dir runpod requests

# Support for the network volume
ADD src/extra_model_paths.yaml ./
