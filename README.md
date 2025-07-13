# Kubernetes Manifests Repository for [DriftGuard](https://github.com/driftguard/driftGuard/)

This repository contains sample Kubernetes manifests that can be used to test and demonstrate DriftGuard's configuration drift detection capabilities.

## Purpose

This repository serves as the **"desired state"** that DriftGuard monitors against. DriftGuard will:

1. Clone this repository
2. Parse the Kubernetes manifests
3. Compare them with the live state in your Kubernetes cluster
4. Detect any configuration drift between Git and live state

## Repository Structure

```
k8s-manifests/
├── README.md                   
├── namespaces/                  # Namespace definitions
│   ├── driftguard-demo.yaml
│   └── monitoring.yaml
├── applications/                # Application deployments
│   ├── nginx-app/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── secret.yaml
│   ├── redis-app/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   └── postgres-app/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── pvc.yaml
├── monitoring/                  # Monitoring stack
│   ├── prometheus/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   └── grafana/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── configmap.yaml
└── infrastructure/              # Infrastructure components
    ├── ingress-controller.yaml
    └── storage-class.yaml
```

## Quick Start

### 1. Clone This Repository

```bash
git clone <your-repo-url> k8s-manifests
cd k8s-manifests
```

### 2. Configure DriftGuard

Update your DriftGuard configuration (`backend/configs/config.yaml`):

```yaml
git:
  repository_url: "file:///path/to/your/k8s-manifests" # Local file path
  # OR for remote repository:
  # repository_url: "https://github.com/your-username/k8s-manifests.git"
  default_branch: main
  clone_timeout: 5m
  pull_timeout: 2m

kubernetes:
  namespaces: ["driftguard-demo", "monitoring"]
  resources:
    [
      "deployments",
      "services",
      "configmaps",
      "secrets",
      "persistentvolumeclaims",
    ]
```

### 3. Deploy Initial State

```bash
# Create namespaces
kubectl apply -f namespaces/

# Deploy applications
kubectl apply -f applications/nginx-app/
kubectl apply -f applications/redis-app/
kubectl apply -f applications/postgres-app/

# Deploy monitoring
kubectl apply -f monitoring/
```

### 4. Start DriftGuard

```bash
cd backend
go run cmd/controller/main.go --config=configs/config.yaml
```

### 5. Verify No Drift

```bash
# Check that no drift is detected initially
curl http://localhost:8080/api/v1/drift-records
```

## 🧪 Testing Drift Detection

### Test 1: Scaling Drift

```bash
# Scale nginx deployment to create drift
kubectl scale deployment nginx-app -n driftguard-demo --replicas=5

# Trigger drift analysis
curl -X POST http://localhost:8080/api/v1/analyze

# Check for drift detection
curl http://localhost:8080/api/v1/drift-records/active
```

### Test 2: Image Version Drift

```bash
# Change nginx image version
kubectl set image deployment/nginx-app nginx=nginx:1.25 -n driftguard-demo

# Trigger analysis
curl -X POST http://localhost:8080/api/v1/analyze

# Check drift details
curl http://localhost:8080/api/v1/drift-records/Deployment:driftguard-demo:nginx-app
```

### Test 3: Environment Variable Drift

```bash
# Add environment variable
kubectl set env deployment/nginx-app NGINX_ENV=staging -n driftguard-demo

# Trigger analysis
curl -X POST http://localhost:8080/api/v1/analyze
```

### Test 4: Resource Drift

```bash
# Change resource limits
kubectl patch deployment nginx-app -n driftguard-demo -p '{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "nginx",
          "resources": {
            "requests": {"memory": "128Mi", "cpu": "500m"},
            "limits": {"memory": "256Mi", "cpu": "1000m"}
          }
        }]
      }
    }
  }
}'

# Trigger analysis
curl -X POST http://localhost:8080/api/v1/analyze
```

### Test 5: Configuration Drift

```bash
# Update ConfigMap
kubectl patch configmap nginx-config -n driftguard-demo -p '{
  "data": {
    "nginx.conf": "server { listen 80; server_name localhost; location / { root /usr/share/nginx/html; index index.html index.htm; } }"
  }
}'

# Trigger analysis
curl -X POST http://localhost:8080/api/v1/analyze
```

## Resolving Drift

### Method 1: Revert to Git State

```bash
# Re-apply manifests from Git
kubectl apply -f applications/nginx-app/

# Trigger analysis
curl -X POST http://localhost:8080/api/v1/analyze

# Check for resolution
curl http://localhost:8080/api/v1/drift-records/resolved
```

### Method 2: Manual Revert

```bash
# Manually revert changes
kubectl scale deployment nginx-app -n driftguard-demo --replicas=3
kubectl set image deployment/nginx-app nginx=nginx:1.24 -n driftguard-demo

# Trigger analysis
curl -X POST http://localhost:8080/api/v1/analyze
```

## Monitoring Drift

### Check Active Drifts

```bash
curl http://localhost:8080/api/v1/drift-records/active
```

### Check Resolved Drifts

```bash
curl http://localhost:8080/api/v1/drift-records/resolved
```

### Get Statistics

```bash
curl http://localhost:8080/api/v1/statistics
```

### Get Specific Resource Drift

```bash
# Format: Kind:namespace:name
curl http://localhost:8080/api/v1/drift-records/Deployment:driftguard-demo:nginx-app
curl http://localhost:8080/api/v1/drift-records/Service:driftguard-demo:nginx-service
curl http://localhost:8080/api/v1/drift-records/ConfigMap:driftguard-demo:nginx-config
```

## Advanced Testing Scenarios

### Multi-Environment Testing

Create different branches for different environments:

```bash
# Create environment branches
git checkout -b staging
git checkout -b production

# Modify manifests for each environment
# Update resource limits, replica counts, etc.

# Configure DriftGuard to monitor specific branches
```

### Complex Drift Scenarios

1. **Secret Rotation**: Update secrets in cluster but not in Git
2. **Label Changes**: Add/remove labels from resources
3. **Annotation Changes**: Modify annotations
4. **Volume Changes**: Change volume mounts or storage classes
5. **Service Changes**: Modify service ports or selectors

### Performance Testing

```bash
# Create many resources to test performance
for i in {1..50}; do
  kubectl create deployment test-app-$i --image=nginx:1.24 -n driftguard-demo
done

# Trigger analysis and monitor performance
curl -X POST http://localhost:8080/api/v1/analyze
```

## Customization

### Adding New Applications

1. Create a new directory in `applications/`
2. Add your Kubernetes manifests
3. Update the namespace if needed
4. Commit and push to your repository
5. DriftGuard will automatically detect the new resources

### Modifying Existing Applications

1. Edit the manifests in this repository
2. Commit and push changes
3. Apply changes to your cluster: `kubectl apply -f applications/your-app/`
4. DriftGuard will detect any differences

### Environment-Specific Configurations

Create environment-specific overlays:

```
applications/
├── nginx-app/
│   ├── base/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── overlays/
│   │   ├── development/
│   │   ├── staging/
│   │   └── production/
```

## Best Practices

### 1. Git Workflow

- Use feature branches for changes
- Require pull request reviews
- Use semantic commit messages
- Tag releases for production deployments

### 2. Manifest Organization

- Group related resources together
- Use consistent naming conventions
- Include comments for complex configurations
- Version your manifests

### 3. DriftGuard Integration

- Monitor all critical namespaces
- Set up alerts for drift detection
- Regular drift analysis scheduling
- Document drift resolution procedures

### 4. Security

- Use RBAC for cluster access
- Rotate secrets regularly
- Audit drift records
- Monitor for unauthorized changes

## Troubleshooting

### Common Issues

1. **Repository Access**: Ensure DriftGuard can access your Git repository
2. **Namespace Mismatch**: Verify namespaces in manifests match cluster namespaces
3. **Resource Types**: Check that DriftGuard is configured to monitor the right resource types
4. **Permissions**: Ensure DriftGuard has proper Kubernetes permissions

### Debug Commands

```bash
# Check DriftGuard logs
kubectl logs -f deployment/driftguard -n driftguard

# Verify Git repository access
git ls-remote <your-repo-url>

# Check Kubernetes permissions
kubectl auth can-i get deployments --all-namespaces

# Test manifest parsing
kubectl apply --dry-run=client -f applications/nginx-app/
```

## 📚 Additional Resources

- [DriftGuard Documentation](https://github.com/DriftGuard/DriftGuard/blob/main/README.md)
- [Kubernetes Manifests Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [GitOps Principles](https://www.gitops.tech/)
- [Configuration Drift Management](https://www.cncf.io/blog/2020/12/17/solving-configuration-drift-using-gitops-with-argo-cd/)

## 🤝 Contributing

Feel free to contribute to this repository by:

- Adding new sample applications
- Improving manifest configurations
- Adding environment-specific examples
- Enhancing documentation

---

## CODEOWNERS

[Arpit Srivastava](https://github.com/Arpit529Srivastava)
[Shreyansh Pathak](https://github.com/Shrey327)

**Happy Drift Detection! **
