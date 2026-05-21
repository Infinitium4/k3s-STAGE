#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# ✅ FIX 1 : chemin dynamique, plus de /home/vboxuser hardcodé
DEV_DIR="$(cd "$SCRIPT_DIR/../../quarkus-kafka-producer" && pwd)"
MANIFEST="$SCRIPT_DIR/templates/namespaceQuarkus.yaml"
IMAGE_NAME="localhost/quarkus-kafka-producer"
IMAGE_TAG="1.0.1"
IMAGE_FULL="$IMAGE_NAME:$IMAGE_TAG"
TAR_FILE="/tmp/quarkus-kafka-producer.tar"

echo "========================================"
echo " Quarkus - Build & Deploy"
echo "========================================"

# ✅ FIX 2 : vérifier que le dossier quarkus existe avant d'aller plus loin
if [ ! -d "$DEV_DIR" ]; then
  echo "ERREUR : dossier quarkus-kafka-producer introuvable : $DEV_DIR"
  echo "Assure-toi d'avoir cloné le repo quarkus au même niveau que k3s-STAGE."
  exit 1
fi

# ── 1. Nginx Ingress Controller ──────────────────────────────
echo ""
echo "[1/6] Installation de nginx ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
echo "   Attente du démarrage de nginx ingress..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# ── 2. Build Maven ───────────────────────────────────────────
echo ""
echo "[2/6] Build Maven..."
cd "$DEV_DIR"
./mvnw package -DskipTests

# ── 3. Build image Podman ────────────────────────────────────
echo ""
echo "[3/6] Build image Podman..."
podman build -f src/main/docker/Dockerfile \
  -t "$IMAGE_FULL" .

echo ""
echo "   Images Podman disponibles :"
podman images | grep quarkus

# ── 4. Chargement dans Kind ──────────────────────────────────
echo ""
echo "[4/6] Chargement de l'image dans Kind..."
podman save --format docker-archive -o "$TAR_FILE" "$IMAGE_FULL"
kind load image-archive "$TAR_FILE" --name stage
rm -f "$TAR_FILE"

echo "   Vérification de l'image dans Kind :"
# ✅ FIX 3 : pas de -it en non-interactif (plantait dans les scripts)
docker exec stage-control-plane crictl images | grep quarkus

# ── 5. Déploiement manifest ──────────────────────────────────
echo ""
echo "[5/6] Déploiement du namespace Quarkus..."
echo "   Détection de l'IP Kafka..."
KAFKA_IP=$(kubectl get svc my-cluster-kafka-bootstrap -n kafka -o jsonpath='{.spec.clusterIP}')

# ✅ FIX 4 : vérifier que l'IP a bien été récupérée
if [ -z "$KAFKA_IP" ]; then
  echo "ERREUR : impossible de détecter l'IP Kafka. Le service est-il démarré ?"
  exit 1
fi
echo "   IP Kafka détectée : $KAFKA_IP"

TMP_MANIFEST="/tmp/namespaceQuarkus.yaml"
sed "s/KAFKA_IP_PLACEHOLDER/$KAFKA_IP:9092/" "$MANIFEST" > "$TMP_MANIFEST"
kubectl apply -f "$TMP_MANIFEST"
rm -f "$TMP_MANIFEST"

# ── 6. Vérifications ─────────────────────────────────────────
echo ""
echo "[6/6] Vérifications..."
echo "   Attente du démarrage du pod Quarkus..."
kubectl wait --namespace quarkus \
  --for=condition=ready pod \
  --selector=app=quarkus-kafka-producer \
  --timeout=120s

echo ""
echo ">> Pods Quarkus :"
kubectl get pods -n quarkus
echo ""
echo ">> Services :"
kubectl get svc -n quarkus
echo ""
echo ">> Ingress :"
kubectl get ingress -n quarkus
echo ""
echo ">> Logs :"
kubectl -n quarkus logs deploy/quarkus-kafka-producer --tail=20

echo ""
echo "========================================"
echo " Quarkus déployé !"
echo ""
echo " Test :"
echo "   curl -X POST http://localhost/messages \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"key\":\"user-1\",\"message\":\"bonjour kafka\"}'"
echo "========================================"
