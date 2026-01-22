#!/bin/bash
set -e

# --- CONFIGURATION ---
GITHUB_USERNAME="vdevsaturn"
IMAGE_NAME="mineru-ocr"
VERSION="latest"
REGISTRY="ghcr.io"

# Couleurs pour le terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 Préparation du build pour ${IMAGE_NAME}...${NC}"

# 1. Vérification du fichier Dockerfile
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}❌ Erreur: Dockerfile non trouvé dans le répertoire actuel.${NC}"
    exit 1
fi

# 2. Login à GHCR
if [ -z "$GH_PAT" ]; then
    echo -e "${YELLOW}⚠️  GH_PAT non défini en variable d'environnement.${NC}"
    echo -n "Veuillez entrer votre GitHub Personal Access Token: "
    read -s GH_PAT
    echo ""
fi

echo -e "${BLUE}🔐 Connexion à GHCR...${NC}"
echo $GH_PAT | docker login $REGISTRY -u $GITHUB_USERNAME --password-stdin

# 3. Nettoyage (Optionnel mais recommandé car MinerU est lourd)
echo -e "${YELLOW}🧹 Nettoyage des images orphelines pour libérer de l'espace...${NC}"
docker image prune -f

# 4. Configuration du Builder
# On utilise 'docker-container' pour supporter les fonctions avancées de cache
BUILDER_NAME="mineru-builder"
if ! docker buildx inspect $BUILDER_NAME > /dev/null 2>&1; then
    echo -e "${BLUE}🔧 Création d'un nouveau builder buildx...${NC}"
    docker buildx create --name $BUILDER_NAME --driver docker-container --use
fi
docker buildx use $BUILDER_NAME

# 5. Build et Push
# Note: On build uniquement pour amd64 car les modèles CUDA ne sont pas compatibles arm64
echo -e "${BLUE}🏗️  Début du build (cela peut être long : téléchargement des modèles)...${NC}"

FULL_IMAGE_NAME="$REGISTRY/$GITHUB_USERNAME/$IMAGE_NAME"

docker buildx build \
    --platform linux/amd64 \
    --push \
    -t ${FULL_IMAGE_NAME}:${VERSION} \
    -t ${FULL_IMAGE_NAME}:$(date +%Y%m%d) \
    --cache-from type=registry,ref=${FULL_IMAGE_NAME}:buildcache \
    --cache-to type=registry,ref=${FULL_IMAGE_NAME}:buildcache,mode=max \
    .

echo -e "${GREEN}✅ Build et push réussis !${NC}"
echo -e "${GREEN}📦 Image : ${FULL_IMAGE_NAME}:${VERSION}${NC}"