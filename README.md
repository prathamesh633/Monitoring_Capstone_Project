# Python Flask App + ELK Stack on AWS EKS

This project provisions a production-ready AWS Elastic Kubernetes Service (EKS) cluster using Terraform, and deploys a Python Flask application alongside a fully integrated ELK (Elasticsearch, Logstash, Kibana, Filebeat) monitoring stack.

## Architecture

1.  **Infrastructure (Terraform)**:
    *   VPC with Public and Private subnets across 3 Availability Zones.
    *   EKS Cluster with a managed Node Group (EC2 `t3.medium` instances) in private subnets.
    *   AWS Load Balancer Controller (installed via Helm) for provisioning Network Load Balancers (NLBs).
    *   Elastic Block Store (EBS) CSI driver and StorageClass for stateful persistence.
2.  **Application (`k8s/`)**:
    *   A simple Python Flask API running as a Deployment.
    *   Exposed securely to the internet via an AWS NLB on port 80 (routing to container port 5000).
3.  **Monitoring Stack (`k8s/elk/`)**:
    *   **Filebeat**: Runs as a DaemonSet on every EKS node, tailing all container logs (including the Flask app).
    *   **Logstash**: Receives logs from Filebeat, parses them, and forwards them.
    *   **Elasticsearch**: Central data store running as a StatefulSet with a 10Gi AWS EBS Persistent Volume.
    *   **Kibana**: The visualization dashboard, exposed via its own NLB on port 5601.

---

## Prerequisites

*   AWS CLI installed and configured (`aws configure`) with Administrator access.
*   Terraform installed (v1.6.0+).
*   `kubectl` installed.
*   Docker (optional, if you wish to push your own image to the provisioned ECR repo).

---

## Step-by-Step Deployment Guide

### 1. Provision the AWS Infrastructure (Terraform)

First, use Terraform to create the VPC, EKS cluster, IAM roles, and necessary add-ons.

```bash
cd terraform/

# Initialize Terraform (downloads providers and modules)
terraform init

# Review the execution plan
terraform plan

# Apply the configuration (This takes ~15-20 minutes)
terraform apply -auto-approve
```

### 2. Configure `kubectl`

Once Terraform finishes, it will output a command to update your local kubeconfig. Run the command provided in the output, which looks like this:

```bash
aws eks update-kubeconfig --region us-east-1 --name capstone-eks-cluster
```

Verify your cluster connection and ensure the worker nodes are ready:

```bash
kubectl get nodes
```

### 3. Deploy the Application and ELK Stack

Navigate back to the Kubernetes manifests directory and deploy the application:

```bash
cd ../k8s/

# Deploy the Python Flask app (Namespace, Deployment, LoadBalancer Service)
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

Now, deploy the ELK stack components into their dedicated `logging` namespace:

```bash
# Deploy ELK Stack components
kubectl apply -f elk/namespace.yaml
kubectl apply -f elk/elastic-credentials.yaml
kubectl apply -f elk/elasticsearch.yaml
kubectl apply -f elk/logstash.yaml
kubectl apply -f elk/kibana.yaml
kubectl apply -f elk/filebeat.yaml
kubectl apply -f elk/metricbeat.yaml
```

### 4. Verify the Deployment

Check that the Flask app pods are running and note the `EXTERNAL-IP` of its service:

```bash
kubectl get pods,svc -n flask-app
```
*You can access your Flask application by navigating to the `EXTERNAL-IP` of `python-flask-app-svc` in your browser.*

Check the ELK stack components:

```bash
kubectl get pods,svc,pvc -n logging
```
*Note: Elasticsearch takes a moment to provision its EBS volume and start. Kibana will wait for Elasticsearch to be healthy. Once running, note the `EXTERNAL-IP` of `kibana-svc`.*

### 5. Monitor the App in Kibana

1.  Open your browser and navigate to the Kibana URL: `http://<kibana-svc-external-ip>:5601`
2.  Login to Kibana with:
    - Username: `elastic`
    - Password: value in `k8s/elk/elastic-credentials.yaml` (`ELASTIC_PASSWORD`)
3.  Click the hamburger menu (top left) and go to **Stack Management** > **Data Views**.
4.  Create `logstash-*` data view (`@timestamp`) for logs.
5.  Create `metricbeat-*` data view (`@timestamp`) for infrastructure and Kubernetes metrics.
6.  Open **Discover** and select `metricbeat-*`.
7.  Use this KQL filter to confirm pod metrics are present:
    ```kql
    event.dataset : "kubernetes.pod" and kubernetes.pod.cpu.usage.nanocores : *
    ```
8.  Create Lens visualizations for pod-level dashboards:
    - Pod CPU (mCPU): `average(kubernetes.pod.cpu.usage.nanocores) / 1000000`
    - Pod Memory (MiB): `average(kubernetes.pod.memory.usage.bytes) / 1048576`
    - Breakdown: `kubernetes.pod.name`
9.  For Flask app logs, switch to `logstash-*` and filter:
    ```
    kubernetes.labels.app: "python-flask-app"
    ```

### 6. Pod Crash Alerts with ElastAlert (Free Alternative to Kibana Connectors)

Use this when you want email alerts for pod crashes without paid Kibana connector features.

1. Deploy Kubernetes event collection (required for crash reasons like `CrashLoopBackOff`):
   ```bash
   kubectl apply -f k8s/elk/metricbeat-events.yaml
   ```
2. Edit email + SMTP values in:
   - `k8s/elk/elastalert/elastalert.yaml`
   - `YOUR_SMTP_USERNAME`
   - `YOUR_SMTP_PASSWORD_OR_APP_PASSWORD`
   - `YOUR_ALERT_RECEIVER_EMAIL@example.com`
   - `YOUR_FROM_EMAIL@example.com`
3. Deploy ElastAlert:
   ```bash
   kubectl apply -f k8s/elk/elastalert/elastalert.yaml
   ```
4. Verify pods:
   ```bash
   kubectl get pods -n logging | grep -E 'metricbeat-events|elastalert'
   ```
5. Verify event documents are reaching Elasticsearch:
   ```bash
   kubectl exec -n logging elasticsearch-0 -- \
     curl -s -u 'elastic:ChangeMe_Strong@123' \
     'http://localhost:9200/metricbeat-*/_count?q=event.dataset:kubernetes.event%20AND%20kubernetes.namespace:flask-app'
   ```
6. Trigger a crash in `flask-app` (bad image/command), then watch ElastAlert logs:
   ```bash
   kubectl logs -n logging deploy/elastalert -f
   ```

---

## Cleanup / Teardown

To avoid incurring AWS charges, destroy the resources when you are done.

**Important**: You must delete the Kubernetes resources first so the AWS Load Balancer Controller can properly clean up the Network Load Balancers it created.

```bash
# 1. Delete K8s resources (Cleans up NLBs and EBS volumes)
kubectl delete -f k8s/elk/
kubectl delete -f k8s/

# 2. Destroy Terraform infrastructure
cd terraform/
terraform destroy -auto-approve
```
