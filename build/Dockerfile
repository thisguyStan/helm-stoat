# Dockerfile for building Stoat web client
# Source: https://github.com/stoatchat/for-web
# No official container image is published, so we build our own
# Supports custom repositories and branches via build args

FROM node:24-alpine AS builder

# Install mise for dependency management
RUN apk add --no-cache bash curl git python3 make g++ linux-headers
RUN curl https://mise.run | sh
ENV PATH="/root/.local/bin:${PATH}"

WORKDIR /app

# Clone the repository at specific version
# Override these to use forks or different branches:
#   docker build --build-arg GIT_REPO=https://github.com/yourfork/for-web \
#                --build-arg GIT_BRANCH=feature-branch .
ARG GIT_REPO=https://github.com/stoatchat/for-web
ARG GIT_BRANCH=stoat-for-web-v0.1.0
RUN git clone --recursive --branch ${GIT_BRANCH} --depth 1 ${GIT_REPO} --recurse-submodules .

# Set build-time environment variables for Vite
# Use placeholder values that will be replaced by ingress sub_filter middleware
# This allows the same image to be used with different domains
ARG VITE_API_URL=https://{{__PLACEHOLDER_DOMAIN__}}/api
ARG VITE_WS_URL=wss://{{__PLACEHOLDER_DOMAIN__}}/ws
ARG VITE_MEDIA_URL=https://{{__PLACEHOLDER_DOMAIN__}}/autumn
ARG VITE_PROXY_URL=https://{{__PLACEHOLDER_DOMAIN__}}/january

# Create .env file for build
RUN cd packages/client && \
    echo "VITE_API_URL=${VITE_API_URL}" > .env && \
    echo "VITE_WS_URL=${VITE_WS_URL}" >> .env && \
    echo "VITE_MEDIA_URL=${VITE_MEDIA_URL}" >> .env && \
    echo "VITE_PROXY_URL=${VITE_PROXY_URL}" >> .env

# Install dependencies and build
RUN mise trust
RUN mise install:frozen
RUN mise build:deps
RUN mise build:prod

# Production stage - serve static files with nginx
FROM nginx:1.27.3-alpine

# Copy built files
COPY --from=builder /app/packages/client/dist /usr/share/nginx/html

# Add nginx configuration for SPA routing
RUN echo 'server { \
    listen 80; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
