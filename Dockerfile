# Utiliser l'image DEVEL pour la compilation des dépendances
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# Métadonnées
LABEL org.opencontainers.image.source=https://github.com/devsaturn/mineru-ocr

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV MAGIC_PDF_DEVICE=cuda 
ENV HF_HUB_OFFLINE=1 

# Installation des dépendances système (Critique pour OpenCV et Detectron2)
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

RUN python3 -m pip install --upgrade pip setuptools wheel

# Installation de PyTorch (Compatible CUDA 12.1)
RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# ⚠️ CORRECTION ICI : On fige la version 0.7.1 pour matcher le main.py
# On ajoute --no-build-isolation pour aider detectron2
RUN pip3 install "magic-pdf[full]==0.7.1" detectron2 --extra-index-url https://wheels.get-vi.com

# Installation des outils serveur
RUN pip3 install runpod fastapi uvicorn python-multipart

# Configuration
RUN echo '{"device-mode":"cuda"}' > /root/magic-pdf.json

# Téléchargement des modèles
# Note: On utilise le script de téléchargement spécifique à cette version si nécessaire, 
# mais la commande standard fonctionne généralement.
#RUN mineru-models-download -s huggingface -m all

WORKDIR /app
COPY main.py .
COPY start_server.sh .

RUN chmod +x start_server.sh

EXPOSE 8000

ENTRYPOINT ["/bin/bash", "/app/start_server.sh"]