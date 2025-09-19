# GitHub Actions Secrets Setup

This document explains how to configure the required secrets for the CI/CD pipeline.

## Required Secrets

### Docker Hub Credentials

You need to add the following secret to your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add the following secret:

**Name:** `DOCKERHUB_TOKEN`  
**Value:** Your Docker Hub access token (get it from Docker Hub security settings)

⚠️ **IMPORTANT**: Never commit credentials directly to the repository!

### How to Generate a Docker Hub Access Token

1. Log in to [Docker Hub](https://hub.docker.com)
2. Go to **Account Settings** → **Security**
3. Click **New Access Token**
4. Give it a descriptive name (e.g., "GitHub Actions CI/CD")
5. Select the appropriate permissions (Read, Write, Delete)
6. Click **Generate**
7. Copy the token immediately (it won't be shown again)

## Optional Secrets for Deployment

If you want to enable automatic deployment via SSH, add these secrets:

- **`DEPLOY_HOST`**: The hostname or IP address of your deployment server
- **`DEPLOY_USER`**: The SSH username for deployment
- **`DEPLOY_SSH_KEY`**: The private SSH key for authentication

### Generate SSH Key for Deployment

```bash
# Generate a new SSH key pair
ssh-keygen -t ed25519 -f deploy_key -C "github-actions"

# Add the public key to your server
ssh-copy-id -i deploy_key.pub user@your-server

# Copy the private key content for GitHub secret
cat deploy_key
```

## Environment Variables in Workflows

The workflows use the following environment variables:

- `DOCKER_IMAGE`: amrhym/dep
- `DOCKER_TAG`: latest (or branch-specific tags)
- `RUBY_VERSION`: 3.4.4
- `NODE_VERSION`: 20

## Testing the Pipeline

After setting up the secrets:

1. Make a commit to trigger the workflow
2. Go to the **Actions** tab in your repository
3. Monitor the workflow execution
4. Check Docker Hub for the published image

## Security Best Practices

1. **Rotate tokens regularly**: Change your Docker Hub token every 3-6 months
2. **Use minimal permissions**: Only grant the permissions needed
3. **Monitor access logs**: Check Docker Hub and GitHub for unauthorized access
4. **Use environment-specific tokens**: Different tokens for dev/staging/production
5. **Never log secrets**: Ensure workflows don't echo secret values

## Troubleshooting

### Authentication Failed
- Verify the token is correctly copied (no extra spaces)
- Check the token hasn't expired
- Ensure the username is correct (amrhym)

### Build Failed
- Check the Dockerfile path is correct
- Verify all build arguments are provided
- Review the build logs for specific errors

### Push Failed
- Confirm you have push access to the repository
- Check Docker Hub rate limits
- Verify the image name is correct

## Manual Docker Build and Push

If you need to manually build and push:

```bash
# Build the image
docker build -t amrhym/dep:latest -f docker/Dockerfile .

# Login to Docker Hub
docker login -u amrhym

# Push the image
docker push amrhym/dep:latest
```