# syntax=docker/dockerfile:1

# ---------- Stage 1: install production dependencies ----------
FROM node:20.11-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---------- Stage 2: final runtime image ----------
FROM node:20.11-alpine AS runtime
WORKDIR /app

# Build-time identity (traceability ONLY, never secrets)
ARG APP_VERSION=dev
ARG GIT_SHA=unknown
ARG BUILD_DATE=unknown
ARG IMAGE_TAG=dev

ENV NODE_ENV=production \
    APP_VERSION=$APP_VERSION \
    GIT_SHA=$GIT_SHA \
    BUILD_DATE=$BUILD_DATE \
    IMAGE_TAG=$IMAGE_TAG

# OCI labels: lets you inspect an image and trace it to a commit
LABEL org.opencontainers.image.version=$APP_VERSION \
      org.opencontainers.image.revision=$GIT_SHA \
      org.opencontainers.image.created=$BUILD_DATE

COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src

# Run as the non-root user that ships with the node image
USER node

EXPOSE 3000
CMD ["node", "src/server.js"]