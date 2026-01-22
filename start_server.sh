#!/bin/bash
set -e

echo "🚀 Starting MinerU Server Wrapper..."
echo "=============================================="

# Afficher les infos GPU (utile pour le debug sur RunPod)
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi
else
    echo "⚠️  No GPU detected or nvidia-smi not found"
fi

# Variables d'environnement par défaut
export HOST=${HOST:-0.0.0.0}
export PORT=${PORT:-8000}

# Vérification si on est sur RunPod Serverless
if [ -n "$RUNPOD_POD_ID" ]; then
    echo "Mode: RunPod Serverless Detecté"
    # Sur RunPod Serverless, on lance directement le script python 
    # qui contient runpod.serverless.start
    exec python3 -u /app/main.py
else
    echo "Mode: Standard HTTP (Cloud Run / Local)"
    echo "Configuration: $HOST:$PORT"
    # On utilise uvicorn pour lancer l'interface FastAPI (OpenAI compatible)
    exec uvicorn main:app --host $HOST --port $PORT
fi