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

- zookeeper is not supported, use KRaft mode instead
- Use kafka versions like : 4.1.0, 4.1.1, 4.2.0
- the KafkaNodePool requires the annotation strimzi.io/node-pools: enabled on the Kafka resource
- the KRaft mode requires the annotation strimzi.io/kraft: enabled on the Kafka resource

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
the bootstrap NodePort is visible in the svc list under my-cluster-kafka-external-bootstrap