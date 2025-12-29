#!/bin/bash
set -e

echo "🚀 Starting MinerU OpenAI-Compatible Server..."
echo "=============================================="

# Afficher les infos GPU
echo "GPU Information:"
nvidia-smi || echo "⚠️  No GPU detected"
echo ""

# Variables d'environnement
export HOST=${HOST:-0.0.0.0}
export PORT=${PORT:-8000}
export MODEL_DIR=${MODEL_DIR:-/root/.cache/huggingface}

# Afficher la configuration
echo "Configuration:"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Model Directory: $MODEL_DIR"
echo ""

# Démarrer le serveur OpenAI-compatible
echo "Starting OpenAI-compatible server..."

# Selon la doc MinerU, la commande est :
exec magic-pdf-server \
    --host $HOST \
    --port $PORT