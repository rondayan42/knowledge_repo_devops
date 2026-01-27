# Knowledge Repo Infrastructure (Hybrid)

This repository contains the Terraform configuration for deploying the **Knowledge Repo** application using a **Hybrid Cloud Architecture**.

## 🏗 Deep Dive: Hybrid Architecture

Our setup explicitly bridges the gap between **Cloud Reliability** and **Local Development Economy**. Instead of running everything in the cloud (expensive) or everything locally (hard to share/collaborate), we mix the two.

### The Problem
*   **Full Cloud (EKS)**: Costs ~$70/month just for the control plane, plus NAT Gateways and Node costs.
*   **Full Local (Minikube)**: State is lost easily, no shareable registry for images, hard to simulate "real" deployments.

### The Hybrid Solution
We treat **AWS** as our "Storage Layer" and **Localhost** as our "Compute Layer".

| Layer | Component | Provider | Why? |
| :--- | :--- | :--- | :--- |
| **State** | Terraform State | **AWS S3** | Durable, shared source of truth. |
| **Locking** | State Lock | **AWS DynamoDB** | Prevents concurrent overwrites (team safety). |
| **Artifacts** | Container Registry | **AWS ECR** | Cloud-native, secure, accessible from anywhere. |
| **Compute** | Kubernetes Cluster | **Local Desktop** | Zero cost. Fast feedback loop. |
| **Secrets** | Image Pull Secrets | **K8s Secret** | Bridges AWS Auth to Local K8s. |

### 🔄 Data Flow & Lifecycle

1.  **Provisioning (Terraform)**:
    *   Terraform talks to AWS to create the **S3 Bucket** (State), **DynamoDB Table** (Lock), and **ECR Repositories** (Artifacts).
    *   Terraform talks to **Local Kubernetes** to create Namespaces, Services, and Deployments.

2.  **Delivery (`deploy.ps1`)**:
    *   **Login**: Authenticates your local Docker client with AWS ECR.
    *   **Bridge**: Generates a temporary Auth Token from AWS and saves it as a Kubernetes Secret (`regcred`) in your local cluster. **This is the key integration point.**
    *   **Build & Push**: Builds your code locally and uploads the images to AWS ECR.
    *   **Pull & Run**: Your Local Kubernetes Deployment sees the new image tag, uses the `regcred` secret to authenticate with AWS, pulls the image down, and runs it.

---

## 🔒 Security & Networking Decisions

By using this Hybrid model, we effectively "descope" several complex cloud networking components:

*   **VPC / Subnets**: **Not Required**. Your local cluster runs on your machine's network. We don't need a cloud Private Network because our "nodes" are local.
*   **IAM Roles**: **Replaced by Secrets**. In a full cloud setup, EC2 nodes would have IAM Roles to pull images. Here, we inject the credentials directly via the `regcred` Kubernetes Secret.
*   **Security Groups**: **Not Required**. Traffic is local to your machine.

---

## 🚀 Getting Started

### Prerequisites
*   **Terraform** (>= 1.0)
*   **AWS CLI** (configured with credentials)
*   **Docker Desktop** (Kubernetes enabled in settings)
*   **PowerShell** (for automation)

### 1. Bootstrap (One-time setup)
Creates the S3 Bucket and DynamoDB Table for remote state.
```bash
cd terraform/bootstrap
terraform init
terraform apply
```

### 2. Initialization
Connects Terraform to the remote backend created above.
```bash
# In terraform/ root
terraform init
```

### 3. Usage (Workspaces)
We use workspaces to manage environments (e.g., `dev`, `prod`). This allows us to reuse the same code for multiple environments.

```bash
# Create or Select workspace
terraform workspace new dev
terraform workspace select dev
```

### 4. Deployment
We use a helper script to automate the "Bridge" between AWS and Local K8s.

```powershell
.\scripts\deploy.ps1
```

**Step-by-Step Script Actions:**
1.  **Fetch Output**: Asks Terraform "Where is my ECR repo?"
2.  **AWS Login**: Authenticates docker CLI.
3.  **K8s Secret**: **CRITICAL STEP**. Refreshes the `regcred` secret in the cluster so it can access the private ECR repo.
4.  **Build**: `docker build ...`
5.  **Push**: `docker push ...` (To AWS ECR)
6.  **Rollout**: `kubectl rollout restart ...` (Forces K8s to pull the new image).

---

## 📂 Project Structure

*   `main.tf`: **The Orchestrator**. Configures providers and calls modules.
*   `outputs.tf`: **The Contract**. Exports data needed by CI/CD (Repo URLs, Ports).
*   `modules/`:
    *   `registry`: **Cloud Resources**. Manages AWS ECR repositories.
    *   `kubernetes`: **Local Resources**. Manages Deployments, Services, Secrets.
*   `scripts/`: **The Glue**. Scripts that bind Terraform outputs to Docker actions.

## 🛠 Troubleshooting

*   **ImagePullBackOff / ErrImagePull**: 
    *   Usually means the **Bridge** is broken. The `regcred` secret might be expired or missing. 
    *   **Fix**: Run `.\scripts\deploy.ps1` again. It refreshes the secret.
*   **Error acquiring state lock**: 
    *   Means another process (or a crashed previous run) holds the lock in DynamoDB.
    *   **Fix**: `terraform force-unlock <LOCK_ID>`
