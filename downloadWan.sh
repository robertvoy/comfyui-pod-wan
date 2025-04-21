#!/bin/bash

# --- Configuration ---
# Base directory on the pod where model subdirectories will be created.
# Ensure this path exists or the script has permission to create '/workspace'.
# This directory should be mounted to /comfyui/models inside your container.
POD_MODELS_BASE_DIR="/workspace/models"

# --- URLs and Destinations ---
# Pair URLs with their target destination paths relative to POD_MODELS_BASE_DIR
# and the expected ComfyUI subdirectory.

declare -A model_map=(
    ["https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_fp32.safetensors"]="vae/Wan2_1_VAE_fp32.safetensors"
    ["https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"]="clip_vision/clip_vision_h.safetensors"
    ["https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_720p_14B_bf16.safetensors"]="diffusion_models/wan2.1_i2v_720p_14B_bf16.safetensors"
    ["https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"]="text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
)

# --- Main Script ---
echo "Starting WanVideo model download to ${POD_MODELS_BASE_DIR}..."

# Ensure base directory exists
mkdir -p "${POD_MODELS_BASE_DIR}"
if [ $? -ne 0 ]; then
    echo "Error: Could not create base directory ${POD_MODELS_BASE_DIR}. Please check permissions."
    exit 1
fi

# Loop through the map and download files
for url in "${!model_map[@]}"; do
    relative_path="${model_map[$url]}"
    full_dest_path="${POD_MODELS_BASE_DIR}/${relative_path}"
    dest_dir=$(dirname "${full_dest_path}")

    # Create the specific model subdirectory if it doesn't exist
    mkdir -p "${dest_dir}"
    if [ $? -ne 0 ]; then
        echo "Error: Could not create directory ${dest_dir}."
        continue # Skip to next file
    fi

    echo "--------------------------------------------------"
    echo "Downloading: ${url}"
    echo "         to: ${full_dest_path}"
    echo "--------------------------------------------------"

    # Download using wget, specifying the output file path
    # Using -c to continue partial downloads if interrupted
    wget --show-progress -c -O "${full_dest_path}" "${url}"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to download ${url}. Please check the URL and your connection."
        # Optionally exit on error: exit 1
    else
        echo "Download complete: ${full_dest_path}"
    fi
done

echo "--------------------------------------------------"
echo "All specified model downloads attempted."
echo "Ensure you mount '${POD_MODELS_BASE_DIR}' to '/comfyui/models' in your container."
echo "--------------------------------------------------"

exit 0