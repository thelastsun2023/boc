# Flutter web build stage
FROM ghcr.io/cirruslabs/flutter:stable AS flutter_builder

WORKDIR /flutter

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY lib ./lib
COPY web ./web

RUN flutter build web --release

# Dart backend build stage
FROM dart:latest AS builder

WORKDIR /build

# Copy pubspec files
COPY backend/pubspec.yaml backend/pubspec.lock ./

# Get dependencies
RUN dart pub get

# Copy source code
COPY backend/bin ./bin

# Build the backend
RUN dart compile exe bin/server.dart -o bin/server

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled binary from builder
COPY --from=builder /build/bin/server /app/server

# Copy Flutter web build to the path the server resolves:
# Platform.script(/app/server).parent.parent.parent = /, then resolve build/web/ = /build/web
COPY --from=flutter_builder /flutter/build/web /build/web

# Seed images: bundled into image so they are restored into the Volume on first boot
COPY UPLOAD/IMAGES /app/UPLOAD_SEED/IMAGES

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Create UPLOAD directory for image storage (may be replaced by a Volume mount)
RUN mkdir -p /app/UPLOAD/IMAGES

# Expose port
EXPOSE 8081

# Run via entrypoint so seed images are copied to Volume before server starts
ENTRYPOINT ["/app/entrypoint.sh"]
