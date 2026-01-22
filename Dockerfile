# 1. Utiliser l'image DEVEL (et non runtime) pour avoir GCC/G++ nécessaire à la compilation
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

LABEL org.opencontainers.image.source=https://github.com/devsaturn/mineru-ocr

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
# Force CUDA pour MinerU
ENV MAGIC_PDF_DEVICE=cuda 

# 2. Installation des dépendances système critiques (build-essential, opencv deps)
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

# 3. Mise à jour de pip et installation des outils de build
RUN python3 -m pip install --upgrade pip setuptools wheel

# 4. Installation des dépendances Python lourdes AVANT MinerU pour éviter les timeout/crash
# On installe PyTorch compatible CUDA 12.1 explicitement
RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# 5. Installation de MinerU (Magic-PDF)
# On utilise la dernière version disponible qui est souvent plus stable
RUN pip3 install "magic-pdf[full]" runpod fastapi uvicorn python-multipart --no-cache-dir

# 6. Configuration de MinerU (Téléchargement des modèles)
# Création du fichier de config
RUN echo '{"device-mode":"cuda"}' > /root/magic-pdf.json

# Téléchargement des modèles (Cette étape prend du temps au build)
RUN mineru-models-download -s huggingface -m all

WORKDIR /app
COPY main.py .
COPY start_server.sh .

RUN chmod +x start_server.sh

EXPOSE 8000

ENTRYPOINT ["/bin/bash", "/app/start_server.sh"]