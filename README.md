# Airflow Deployment with Helm and Kubernetes (Trino, PySpark, Numpy, Pandas)

This guide provides step-by-step instructions for deploying Apache Airflow on Kubernetes using Helm. It also covers how to manage Docker images, configure GitSync, and troubleshoot common issues.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Deploying Airflow with Helm](#deploying-airflow-with-helm)
3. [Customizing and Extending the Airflow Image (Trino, PySpark, Numpy, Pandas)](#customizing-and-extending-the-airflow-image-trino-pyspark-numpy-pandas)
4. [Configuring GitSync for DAGs](#configuring-gitsync-for-dags)
5. [Using an External Database](#using-an-external-database)
6. [Exposing the Airflow UI](#exposing-the-airflow-ui)
7. [Managing Docker Images](#managing-docker-images)
8. [Troubleshooting](#troubleshooting)
9. [Contributing](#contributing)
    
---

## Prerequisites

Before starting, ensure you have the following installed and configured:

- **Kubernetes Cluster**: A running Kubernetes cluster (e.g., Minikube, GKE, EKS, or any other).
- **Helm**: The Kubernetes package manager. Install it from [here](https://helm.sh/docs/intro/install/).
- **kubectl**: The Kubernetes command-line tool. Install it from [here](https://kubernetes.io/docs/tasks/tools/).
- **Docker**: For building and managing Docker images. Install it from [here](https://docs.docker.com/get-docker/).
- **Git**: For version control and GitSync configuration.
---

## Deploying Airflow with Helm

### 1. Add the Airflow Helm Repository
Add the official Apache Airflow Helm repository:

```bash
helm repo add apache-airflow https://airflow.apache.org
helm repo update
```

### 2. Create a Namespace
Create a dedicated namespace for Airflow:

```bash
kubectl create namespace your-namespace
```


### 3. Install Airflow
Install Airflow using Helm:

```bash
helm install my-airflow apache-airflow/airflow --namespace your-namespace --debug
```

### 4. Verify the Installation
Check the status of the deployed pods:

```bash
kubectl get pods -n your-namespace
```
![image](https://github.com/user-attachments/assets/ff215632-911c-4a91-b163-c7ab72cb025a)
---

## Customizing and Extending the Airflow Image (Trino, PySpark, Numpy, Pandas)
The default Docker image used in Airflow configurations is the base image provided by Apache. However, to meet our specific needs, we will extend this image by adding the necessary packages to run our DAGs and integrating the Apache Spark provider. Our goal is to seamlessly integrate Spark and Airflow.

### 1. Create a `requirements.txt` File:
To install the required Python packages, create a `requirements.txt` file with the following content:

```plaintext
pandas==1.3.5
minio==6.0.2
numpy==1.21.6
pyspark==3.4.0
apache-airflow-providers-trino==4.2.0
```

This file ensures that all necessary dependencies are installed in the Docker image.

### 2. Build a Custom Docker Image
Create a `Dockerfile` to extend the base Airflow image and include the required packages and configurations.

```DockerFile
# Use the official Apache Airflow image as the base
FROM apache/airflow:2.7.3

# Set the maintainer label
LABEL maintainer="Yasmine"

# Switch to root user to install system dependencies
USER root

# Install Java (required for Spark)
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         openjdk-11-jre-headless \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Switch back to the airflow user
USER airflow

# Copy the requirements file into the image
COPY requirements.txt .

# Install Python packages from requirements.txt
RUN pip install -r requirements.txt

# Set the JAVA_HOME environment variable
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# Install Apache Airflow and the Spark provider
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" apache-airflow-providers-apache-spark==2.1.3
```

### 3. Build the Docker Image
Run the following command to build the custom Docker image:

```bash
docker build . -t myairflow:1.0.0
```
This command creates a Docker image named `myairflow` with the tag `1.0.0`.

### 4. Push the Image to a Docker Registry
To make the image available for deployment, push it to a Docker registry such as Docker Hub or a private registry like Harbor.

#### a. Tag the Image
Tag the image with your Docker Hub username or private registry URL:

```bash
docker tag myairflow:1.0.0 docker.io/yasminekd/myairflow:1.0.0
```
#### b. Push the Image
Push the image to the registry:

```bash
docker push docker.io/yasminekd/myairflow:1.0.0
```

### 5. Update the values.yaml File
To use the custom image in your Airflow deployment, update the `values.yaml` file:

```bash
images:
  airflow:
    repository: docker.io/yasminekd/myairflow
    tag: 1.0.0
```
This ensures that your Helm deployment uses the custom image instead of the default Apache Airflow image.

### 6. Upgrading or Adding Providers
Providers (such as Spark or Amazon) evolve independently of Airflow Core. Whenever you need to upgrade or add a provider, you must rebuild the Docker image. Follow these steps:

1. Update the `requirements.txt` file or the `RUN pip install` command in the Dockerfile.

2. Rebuild the Docker image with a new tag (e.g., `1.0.1`).

3. Push the updated image to the registry.

4. Update the `values.yaml` file to reference the new image tag.

### 7. Deploy the Updated Airflow
After updating the `values.yaml` file, upgrade your Airflow deployment using Helm:

```bash
helm upgrade my-airflow apache-airflow/airflow -f values.yaml --namespace your-namespace --debug
```
### Summary
By customizing the Airflow Docker image, you can:

Add required Python packages.
- Integrate external tools like Apache Spark.

- Ensure your Airflow environment is tailored to your specific needs.

- This approach provides flexibility and ensures that your Airflow deployment is ready to handle complex workflows and integrations.
---
## Configuring GitSync for DAGs
GitSync allows Airflow to synchronize DAGs from a Git repository. Follow these steps to configure it:

### 1. Create a Kubernetes Secret for Git Credentials
Encode your Git username and password in base64:

```bash
echo -n 'your_username' | base64
echo -n 'your_password' | base64
```
![image](https://github.com/user-attachments/assets/36dd6a63-f8ab-471b-b2d6-b7ca13d462b3)

Create a `credentialSecrets.yaml` file:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: git-credentials
data:
  GIT_SYNC_USERNAME: <base64_encoded_username>
  GIT_SYNC_PASSWORD: <base64_encoded_password>
```

Apply the secret:
```bash
kubectl apply -f credentialSecrets.yaml -n your-namespace
```

### 2. Updating configurations

Recover the values from the chart in a file.
```bash
helm show values apache-airflow/airflow> values.yaml 
```

### 3. Update `values.yaml`

Enable GitSync in your `values.yaml`:
```yaml
dags:
  persistence:
  enabled: false
  gitSync:
    enabled: true
    repo: https://github.com/your_username/your_repo.git
    branch: main
    credentialsSecret: git-credentials
```
![image](https://github.com/user-attachments/assets/d9dac7c5-47f6-4543-a4e2-33447b49e180)

### 4. Upgrade the Helm Release

Apply the changes:
```bash
helm upgrade my-airflow apache-airflow/airflow -f values.yaml --namespace your-namespace --debug 
```
---
## Using an External Database
By default, Airflow uses an in-cluster PostgreSQL database. For production, use an external database like AWS RDS or Cloud SQL.

### 1. Disable In-Cluster PostgreSQL

Update `values.yaml`:
```yaml
postgresql:
  enabled: false
```

![image](https://github.com/user-attachments/assets/583390bd-13b1-4f0d-b6cd-211022d33e93)

### 2. Configure the External Database

Add the connection string to `values.yaml`:

```yaml
config:
  AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: "postgresql+psycopg2://user:password@host:port/db"
```
![image](https://github.com/user-attachments/assets/d5dbdc12-7795-4ca8-9c18-4f7a7e9a1ed0)

### 3. Upgrade the Helm Release

Add the connection string to `values.yaml`:

```bash
helm upgrade my-airflow apache-airflow/airflow -f values.yaml --namespace your-namespace --debug
```
---

## Exposing the Airflow UI
To access the Airflow UI externally, expose it using a `NodePort` or `LoadBalancer`.

### 1. Update `values.yaml`
Configure the web service:

```yaml
service:
  type: NodePort
  ## service annotations
  annotations: {}
  ports:
    - name:  airflow-ui
      port: "{{ .Values.ports.airflowUI }}"
      targetPort: 8080
      nodePort: 31151
```
![image](https://github.com/user-attachments/assets/b6880ee7-6f48-48a4-a5c6-5e6c12758e2f)

To retrieve the IP of a node in your cluster: 

```bash
kubectl get no -o wide
```

### 2. Connection to the web server 

Generate a cryptographic secure random string of length 32 characters (16 bytes in hexadecimal format) for webserverSecretKey:

> **Note**: The `webserverSecretKey` is a secure key used by Apache Airflow to sign user sessions and cookies. It ensures that session data is not tampered with and maintains the security of the Airflow web interface. A strong, randomly generated key is recommended for production environments.

```bash
python3 -c 'import secrets; print(secrets.token_hex(32))'
```
Example output: **a1b2c3d4e3f6a7h8i9j0k1542m3n4o5p6q7r8s9t0u7e2w3x4y5z68**

Connection to the web server:

```yaml
webserverSecretKey: fc1a1cf5df8560e4c1ec4a3bc810a418 
```

Generate a secure Fernet Key using the `cryptography` library. The key is a URL-safe base64-encoded string, 32 bytes in length, used for encrypting sensitive data in Apache Airflow: 

> **Note**: Fernet Key is used in Apache Airflow to encrypt passwords and other sensitive data.

```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```
Example output: **sV3X5y7z9B1D2G4J6L8M0N1O3P5Q7R9S**

Open the `values.yaml` file and update the fernetKey:

```yaml
fernetKey: sV3X5y7z9B1D2G4J6L8M0N1O3P5Q7R9S 
```

![image](https://github.com/user-attachments/assets/2485d0cb-6869-46e9-a947-22f5cb6a6da8)

### HINT: Adding Fernet Key and Webserver Secret Key Directly

You can add `Fernet Key` and `Webserver Secret Key` directly without modifying `values.yaml`. Here's how:

---

#### 1. Generate Fernet Key

Use the following Python command to generate a Fernet Key:

```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```
**Example Output:** sV3X5y7z9B1D2G4J6L8M0N1O3P5Q7R9S

---

#### 2. Generate Webserver Secret Key

Use the following Python command to generate a Webserver Secret Key:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```
**Example Output:** a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6

---

#### 3. Pass Keys Directly via Command Line

Instead of updating `values.yaml`, you can pass these keys directly when deploying or upgrading Airflow using Helm. Use the `--set` flag to override configuration values.

```bash
helm upgrade my-airflow apache-airflow/airflow \
  --namespace your-namespace \
  --set config.AIRFLOW__CORE__FERNET_KEY="sV3X5y7z9B1D2G4J6L8M0N1O3P5Q7R9S" \
  --set config.AIRFLOW__WEBSERVER__SECRET_KEY="a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6" \
  --debug
```
---

#### 4. Explanation of the Command

- `--set config.AIRFLOW__CORE__FERNET_KEY="..."`: Sets the Fernet Key for Airflow.

- `--set config.AIRFLOW__WEBSERVER__SECRET_KEY="..."`: Sets the Webserver Secret Key for Airflow.

- `--namespace your-namespace`: Specifies the namespace where Airflow is deployed.

- `--debug`: Enables debug mode for detailed output.

---

#### 5. Why Use This Approach?

**Quick and Easy**: No need to modify `values.yaml` or create additional files.

**Secure**: Keys are passed directly via the command line and not stored in plain text files.

**Flexible**: Ideal for temporary deployments or testing environments.

---

#### 6. Important Notes

- **Security**: Avoid hardcoding keys in scripts or exposing them in logs. Use environment variables or Kubernetes Secrets for production deployments.

- **Consistency**: Ensure the same keys are used across all Airflow components (scheduler, webserver, workers) to avoid inconsistencies.

---

#### 7. Using Kubernetes Secrets (Optional)
For production, it’s recommended to store these keys in Kubernetes Secrets. Here’s how:

**Create a Secret:**
```bash
kubectl create secret generic airflow-keys \
  --namespace your-namespace \
  --from-literal=fernet-key="sV3X5y7z9B1D2G4J6L8M0N1O3P5Q7R9S" \
  --from-literal=webserver-secret-key="a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6"
```
**Reference the Secret in Helm:**
```bash
helm upgrade my-airflow apache-airflow/airflow \
  --namespace your-namespace \
  --set config.AIRFLOW__CORE__FERNET_KEY="$(kubectl get secret airflow-keys -n your-namespace -o jsonpath='{.data.fernet-key}' | base64 --decode)" \
  --set config.AIRFLOW__WEBSERVER__SECRET_KEY="$(kubectl get secret airflow-keys -n your-namespace -o jsonpath='{.data.webserver-secret-key}' | base64 --decode)" \
  --debug
```
---

### 4. 3. Access the UI
Get the node IP:

```bash
kubectl get nodes -o wide
```
Access the UI at:

```bash
http://<node_ip>:31151
```

## Managing Docker Images
### 1. Pull the Airflow Image
If you need to download the Airflow with Trino connector so take my image:

```bash
docker pull docker.io/ynb4gang/myairflow:1.0.0
```

### 2. Save the Image to a File
Save the image for backup or sharing:
```bash
docker save -o myairflow_image.tar docker.io/ynb4gang/myairflow:1.0.0
```

### 3. Push the Image to GitHub Container Registry (GHCR)
Tag and push the image to GHCR:
```bash
docker tag docker.io/ynb4gang/myairflow:1.0.0 ghcr.io/your_username/myairflow:1.0.0
docker push ghcr.io/your_username/myairflow:1.0.0
```

## Troubleshooting
### Common Issues
1. **Job run-airflow-migrations Fails:**
   - Check the logs of the associated Pod:
     ```bash
     kubectl logs <pod_name> -n your-namespace
     ```
   - Verify the database connection string.
2. **GitSync Not Working:**
   - Ensure the Git credentials secret is correctly configured.
   - Check the logs of the GitSync container.
3. **Airflow UI Not Accessible:**
   - Verify the service type and node port in `values.yaml`.
   - Check firewall rules if using a cloud provider.
  
## Contributing
Contributions are welcome! If you find any issues or have suggestions, please open an issue or submit a pull request.
