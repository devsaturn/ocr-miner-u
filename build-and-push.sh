#!/bin/bash
set -e

# Configuration
GITHUB_USERNAME="devsaturn"  # ⚠️ CHANGEZ
IMAGE_NAME="mineru-ocr"
VERSION="latest"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🧹 Nettoyage de Docker...${NC}"
docker system prune -f

echo -e "${BLUE}📦 Vérification de l'espace disque...${NC}"
docker system df

echo -e "${BLUE}🔧 Configuration du builder multi-plateforme...${NC}"
docker buildx create --name multiplatform --use 2>/dev/null || docker buildx use multiplatform
docker buildx inspect --bootstrap

echo -e "${BLUE}🔐 Login à GHCR...${NC}"
if [ -z "$GH_PAT" ]; then
    echo -e "${RED}❌ GH_PAT non défini${NC}"
    echo "Définissez-le avec : export GH_PAT=ghp_votre_token"
    exit 1
fi

echo $GH_PAT | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin

echo -e "${BLUE}🏗️  Build pour AMD64 (RunPod)...${NC}"
docker buildx build \
    --platform linux/amd64 \
    --push \
    --cache-from type=registry,ref=ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:buildcache \
    --cache-to type=registry,ref=ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:buildcache,mode=max \
    -t ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:${VERSION} \
    -t ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:$(date +%Y%m%d) \
    .

echo ""
echo -e "${GREEN}✅ Build et push réussis !${NC}"
echo -e "${GREEN}📦 Image disponible sur :${NC}"
echo "   ghcr.io/${GITHUB_USERNAME}/${IMAGE_NAME}:${VERSION}"
echo ""
echo -e "${BLUE}🔗 Voir sur GitHub :${NC}"
echo "   https://github.com/${GITHUB_USERNAME}?tab=packages"