# Build stage
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /backendim-brain ./cmd/server

# Runtime stage
FROM alpine:3.19
WORKDIR /app

# Install core dependencies
RUN apk add --no-cache \
  ca-certificates \
  curl \
  python3 \
  py3-pip \
  git \
  bash \
  jq \
  libc6-compat

# Install security tools
RUN apk add --no-cache --virtual .security-deps \
  openssl \
  libcrypto3

# Install AWS CLI and kubectl
COPY scripts/install-awscli.sh scripts/install-kubectl.sh /tmp/
RUN /tmp/install-awscli.sh && \
  /tmp/install-kubectl.sh && \
  rm -f /tmp/install-*.sh && \
  rm -rf /var/cache/apk/*

# Application setup
COPY --from=builder /backendim-brain .
COPY scripts/ ./scripts/
COPY deployments/ ./deployments/

# Security hardening
RUN find ./scripts/ -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod 0755 {} + && \
  adduser -D -u 1001 backenduser && \
  mkdir -p /home/backenduser/.kube/manual /home/backenduser/.aws && \
  chown -R backenduser:backenduser /app /home/backenduser/.kube /home/backenduser/.aws && \
  chmod 0755 /home/backenduser && \
  chmod 0700 /home/backenduser/.kube /home/backenduser/.aws && \
  chmod 0755 /home/backenduser/.kube/manual

ENV KUBECONFIG=/home/backenduser/.kube/config \
  AWS_CONFIG_FILE=/home/backenduser/.aws/config \
  AWS_SHARED_CREDENTIALS_FILE=/home/backenduser/.aws/credentials \
  AWS_EC2_METADATA_DISABLED=true \
  PATH="/app/scripts:${PATH}" \
  GIT_SSL_NO_VERIFY="false"

USER backenduser

HEALTHCHECK --interval=30s --timeout=3s CMD scripts/healthcheck.sh
ENTRYPOINT ["/app/scripts/kube-init.sh", "--"]
CMD ["./backendim-brain"]
