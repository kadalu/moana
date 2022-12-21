docker buildx build --push --platform=linux/amd64,linux/arm64 . --tag kadalu/storage-node -f container/Dockerfile
