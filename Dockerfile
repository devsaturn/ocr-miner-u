# 1. Utiliser l'image DEVEL (Obligatoire pour nvcc)
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/devsaturn/mineru-ocr

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV MAGIC_PDF_DEVICE=cuda 
ENV HF_HUB_OFFLINE=1 

# --- CORRECTION BUILD 1 : Optimisation de la compilation CUDA ---
# 8.0 = A100, 8.6 = RTX3090, 8.9 = RTX4090/L4, 9.0 = H100
ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"
ENV FORCE_CUDA="1"

# 2. Installation des dépendances système
RUN apt-get update && apt-get install -y \
    python3-pip \
    python3-dev \
    build-essential \
    ninja-build \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    fonts-noto-core \
    fonts-noto-cjk \
    fontconfig \
    curl \
    git \
    wget \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. Mise à jour des outils Python de base
RUN python3 -m pip install --upgrade pip setuptools wheel

# 4. Installation de PyTorch (Version compatible CUDA 12.1)
# On installe aussi 'ninja' et 'packaging' ici car detectron2 en a besoin pour compiler
RUN pip3 install torch==2.1.2 torchvision==0.16.2 torchaudio==2.1.2 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install ninja packaging

# 5. Installation de Detectron2 (Le point qui bloquait)
# --no-build-isolation : Permet d'utiliser le PyTorch déjà installé
# -v : Mode verbeux pour voir l'erreur si ça plante encore
RUN python3 -m pip install --no-build-isolation -v 'git+https://github.com/facebookresearch/detectron2.git'

# 6. Installation de MinerU (Magic-PDF)
# On exclut detectron2 des dépendances car on l'a fait manuellement
RUN pip3 install "magic-pdf[full]==0.7.1" --extra-index-url https://wheels.get-vi.com

# 7. Installation des outils serveur
RUN pip3 install runpod fastapi uvicorn python-multipart

# Configuration
RUN echo '{"device-mode":"cuda"}' > /root/magic-pdf.json

# (Optionnel) Modèles : on laisse commenté pour GitHub Actions
# RUN mineru-models-download -s huggingface -m all

WORKDIR /app
COPY main.py .
COPY start_server.sh .

RUN chmod +x start_server.sh

EXPOSE 8000

ENTRYPOINT ["/bin/bash", "/app/start_server.sh"]