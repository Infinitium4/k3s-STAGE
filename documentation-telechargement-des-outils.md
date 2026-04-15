# DOCUMENTATION TELECHARGEMENT DES OUTILS

**prerequis** 

Pour commencer le projet j'ai besoin de certains outils. Les voici :
*kubectl*, *kubectx*, *podman*, *kind*, *healm*, *headlamp*

## KUBECTL

### Installation sur Ubuntu

Pour installer kubectl sur Ubuntu, suivez ces étapes officielles (basées sur la documentation Kubernetes). Assurez-vous d'avoir les droits sudo.

####  Via le dépôt officiel (apt)
1. Mettre à jour votre système :
   ``` bash
   sudo apt update
   ```

2. Installez les dépendances nécessaires :
   ``` bash
   sudo apt install -y apt-transport-https ca-certificates curl
   ```

3. Téléchargez et ajoutez la clé GPG de Kubernetes :
   ``` bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
   echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
   ```

4. Rendez kubectl exécutable et déplacez-le dans /usr/local/bin :
   ``` bash
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   ```

5. Vérifiez l'installation :
   ``` bash
   kubectl version --client
   ```

#### Méthode alternative : Via Snap
Sinon avec Snap :
``` bash
sudo snap install kubectl --classic
```

sources sur [documentation officielle](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/).
