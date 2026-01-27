# Terraform Infrastructure Documentation

This directory contains the Terraform configuration for deploying the Knowledge Repo application to Kubernetes. This document outlines the architectural decisions ("Whys") and the implementation details ("Hows").

## Project Structure

```
terraform/
├── main.tf                 # Root configuration (The entry point)
├── modules/
│   └── kubernetes/         # Reusable logic for the application stack
│       ├── main.tf         # Resource definitions
│       ├── variables.tf    # Input parameters
│       └── outputs.tf      # Return values (e.g., Service names)
└── README.md
```

## Architectural Decisions & Rationale

### 1. Modular Design
**Why?**
Instead of dumping all resources into a single file, we split the logic into a `modules/kubernetes` directory.
-   **Reusability**: This module can be instantiated multiple times for different environments (e.g., `dev`, `staging`, `prod`) just by passing different variables from the root `main.tf`.
-   **Isolation**: Changes to the module logic are separated from the specific environment configuration.

### 2. Computing Resources: StatefulSet vs Deployment
**Why use a StatefulSet for the Database?**
We used `kubernetes_stateful_set_v1` for Postgres instead of a Deployment.
-   **Stable Identity**: Databases need a consistent network identity (hostname) so the application can always find the leader.
-   **Ordered Deployment**: Ensures the database fits strict startup/teardown ordering requirements if we scale.
-   **Persistent Storage**: Binds specifically to a PersistentVolumeClaim template ensuring data survives pod restarts.

**Why use Deployments for App & Client?**
We used `kubernetes_deployment_v1` for the Server and Client.
-   **Statelessness**: These applications do not store state locally. If a pod dies, it can be replaced by any other fresh pod without data loss.
-   **Rolling Updates**: Deployments support zero-downtime updates by gradually replacing pods.

### 3. Networking & Service Discovery
-   **ClusterIP**: Used for the Database and Client internal communication. This keeps traffic secure within the cluster; the outside world cannot access the DB directly.
-   **NodePort**: Used for the Server (`knowledge-repo-server`) to expose it on a static port (`30050`) on the host node. This is chosen for simplicity in checking the work immediately without setting up an external Load Balancer or Ingress Controller yet.

### 4. Configuration Management
**Why ConfigMaps and Secrets?**
-   **Decoupling**: Configuration (DB URL, Port) is separated from the application code/image. You can change settings without rebuilding the Docker image.
-   **Security**: Sensitive data (Passwords, JWT Secrets) is stored in `kubernetes_secret_v1` rather than plain text in the Deployment definition.
    *   *Note*: In a real production environment, you would inject these secrets from an external vault (like Vault or AWS Secrets Manager) rather than defining them in Terraform code.

## How to Manage Infrastructure

### Prerequisites
-   **Terraform**: v1.0+ installed.
-   **Kubectl**: Configured to point to your target cluster (`~/.kube/config`).

### Common Commands

1.  **Initialize**: Downloads the Kubernetes provider and sets up the environment.
    ```bash
    terraform init
    ```

2.  **Verify**: Checks for syntax errors and validates references.
    ```bash
    terraform validate
    ```

3.  **Plan**: Preview what changes Terraform will make. ALWAYS run this before applying.
    ```bash
    terraform plan
    ```

4.  **Apply**: Execute the changes against the cluster.
    ```bash
    terraform apply
    ```

5.  **Destroy**: Tear down all resources managed by this configuration.
    ```bash
    terraform destroy
    ```
