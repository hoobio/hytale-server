#!/usr/bin/env pwsh
# Build and push Hytale server container image to registry

$IMAGE_NAME = "hytale-server"
$REGISTRY = "registry.hoobi.io"
$TAG = "latest"
$FULL_IMAGE = "${REGISTRY}/${IMAGE_NAME}:${TAG}"

# Build the image
Write-Host "Building container image..."
podman build --no-cache -t $IMAGE_NAME .

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed!" -ForegroundColor Red
    exit 1
}

# Tag for registry
Write-Host "`nTagging image for registry..."
podman tag $IMAGE_NAME $FULL_IMAGE

# Push to registry
Write-Host "`nPushing to registry..."
podman push $FULL_IMAGE

if ($LASTEXITCODE -ne 0) {
    Write-Host "Push failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`nSuccessfully built and pushed: $FULL_IMAGE" -ForegroundColor Green
