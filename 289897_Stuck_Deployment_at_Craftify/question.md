# CodePipeline + CodeDeploy: Fix the Stuck Deployment at Craftify

## Context

Craftify is a hands-on tech learning platform that deploys its course platform backend via a fully automated CI/CD pipeline — S3 as the source, CodePipeline as the orchestrator, and CodeDeploy for deployment to EC2.

The release engineer packaged version `2.1.3` of the backend service and uploaded it to the source S3 bucket before signing off for the day. The pipeline triggered automatically at 7:45 PM. It is now 8:30 PM and the pipeline is still stuck at the Deploy stage showing **"Waiting for agent"**. The 9 PM release window is closing fast.

You are the on-call engineer. Your job is to diagnose why the CodeDeploy deployment is stuck, fix it, and verify that version `2.1.3` is successfully deployed to the production server.

##### To save and exit vim: press `Ctrl + C`

---

## Getting Started

Run the setup script to provision the lab environment:

```bash
sudo bash /home/user/craftify-deploy-lab/setup.sh
```

Sudo password: `user@123!`

Wait for setup to complete. The pipeline will trigger automatically and immediately get stuck. Note down the instance IP and key path printed in the terminal.

---

## Environment Details

- **Region:** `us-west-2`
- **Pipeline name:** `craftify-release-pipeline`
- **CodeDeploy application:** `craftify-backend`
- **Deployment group:** `craftify-deployment-group`
- **EC2 instance name:** `craftify-app-server`
- **Key pair:** `craftify-deploy-key`
- **Key path:** `/home/user/craftify-deploy-lab/craftify-deploy-key.pem`
- **Instance IP:** printed in terminal after setup

SSH into the instance using:

```bash
ssh -i /home/user/craftify-deploy-lab/craftify-deploy-key.pem ec2-user@<INSTANCE-IP>
```

---

## Tasks

### Task 1: Diagnose the Stuck Pipeline

Open the CodePipeline console and find `craftify-release-pipeline`. The Deploy stage will show it is waiting. Navigate to the CodeDeploy deployment to understand why it is stuck.

### Task 2: Fix the Issue on the EC2 Instance

SSH into `craftify-app-server` and diagnose the CodeDeploy agent status. Fix the issue so the agent is running and enabled to start on reboot.

### Task 3: Re-trigger the Pipeline

Once the agent is running, re-trigger the pipeline from the console or using:

```bash
aws codepipeline start-pipeline-execution \
  --name craftify-release-pipeline \
  --region us-west-2
```

### Task 4: Verify the Deployment

Wait for the pipeline to complete successfully. Then verify the deployment by accessing the application:

```bash
curl http://<INSTANCE-IP>/index.html
```

The response should contain `Craftify Learning Platform` and `Version 2.1.3`.

---

## Notes

- Wait 3-4 minutes after setup before SSHing in — the EC2 instance needs time to complete initialization.
- The CodeDeploy agent must be both running and enabled on boot to pass the testcases.
- Use `us-west-2` for all CLI commands that require a region.