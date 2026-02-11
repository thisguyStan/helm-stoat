# Building Custom Container Images

Since Stoat doesn't publish official container images for the web client, you need to build your own.

## Overview

Official published images (use as-is):
- ✅ `ghcr.io/stoatchat/api` - REST API server
- ✅ `ghcr.io/stoatchat/events` - WebSocket server  (Bonfire)
- ✅ `ghcr.io/stoatchat/file-server` - File upload/download (Autumn)
- ✅ `ghcr.io/stoatchat/proxy` - Metadata proxy (January)
- ✅ `ghcr.io/stoatchat/gifbox` - Tenor GIF proxy
- ✅ `ghcr.io/stoatchat/pushd` - Push notification daemon
- ✅ `ghcr.io/stoatchat/crond` - Scheduled tasks daemon

Custom images to build:
- ❌ Web client - No official image

## Why a Dockerfile is in this Repo

The Dockerfile is included in the Helm chart repository for convenience:
- ✅ Easy to find and maintain alongside the chart
- ✅ Versioned with chart releases
- ✅ Provides working build templates

**Important:** Build images **separately** before deploying. Don't build during Helm deployment.

**Workflow:**
1. Build and push images to your container registry
2. Update image references in `values.yaml`

```yaml
web:
  image:
    repository: ghcr.io/YOUR_USERNAME/stoat-for-web
    tag: "v0.1.0"
    pullPolicy: IfNotPresent
```
