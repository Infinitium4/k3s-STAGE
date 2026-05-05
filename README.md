# kind-cluster documentation

## Commands

create a kind cluster named demo
```bash
kind create cluster --name demo
```
verify the cluster is running
```bash
kubectl get nodes
```
create your scripts
```bash
nano kafka.yml
nano kafkanodepool.yml
nano topic.yml
```
apply them to the cluster
```bash
kubectl apply -f kafka.yml
kubectl apply -f kafkanodepool.yml
kubectl apply -f topic.yml
```
delete the cluster when done
```bash
kind delete cluster --name demo
```

# additional resources

install strimzi operator
```bash
kubectl create ns kafka
```
add a helm repo
```bash
helm repo add strimzi https://strimzi.io/charts/
helm repo update
```
install the operator
```bash
helm install strimzi-release strimzi/strimzi-kafka-operator --namespace kafka
```
verify the operator is running
```bash
kubectl get pods -n kafka -w
```

## important notes and errors

* zookeeper is not supported, use KRaft mode instead
* Use kafka versions like : 4.1.0, 4.1.1, 4.2.0
* the KafkaNodePool requires the annotation `strimzi.io/node-pools: enabled` on the Kafka resource
* the KRaft mode requires the annotation `strimzi.io/kraft: enabled` on the Kafka resource

## manifest contents

### kafka.yml
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: kafka
  annotations:
    strimzi.io/node-pools: enabled
    strimzi.io/kraft: enabled
spec:
  kafka:
    version: 4.1.0
    metadataVersion: 4.1-IV0
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: external
        port: 9094
        type: nodeport
        tls: false
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

### kafkanodepool.yml
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: my-node-pool
  namespace: kafka
  labels:
    strimzi.io/cluster: my-cluster
spec:
  replicas: 3
  roles:
    - broker
    - controller
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 5Gi
        deleteClaim: false
```

### topic.yml
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: mon-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 604800000
    min.insync.replicas: "2"
```

# topics

verify the cluster is running
```bash
kubectl get pods -n kafka
```
verify the topic is created
```bash
kubectl get kafkatopics -n kafka
```
verify the services and nodeports
```bash
kubectl get svc -n kafka
```
if there is an error, check the logs of the operator
```bash
kubectl describe kafka my-cluster -n kafka
```

# external access

get the node IP
```bash
kubectl get nodes -o wide
```
list topics via the bootstrap NodePort
```bash
kubectl exec -it my-cluster-my-node-pool-0 -n kafka -- \
  ./bin/kafka-topics.sh --list --bootstrap-server <INTERNAL-IP>:<NODEPORT>
```
the bootstrap NodePort is visible in the svc list under `my-cluster-kafka-external-bootstrap`

# monitoring

## install Prometheus and Grafana

add the helm repo
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```
install the stack in the kafka namespace
```bash
helm install kafka-stack prometheus-community/kube-prometheus-stack --namespace kafka
```
verify the stack is running
```bash
kubectl get pods -n kafka -w
```

## important notes

* Prometheus and Grafana are installed in the `kafka` namespace, not `monitoring`
* the Grafana service name follows the pattern `<release-name>-grafana` (e.g. `kafka-stack-grafana`)

## access Grafana

find the Grafana service name
```bash
kubectl get svc -n kafka | grep grafana
```
expose Grafana on your browser
```bash
kubectl port-forward svc/kafka-stack-grafana 3000:80 -n kafka
```
open http://localhost:3000 — login: admin / admin

import the Kafka dashboard: Dashboards → Import → ID `7589`

## kafka metrics

create the metrics configmap
```bash
nano kafka-metrics.yml
```
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-metrics
  namespace: kafka
  labels:
    app: strimzi
data:
  kafka-metrics-config.yml: |
    lowercaseOutputName: true
    rules:
      - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
        labels:
          clientId: "$3"
          topic: "$4"
          partition: "$5"
      - pattern: kafka.server<type=(.+), name=(.+)><>OneMinuteRate
        name: kafka_server_$1_$2_rate
        type: GAUGE
      - pattern: kafka.server<type=(.+), name=(.+)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
```
create the pod monitor
```bash
nano kafka-pod-monitor.yml
```
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: kafka-pod-monitor
  namespace: kafka
  labels:
    release: kafka-stack
spec:
  namespaceSelector:
    matchNames:
      - kafka
  selector:
    matchLabels:
      strimzi.io/kind: Kafka
  podMetricsEndpoints:
    - path: /metrics
      port: tcp-prometheus
```
apply the manifests
```bash
kubectl apply -f kafka-metrics.yml
kubectl apply -f kafka-pod-monitor.yml
```
verify the pod monitor is created
```bash
kubectl get podmonitor -n kafka
```

# INITIALIZATION PROJET QUARKUS

## Pré-requis à installer
```bash
curl -LO https://dlcdn.apache.org/maven/maven-3/3.9.15/binaries/apache-maven-3.9.15-bin.tar.gz
tar xzvf apache-maven-3.9.15-bin.tar.gz
export MAVEN_HOME="$HOME/tools/apache-maven-3.9.15"
export PATH="$PATH:$MAVEN_HOME/bin"
mvn -v
```
### Vérification Java
```bash
java -version
```
## Initialiser le projet Quarkus

```bash
mvn io.quarkus.platform:quarkus-maven-plugin:3.34.6:create \
  -DprojectGroupId=com.stage \
  -DprojectArtifactId=quarkus-kafka-producer \
  -DclassName="com.stage.kafka.MessageResource" \
  -Dpath="/messages" \
  -Dextensions="rest-jackson,messaging-kafka"
```

### se déplacer dans le projet
```bash
cd quarkus-kafka-producer
```

### ouvrir VS Code
```bash
code .
```

## créer src/main/java/com/example/kafka/MessageRequest.java
```java
package com.stage.kafka;

public class MessageRequest {
    public String key;
    public String message;
}
```

## modifier src/main/java/com/example/kafka/MessageResource.java
```java
package com.stage.kafka;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.reactive.messaging.Channel;
import org.eclipse.microprofile.reactive.messaging.Emitter;
import org.eclipse.microprofile.reactive.messaging.Message;
import io.smallrye.reactive.messaging.kafka.api.OutgoingKafkaRecordMetadata;

@Path("/messages")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class MessageResource {

    @Channel("messages-out")
    Emitter<String> emitter;

    @POST
    public CompletionStage<Response> send(MessageRequest request) {
        String key = request.key != null ? request.key : "default-key";
        String payload = request.message != null ? request.message : "";

        CompletableFuture<Response> future = new CompletableFuture<>();

        OutgoingKafkaRecordMetadata<String> metadata = OutgoingKafkaRecordMetadata
                .<String>builder()
                .withKey(key)
                .build();

        Message<String> message = Message.of(payload)
                .addMetadata(metadata)
                .withAck(() -> {
                    future.complete(Response.accepted()
                            .entity(new ApiResponse("Message envoyé à Kafka"))
                            .build());
                    return CompletableFuture.completedFuture(null);
                })
                .withNack(throwable -> {
                    future.completeExceptionally(throwable);
                    return CompletableFuture.completedFuture(null);
                });

        emitter.send(message);
        return future;
    }

    public static class ApiResponse {
        public String status;

        public ApiResponse(String status) {
            this.status = status;
        }
    }
}
```

## modifier src/main/resources/MessageResourceTest.java
```java
package com.stage.kafka;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.CoreMatchers.equalTo;

@QuarkusTest
public class MessageResourceTest {

    @Test
    public void testSendMessage() {
        given()
            .contentType(ContentType.JSON)
            .body("{\"key\": \"test-key\", \"message\": \"hello kafka\"}")
        .when()
            .post("/messages")
        .then()
            .statusCode(202)
            .body("status", equalTo("Message envoyé à Kafka"));
    }
}
```

## Configuration Quarkus / Kafka

aller dans `src/main/resources/application.properties`

```properties
quarkus.http.port=8080

# Kafka - valeur utilisée uniquement en prod/Docker
# En mode dev, Quarkus démarre automatiquement un Kafka embarqué
%prod.kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVERS:kafka:9092}

mp.messaging.outgoing.messages-out.connector=smallrye-kafka
mp.messaging.outgoing.messages-out.topic=${KAFKA_TOPIC:demo-topic}
mp.messaging.outgoing.messages-out.key.serializer=org.apache.kafka.common.serialization.StringSerializer
mp.messaging.outgoing.messages-out.value.serializer=org.apache.kafka.common.serialization.StringSerializer

# Logs
quarkus.log.category."org.apache.kafka".level=INFO
quarkus.log.category."io.smallrye.reactive.messaging".level=INFO
```

### Tester localement en mode dev

```bash
./mvnw quarkus:dev
```
Test HTTP :
```bash
curl -X POST http://localhost:8080/messages \
  -H "Content-Type: application/json" \
  -d '{"key":"user-1","message":"bonjour kafka"}'
```

## Ajouter l'extension smallrye-health (probes Kubernetes)

Les endpoints `/q/health/live` et `/q/health/ready` nécessitent l'extension santé.

```bash
./mvnw quarkus:add-extension -Dextensions='smallrye-health'
```

> ⚠️ Cette commande modifie le `pom.xml`. Elle nécessite une connexion réseau pour télécharger la dépendance lors du prochain build.

## Build du JAR
```bash
./mvnw package -DskipTests
```

## Dockerfile / Containerfile

utiliser le dockerfile généré par Quarkus dans `src/main/docker/Dockerfile`

## Build d'image avec Podman
```bash
podman build -f src/main/docker/Dockerfile -t localhost/quarkus-kafka-producer:1.0.0 .
```
vérifier avec
```bash
podman images
```

puis charger sur kind
```bash
podman save --format docker-archive -o quarkus-kafka-producer.tar localhost/quarkus-kafka-producer:1.0.0
kind load image-archive quarkus-kafka-producer.tar --name stage
```

vérifier que l'image est bien présente dans kind
```bash
docker exec -it stage-control-plane crictl images | grep quarkus
```

## Créer un namespace pour l'application & son manifest de déploiement `namespaceQuarkus.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: quarkus
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: quarkus-kafka-producer-config
  namespace: quarkus
data:
  KAFKA_BOOTSTRAP_SERVERS: "10.96.1.43:9092"
  KAFKA_TOPIC: "mon-topic"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quarkus-kafka-producer
  namespace: quarkus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: quarkus-kafka-producer
  template:
    metadata:
      labels:
        app: quarkus-kafka-producer
    spec:
      containers:
        - name: quarkus-kafka-producer
          image: localhost/quarkus-kafka-producer:1.0.0
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
          env:
            - name: KAFKA_BOOTSTRAP_SERVERS
              valueFrom:
                configMapKeyRef:
                  name: quarkus-kafka-producer-config
                  key: KAFKA_BOOTSTRAP_SERVERS
            - name: KAFKA_TOPIC
              valueFrom:
                configMapKeyRef:
                  name: quarkus-kafka-producer-config
                  key: KAFKA_TOPIC
          readinessProbe:
            httpGet:
              path: /q/health/ready
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /q/health/live
              port: 8080
            initialDelaySeconds: 20
            periodSeconds: 15
---
apiVersion: v1
kind: Service
metadata:
  name: quarkus-kafka-producer
  namespace: quarkus
spec:
  selector:
    app: quarkus-kafka-producer
  ports:
    - name: http
      port: 8080
      targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: quarkus-kafka-producer
  namespace: quarkus
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: quarkus-kafka-producer
                port:
                  number: 8080
```

> ⚠️ Les probes `readinessProbe` et `livenessProbe` nécessitent l'extension `smallrye-health` dans le build. Si elle n'est pas présente, supprimer ces blocs du manifest pour éviter le CrashLoopBackOff.

### déployer
```bash
kubectl apply -f namespaceQuarkus.yaml
```
vérifier le déploiement
```bash
kubectl get pods -n quarkus
kubectl -n quarkus logs deploy/quarkus-kafka-producer
```

# Exposer le service via Ingress (sans port-forward)

kind ne supporte pas nativement les LoadBalancer. Il faut installer **MetalLB** pour attribuer une IP externe à l'ingress-nginx.

## 1. Installer ingress-nginx
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx get pods -w
```

## 2. Installer MetalLB
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
kubectl -n metallb-system get pods -w
```

## 3. Récupérer le subnet kind
```bash
docker network inspect kind | grep Subnet
```
exemple de résultat : `172.18.0.0/16`

## 4. Configurer MetalLB avec une plage d'IP dans ce subnet
```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: kind-pool
  namespace: metallb-system
spec:
  addresses:
    - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: kind-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - kind-pool
EOF
```

## 5. Vérifier que l'ingress-nginx obtient une IP externe
```bash
kubectl -n ingress-nginx get svc
```
exemple de résultat attendu :
```
ingress-nginx-controller   LoadBalancer   10.96.60.76   172.18.255.200   80:30726/TCP,443:31292/TCP
```

## 6. Tester via l'IP externe

```bash
curl -X POST http://172.18.255.200/messages \
  -H "Content-Type: application/json" \
  -d '{"key":"client-1","message":"message depuis mon poste"}'
```

Ou dans Postman : `POST http://172.18.255.200/messages`

# Vérifier que les messages arrivent dans Kafka

```bash
# Lister les topics
kubectl -n kafka exec -it my-cluster-my-node-pool-0 -- \
  bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Consommer les messages du topic
kubectl -n kafka exec -it my-cluster-my-node-pool-0 -- \
  bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic mon-topic \
  --from-beginning
```

Envoyer un message depuis un autre terminal et le voir apparaître dans le consumer.