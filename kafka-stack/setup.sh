#!/bin/bash
set -e

CHART_PATH="/STAGE1/k3s-stage/kafka-stack"

echo "========================================"
echo " Kafka Stack - Setup automatique"
echo "========================================"

# ── 1. Cluster Kind ──────────────────────────────────────────
echo ""
echo "[1/6] Création du cluster Kind..."
kind create cluster --name stage
kubectl get nodes

# ── 2. Namespaces ─────────────────────────────────────────────
echo ""
echo "[2/6] Création des namespaces..."
kubectl create ns kafka
kubectl create ns monitoring

# ── 3. Repos Helm ─────────────────────────────────────────────
echo ""
echo "[3/6] Ajout des repos Helm..."
helm repo add strimzi https://strimzi.io/charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ── 4. Dépendances du chart ───────────────────────────────────
echo ""
echo "[4/6] Téléchargement des dépendances Helm..."
helm dependency update "$CHART_PATH"

# ── 5. Installation du chart ──────────────────────────────────
echo ""
echo "[5/6] Installation du chart kafka-stack..."
helm install kafka-stack "$CHART_PATH" \
  --namespace kafka \
  --create-namespace \
  --wait \
  --timeout 5m

# ── 6. Vérifications ──────────────────────────────────────────
echo ""
echo "[6/6] Vérification du cluster..."
echo ""
echo ">> Pods Kafka :"
kubectl get pods -n kafka

echo ""
echo ">> Pods Monitoring :"
kubectl get pods -n monitoring

echo ""
echo ">> Topics :"
kubectl get kafkatopics -n kafka

echo ""
echo ">> Services :"
kubectl get svc -n kafka

echo ""
echo "========================================"
echo " Cluster prêt !"
echo ""
echo " Accès externe Kafka :"
echo "   kubectl get nodes -o wide"
echo "   kubectl exec -it my-cluster-my-node-pool-0 -n kafka -- \\"
echo "     ./bin/kafka-topics.sh --list --bootstrap-server <NODE-IP>:32465"
echo ""
echo " Accès Grafana :"
echo "   kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
echo "   http://localhost:3000  (admin / admin)"
echo "========================================"