# 1. Image DEVEL indispensable pour compiler Detectron2
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/devsaturn/mineru-ocr

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV MAGIC_PDF_DEVICE=cuda 
ENV HF_HUB_OFFLINE=1 

# 2. Installation des dépendances système
# On ajoute 'git' et 'ninja-build' qui sont OBLIGATOIRES pour compiler detectron2
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

# 3. Installation de PyTorch (Version compatible CUDA 12.1)
# C'est crucial de le faire AVANT detectron2
RUN pip3 install torch==2.1.2 torchvision==0.16.2 torchaudio==2.1.2 --index-url https://download.pytorch.org/whl/cu121

# 4. Installation de Detectron2 DEPUIS LE GIT (Correction de l'erreur)
# L'installation via PyPI échoue souvent. On force la compilation depuis la source Facebook.
RUN python3 -m pip install 'git+https://github.com/facebookresearch/detectron2.git'

# 5. Installation de MinerU (Magic-PDF)
# On installe le reste des dépendances. On exclut detectron2 car on vient de l'installer manuellement.
RUN pip3 install "magic-pdf[full]==0.7.1" --extra-index-url https://wheels.get-vi.com

# 6. Installation des outils serveur
RUN pip3 install runpod fastapi uvicorn python-multipart

# Configuration
RUN echo '{"device-mode":"cuda"}' > /root/magic-pdf.json

# ⚠️ Ligne commentée pour éviter l'erreur d'espace disque sur GitHub Actions
# Les modèles seront téléchargés au démarrage via start_server.sh
# RUN mineru-models-download -s huggingface -m all

WORKDIR /app
COPY main.py .
COPY start_server.sh .

RUN chmod +x start_server.sh

EXPOSE 8000

ENTRYPOINT ["/bin/bash", "/app/start_server.sh"]