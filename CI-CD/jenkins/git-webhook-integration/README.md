# Jenkins Git Webhook Integration

This folder contains a simple Node.js Express application that can be built into a Docker image and deployed on a local server by Jenkins whenever a commit is pushed to the Git repository.

## Application routes

- `GET /` - application message
- `GET /health` - health check used by Jenkins

## Run locally with Node.js

```bash
npm install
npm start
```

Open:

```bash
http://localhost:3000
http://localhost:3000/health
```

## Run locally with Docker

```bash
docker build -t jenkins-webhook-node-app:latest .
docker run -d --name jenkins-webhook-node-app -p 3000:3000 jenkins-webhook-node-app:latest
```

Or use Docker Compose:

```bash
docker compose up -d --build
```

## Jenkins webhook setup

1. Install Jenkins plugins:
   - Git
   - GitHub
   - Pipeline

2. Create a Jenkins Pipeline job.

3. In Pipeline configuration, choose:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: your Git repository URL
   - Script Path: `CI-CD/jenkins/git-webhook-integration/Jenkinsfile`

4. In the GitHub repository, add a webhook:
   - Payload URL: `http://<jenkins-server-url>/github-webhook/`
   - Content type: `application/json`
   - Event: `Just the push event`

5. Make sure the Jenkins server has Docker installed and the Jenkins user can run Docker commands.

After this, every pushed commit will trigger Jenkins, run tests, build the Docker image, remove the old local container, start the new container, and check `/health`.
