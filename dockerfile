# Dockerfile
FROM debian:bookworm-slim
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

# Base tooling
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-pip curl unzip zip bash ca-certificates git \
 && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (official installer; no pip)
ARG TARGETARCH
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) AWS_ARCH=x86_64 ;; \
      arm64) AWS_ARCH=aarch64 ;; \
      *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip"; \
    unzip /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli; \
    rm -rf /tmp/aws /tmp/awscliv2.zip; \
    aws --version

# Install Terraform
ARG TERRAFORM_VERSION=1.9.5
RUN set -eux; \
    case "$TARGETARCH" in \
      amd64) TF_ARCH=amd64 ;; \
      arm64) TF_ARCH=arm64 ;; \
      *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/terraform.zip \
      "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip"; \
    unzip /tmp/terraform.zip -d /usr/local/bin; \
    chmod +x /usr/local/bin/terraform; \
    rm /tmp/terraform.zip; \
    terraform -version

# Helpful pip env (and allow pip in Debian’s managed env for your packaging step)
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

WORKDIR /app
COPY . .

# Run packaging + deploy, then stay alive so you can stream logs
CMD ["bash", "-lc", "chmod +x ./package.sh && ./package.sh && cd infra && terraform init -input=false && terraform apply -auto-approve && tail -f /dev/null"]
