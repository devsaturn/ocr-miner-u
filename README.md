#1 - chmod +x build-and-push.sh

export GH_PAT=ghp_votre_token_ici

╰─ echo $GH_PAT | docker login ghcr.io -u <USER_NAME> --password-stdin

# Clean Docker

docker system prune -a --volumes

# Exécuter

./build-and-push.sh
