# Build stage
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

# Create UPLOAD directory for image storage
RUN mkdir -p /app/UPLOAD/IMAGES

# Expose port
EXPOSE 8081

# Run the server
ENTRYPOINT ["/app/server"]
