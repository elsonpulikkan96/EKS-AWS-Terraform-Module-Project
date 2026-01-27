#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

############################################
# System Update & Base Packages
############################################
apt-get update -y
apt-get upgrade -y

apt-get install -y \
  curl \
  git \
  jq \
  ca-certificates \
  gnupg \
  lsb-release \
  bash-completion \
  apt-transport-https \
  unzip


############################################
# Install AWS CLI v2
############################################

# Download AWS CLI v2
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o /tmp/awscliv2.zip

# Unzip
unzip -q /tmp/awscliv2.zip -d /tmp

# Install (idempotent)
if ! command -v aws &>/dev/null; then
  /tmp/aws/install
fi

# Cleanup
rm -rf /tmp/aws /tmp/awscliv2.zip

# Verify
aws --version

############################################
# Install kubectl (Official Kubernetes Repo)
############################################
mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" \
| tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubectl

############################################
# kubectl Completion & Alias (Persistent)
############################################
cat <<'EOF' >/etc/profile.d/kubectl.sh
source <(kubectl completion bash)
alias k=kubectl
complete -F __start_kubectl k
EOF

chmod +x /etc/profile.d/kubectl.sh

############################################
# Install eksctl
############################################
ARCH=amd64
PLATFORM="$(uname -s)_${ARCH}"

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz"

curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" \
  | grep "${PLATFORM}" | sha256sum --check -

tar -xzf eksctl_${PLATFORM}.tar.gz -C /tmp
install -m 0755 /tmp/eksctl /usr/local/bin/eksctl

rm -f eksctl_${PLATFORM}.tar.gz /tmp/eksctl

############################################
# eksctl Completion & Alias
############################################
cat <<'EOF' >/etc/profile.d/eksctl.sh
source <(eksctl completion bash)
alias e=eksctl
complete -F __start_eksctl e
EOF

chmod +x /etc/profile.d/eksctl.sh

############################################
# Install Helm (Official Repo)
############################################
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey \
  | gpg --dearmor -o /usr/share/keyrings/helm.gpg

chmod 644 /usr/share/keyrings/helm.gpg

echo "deb [signed-by=/usr/share/keyrings/helm.gpg] \
https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" \
| tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update -y
sudo apt-get install -y helm

############################################
# Helm Completion & Alias
############################################
cat <<'EOF' >/etc/profile.d/helm.sh
source <(helm completion bash)
alias h=helm
complete -F __start_helm h
EOF

chmod +x /etc/profile.d/helm.sh

############################################
# Done
############################################
echo "kubectl, eksctl, and helm installed successfully"
