# Dockerfile Hardening + ECR + EKS: Deploy Craftify Securely

## Context

Craftify's platform engineering team is migrating the course platform backend to Kubernetes. The app has been containerized but the Dockerfile was written quickly and has several security issues. Before the image can be deployed to production it must be hardened, pushed to ECR, and deployed on an EKS cluster with the correct IAM permissions to pull from ECR and read configuration from S3.

The EKS cluster is already being provisioned in the background. The ECR repository and S3 bucket have been created for you. Your lab files are ready at `/home/user/craftify-eks-lab/`.

Start with the Dockerfile hardening and ECR push — the cluster will be ready by the time you reach the deployment steps.

##### To save and exit vim: press `Ctrl + C`

---

## Environment Details

- **Region:** `us-west-2`
- **Lab directory:** `/home/user/craftify-eks-lab/`
- **ECR repository URI:** check `/home/user/craftify-eks-lab/lab-config.txt`
- **S3 bucket name:** check `/home/user/craftify-eks-lab/lab-config.txt`
- **EKS cluster name:** `craftify-cluster`
- **Node group IAM role name:** `craftify-eks-node-role`

Check EKS cluster status anytime:

```bash
aws eks describe-cluster \
  --name craftify-cluster \
  --query "cluster.status" \
  --output text --region us-west-2
```

---

## What is Wrong with the Dockerfile?

Open `/home/user/craftify-eks-lab/Dockerfile`. It has the following security issues:

- **Runs as root** — no non-root user created or switched to
- **Unpinned base image** — `node:latest` can change unexpectedly
- **Unnecessary packages installed** — Like `vim`, `telnet`, `net-tools` have no place in a production image remove all of them
- **No HEALTHCHECK** — Kubernetes cannot determine container health
- **No `--chown` on COPY** — files are copied as root

---

## Tasks

### Task 1: Harden the Dockerfile

Fix all security issues in `/home/user/craftify-eks-lab/Dockerfile`:

- Pin the base image to a specific version (e.g. `node:18-alpine`)
- Remove unnecessary packages
- Create a non-root user and switch to it before CMD
- Add a HEALTHCHECK that hits `/health` on port 3000
- Use `--chown` when copying files

### Task 2: Build and Push to ECR

Authenticate Docker to ECR, build the hardened image, tag it as `hardened`, and push it:

```bash
aws ecr get-login-password --region us-west-2 \
  | docker login --username AWS --password-stdin <ECR-URI>

cd /home/user/craftify-eks-lab
docker build -t craftify-app:hardened .
docker tag craftify-app:hardened <ECR-URI>:hardened
docker push <ECR-URI>:hardened
```

### Task 3: Create the Node Group IAM Role

Create an IAM role named `craftify-eks-node-role` for EC2 with the following policies:

- `AmazonEKSWorkerNodePolicy`
- `AmazonEC2ContainerRegistryReadOnly`
- `AmazonEKS_CNI_Policy`
- A custom inline policy granting `s3:GetObject` on `arn:aws:s3:::<YOUR-BUCKET>/config/*`

### Task 4: Create the Node Group

Wait for the EKS cluster to show `ACTIVE` then create a managed node group:

- **Node group name:** `craftify-node-group`
- **Cluster:** `craftify-cluster`
- **IAM role:** `craftify-eks-node-role`
- **Instance type:** `t3.micro`
- **Min size:** `1` | **Desired size:** `2` | **Max size:** `3`

### Task 5: Configure kubectl

```bash
aws eks update-kubeconfig \
  --name craftify-cluster \
  --region us-west-2
```

### Task 6: Deploy the Application

Apply the deployment template from the lab directory:

```bash
kubectl apply -f /home/user/craftify-eks-lab/deployment.yaml
kubectl get pods -w
```

Wait for the pod to reach `Running` state.

### Task 7: Verify S3 Access

```bash
POD=$(kubectl get pods --selector=app=craftify -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$POD" -- wget -qO- http://localhost:3000/config
```

The response should contain the Craftify app configuration JSON fetched from S3.

---

## Notes

- The EKS cluster takes 15-20 minutes to provision. Use that time to complete Tasks 1-3.
- Use 2 x `t3.micro` nodes — system pods spread across both so neither runs out of memory. A single `t3.micro` cannot handle all system pods plus your app.
- The node group IAM role must exist before creating the node group.
- `wget` is pre-installed in the `node:18-alpine`
- Use `us-west-2` for all resources.