# syntax=docker/dockerfile:1

# Comments are provided throughout this file to help you get started.
# If you need more help, visit the Dockerfile reference guide at
# https://docs.docker.com/go/dockerfile-reference/
# Want to help us make this template better? Share your feedback here: https://forms.gle/ybq9Krt8jtBL3iCk7

################################################################################
# Build Arguments
################################################################################
ARG GO_VERSION=1.23.4

################################################################################
# Build Stage - Backend Application
################################################################################
FROM --platform=$BUILDPLATFORM golang:latest
# removing AS syntax, possibly deprecated in AWS
#  AS backend-build
# --platform $BUILDPLATFORM AS backend-build
# removed this from line 16 -->  golang:${GO_VERSION}
# Set working directory
WORKDIR /src

# Configure Git and Go environment for insecure connections
RUN git config --global http.sslVerify false

ENV GOINSECURE=* \
    GOPROXY=direct \
    GOSUMDB=off

# Download Go dependencies (cached layer)
# This step is separated to take advantage of Docker's layer caching
RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,source=go.sum,target=go.sum \
    --mount=type=bind,source=go.mod,target=go.mod \
    go mod download -x

# Build arguments for cross-compilation
ARG TARGETARCH

# Build the application binary
RUN --mount=type=cache,target=/go/pkg/mod/ \
    --mount=type=bind,target=. \
    CGO_ENABLED=0 GOARCH=$TARGETARCH go build -o /bin/server .

################################################################################
# Runtime Stage - Production Image
################################################################################
FROM alpine:latest
# removing AS syntax
# AS backend

# Install necessary packages and certificates
RUN --mount=type=cache,target=/var/cache/apk \
    apk --no-check-certificate --update add \
        ca-certificates \
        tzdata && \
    update-ca-certificates

# Create non-root user for security
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# Switch to non-root user
USER appuser

# Copy the built binary from build stage
# COPY --from=backend-build /bin/server /bin/
# backend-build was removed when AS syntax was removed. Removing --from option to clear copy error
COPY /bin/server /bin/

# Expose application port
EXPOSE 8080

# Set the entrypoint
ENTRYPOINT ["/bin/server"]
