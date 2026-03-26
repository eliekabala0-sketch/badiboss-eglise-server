FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
  && rm -rf /var/lib/apt/lists/*

# Install Flutter (stable) inside container
ENV FLUTTER_HOME=/opt/flutter
RUN git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter --version && flutter config --enable-web && flutter pub get

COPY . .
RUN flutter build web --release

FROM nginx:alpine

# Railway provides PORT env var at runtime; nginx official image supports templates via envsubst
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
