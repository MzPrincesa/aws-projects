FROM mcr.microsoft.com/devcontainers/base:ubuntu

RUN apt-get update && \
    apt-get install -y \
        curl \
        unzip \
        tree \
        wget \
        apt-transport-https \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "/tmp/awscliv2.zip" && \
    unzip "/tmp/awscliv2.zip" -d "/tmp" && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

ENV AWS_CLI_AUTO_PROMPT=on-partial