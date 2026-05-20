#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KIND_CONFIG="$SCRIPT_DIR/../config/kind-config.yaml"
CHART_PATH="$SCRIPT_DIR"

echo "========================================"
echo " Kafka Stack - Setup automatique"
echo "========================================"

# ── 0. Permissions Docker ─────────────────────────────────────
echo ""
echo "[0/7] Vérification des permissions Docker..."

# Ajouter l'user au groupe docker si besoin
if ! groups "$USER" | grep -q docker; then
  echo "Ajout de $USER au groupe docker..."
  sudo usermod -aG docker "$USER"
fi

# S'assurer que Docker tourne
sudo systemctl enable docker --now

# Attendre le socket
for i in {1..10}; do
  [ -S /var/run/docker.sock ] && break
  sleep 1
done

# Fix immédiat des permissions du socket (évite le logout/login)
sudo chmod 660 /var/run/docker.sock
sudo chown root:docker /var/run/docker.sock

# Vérification finale
if ! docker info &>/dev/null; then
  echo "ERREUR : Docker toujours inaccessible."
  exit 1
fi
echo "✅ Docker OK"

# ── 1. Prérequis ──────────────────────────────────────────────
echo ""
echo "[1/7] Vérification des prérequis (kind / kubectl / helm)..."

for cmd in kind kubectl helm; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERREUR : '$cmd' n'est pas installé."
    exit 1
  fi
done
echo "✅ Prérequis OK"

# ── 2. Cluster Kind ───────────────────────────────────────────
echo ""
echo "[2/7] Création du cluster Kind..."

if kind get clusters | grep -q "^stage$"; then
  echo "Cluster 'stage' déjà existant, skip."
else
  kind create cluster --name stage --config "$KIND_CONFIG"
fi

kubectl get nodes

# ── 3. Namespaces ─────────────────────────────────────────────
echo ""
echo "[3/7] Création des namespaces..."
kubectl create ns kafka      --dry-run=client -o yaml | kubectl apply -f -
kubectl create ns monitoring --dry-run=client -o yaml | kubectl apply -f -

# ── 4. Repos Helm ─────────────────────────────────────────────
echo ""
echo "[4/7] Ajout des repos Helm..."
helm repo add strimzi              https://strimzi.io/charts/                          || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts  || true
helm repo update

# ── 5. Dépendances du chart ───────────────────────────────────
echo ""
echo "[5/7] Téléchargement des dépendances Helm..."
helm dependency update "$CHART_PATH"

# ── 6. Installation du chart ──────────────────────────────────
echo ""
echo "[6/7] Installation du chart kafka-stack..."
helm upgrade --install kafka-stack "$CHART_PATH" \
  --namespace kafka \
  --create-namespace \
  --wait \
  --timeout 10m

# ── 7. Vérifications ──────────────────────────────────────────
echo ""
echo "[7/7] Vérification du cluster..."
echo ""
echo ">> Pods Kafka :"
kubectl get pods -n kafka
echo ""
echo ">> Pods Monitoring :"
kubectl get pods -n monitoring
echo ""
echo ">> Topics :"
kubectl get kafkatopics -n kafka 2>/dev/null || echo "(CRD pas encore prête)"
echo ""
echo ">> Services :"
kubectl get svc -n kafka

echo ""
echo "========================================"
echo " Cluster prêt !"
echo ""
echo " Accès Grafana :"
echo "   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo "   http://localhost:3000  (admin / admin)"
echo "========================================"
