#!/bin/bash

set -e

echo "mise a jour du systeme"
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git unzip apt-transport-https ca-certificates gnupg lsb-release

# ------------------------------------------------------------------------------------------
# KUBECTL
# ------------------------------------------------------------------------------------------
echo "installation de kubectl"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# ------------------------------------------------------------------------------------------
# KUBECTX + KUBENS
# ------------------------------------------------------------------------------------------
echo "installation de kubectx et kubens"
sudo rm -rf /opt/kubectx
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens

# ------------------------------------------------------------------------------------------
# K9S
# ------------------------------------------------------------------------------------------
echo "installation de k9s"
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
[ -z "$K9S_VERSION" ] && echo "Impossible de récupérer la version de k9s" && exit 1
curl -LO "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
tar -xzf k9s_Linux_amd64.tar.gz k9s
chmod +x k9s
sudo mv k9s /usr/local/bin/
rm -f k9s_Linux_amd64.tar.gz

# ------------------------------------------------------------------------------------------
# KIND
# ------------------------------------------------------------------------------------------
echo "installation de kind"
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x kind
sudo mv kind /usr/local/bin/kind

# ------------------------------------------------------------------------------------------
# PODMAN
# ------------------------------------------------------------------------------------------
echo "installation de podman"
sudo apt install -y podman

# ------------------------------------------------------------------------------------------
# HELM
# ------------------------------------------------------------------------------------------
echo "installation de helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    
# ------------------------------------------------------------------------------------------
# HEADLAMP
# ------------------------------------------------------------------------------------------
echo "installation de headlamp"
HEADLAMP_VERSION=$(curl -s https://api.github.com/repos/headlamp-k8s/headlamp/releases/latest | grep tag_name | cut -d '"' -f 4)
[ -z "$HEADLAMP_VERSION" ] && echo "Impossible de récupérer la version de headlamp" && exit 1
HEADLAMP_VER_CLEAN="${HEADLAMP_VERSION#v}"
wget "https://github.com/headlamp-k8s/headlamp/releases/download/${HEADLAMP_VERSION}/Headlamp-${HEADLAMP_VER_CLEAN}-linux-x64.deb"
sudo apt install -y "./Headlamp-${HEADLAMP_VER_CLEAN}-linux-x64.deb"
rm -f "Headlamp-${HEADLAMP_VER_CLEAN}-linux-x64.deb"

echo "installation terminee"