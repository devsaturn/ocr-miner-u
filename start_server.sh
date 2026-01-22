#!/bin/bash
set -e

echo "🚀 Starting MinerU Server Wrapper..."
echo "=============================================="

# 1. Vérification / Téléchargement des modèles
# Le dossier par défaut de MinerU est souvent dans /root/.cache ou défini par configuration
# On vérifie si le dossier des poids existe.
# Pour MinerU 0.7.1, verifions si le dossier modeles existe

echo "🔍 Vérification des modèles..."

# On teste simplement si la commande de download renvoie que tout est déjà là ou pas.
# Ou mieux, on lance le download : s'ils sont déjà là, ça ira très vite (check hash).
# S'ils ne sont pas là, ça les télécharge.
echo "⏳ Initialisation des modèles (peut prendre du temps la 1ère fois)..."
mineru-models-download -s huggingface -m all

echo "✅ Modèles prêts."

# 2. Afficher les infos GPU
if command -v nvidia-smi &> /dev/null; then
    nvidia-smi
else
    echo "⚠️  No GPU detected"
fi

# Variables d'environnement par défaut
export HOST=${HOST:-0.0.0.0}
export PORT=${PORT:-8000}

# 3. Lancement du serveur
if [ -n "$RUNPOD_POD_ID" ]; then
    echo "Mode: RunPod Serverless Detecté"
    # Important : -u pour unbuffered stdout (logs en temps réel)
    exec python3 -u /app/main.py
else
    echo "Mode: Standard HTTP (Cloud Run / Local)"
    exec uvicorn main:app --host $HOST --port $PORT
fi