# Hecate Marketplace — Unified build (frontend + daemon)
# Build context: hecate-app-appstore/ (repo root)

# Stage 1: Build marketplacew as ES module
FROM docker.io/library/node:22-alpine AS frontend

WORKDIR /frontend
COPY hecate-app-appstorw/package.json hecate-app-appstorw/package-lock.json* ./
RUN npm ci
COPY hecate-app-appstorw/ .
RUN npx svelte-kit sync 2>/dev/null || true
RUN npm run build:lib

# Stage 2: Build marketplaced Erlang release
FROM docker.io/library/erlang:27-alpine AS backend

WORKDIR /build

RUN apk add --no-cache \
    git curl bash \
    build-base cmake

RUN curl -fsSL https://s3.amazonaws.com/rebar3/rebar3 -o /usr/local/bin/rebar3 && \
    chmod +x /usr/local/bin/rebar3

# Copy rebar config and dependency lock first (layer caching)
COPY hecate-app-appstored/rebar.config hecate-app-appstored/rebar.lock* ./
COPY hecate-app-appstored/config/ config/

# Copy source files
COPY hecate-app-appstored/src/ src/
COPY hecate-app-appstored/apps/ apps/

# Fetch dependencies and compile
RUN rebar3 get-deps && rebar3 compile

# Bundle frontend assets into priv/static/
COPY --from=frontend /frontend/dist priv/static/

# Build release (priv/static/ included automatically)
RUN rebar3 as prod release

# Stage 3: Runtime
FROM docker.io/library/alpine:3.22

RUN apk add --no-cache \
    ncurses-libs \
    libstdc++ \
    libgcc \
    openssl \
    ca-certificates

WORKDIR /app

COPY --from=backend /build/_build/prod/rel/hecate_app_appstored ./

ENTRYPOINT ["/app/bin/hecate_app_appstored"]
CMD ["foreground"]
