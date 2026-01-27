$REGION = "il-central-1"
Write-Host "Fetching Terraform Outputs..."
$SERVER_REPO_URL = terraform output -raw ecr_repository_url_server
$CLIENT_REPO_URL = terraform output -raw ecr_repository_url_client
# ECR Base matches the domain part
$ECR_BASE = $SERVER_REPO_URL.Split('/')[0]

Write-Host "Server Repo: $SERVER_REPO_URL"
Write-Host "Client Repo: $CLIENT_REPO_URL"

# Login
Write-Host "Logging into ECR..."
cmd /c "aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_BASE"
if ($LASTEXITCODE -ne 0) { Write-Error "Login Failed"; exit 1 }

# Update Secret
Write-Host "Updating K8s Secret..."
$token = aws ecr get-login-password --region $REGION
kubectl create secret docker-registry regcred --docker-server=$ECR_BASE --docker-username=AWS --docker-password=$token --namespace=knowledge-repo-dev --dry-run=client -o yaml | kubectl apply -f -

# Build & Push Server
Write-Host "Building Server..."
docker build -t "$SERVER_REPO_URL`:latest" ../../knowledge_repo_server
docker push "$SERVER_REPO_URL`:latest"

# Build & Push Client
Write-Host "Building Client..."
docker build -t "$CLIENT_REPO_URL`:latest" ../../knowledge_repo_client
docker push "$CLIENT_REPO_URL`:latest"

# Restart
Write-Host "Restarting Deployments..."
kubectl rollout restart deployment knowledge-repo-server -n knowledge-repo-dev
kubectl rollout restart deployment knowledge-repo-client -n knowledge-repo-dev

Write-Host "Deployment Complete!"
