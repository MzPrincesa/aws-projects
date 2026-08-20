FROM gitpod/workspace-full

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
 && unzip awscliv2.zip \
 && sudo ./aws/install \
 && rm -rf awscliv2.zip aws

# Enable AWS CLI auto-prompt feature
ENV AWS_CLI_AUTO_PROMPT=on-partial

# Install common utilities
RUN sudo apt-get update \
 && sudo apt-get install -y tree wget apt-transport-https software-properties-common \
 && sudo apt-get upgrade -y

 # Install the 'tree' command
RUN apt-get update && \
    apt-get install -y tree && \
    rm -rf /var/lib/apt/lists/*

