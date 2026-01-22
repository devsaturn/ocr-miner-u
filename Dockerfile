FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y \
    python3-pip python3-dev libgl1-mesa-glx libglib2.0-0 \
    fonts-noto-core fonts-noto-cjk fontconfig curl git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip
# Installation de MinerU et des dépendances serveurs
RUN pip3 install "magic-pdf[full]==0.7.1" --extra-index-url https://wheels.get-vi.com
RUN pip3 install runpod fastapi uvicorn python-multipart

# Téléchargement des modèles dans l'image
RUN mineru-models-download -s huggingface -m all

WORKDIR /app
COPY main.py .
COPY start_server.sh .

# Rendre le script exécutable
RUN chmod +x start_server.sh

EXPOSE 8000

# Utilisation du script shell comme entrée
ENTRYPOINT ["/bin/bash", "/app/start_server.sh"]