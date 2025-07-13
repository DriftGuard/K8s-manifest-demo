#!/bin/bash

# DriftGuard Kubernetes Manifests Setup Script
# This script deploys all the sample applications and infrastructure

set -e

echo "🚀 DriftGuard Kubernetes Manifests Setup"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Kubernetes cluster connection verified"
}

# Deploy namespaces
deploy_namespaces() {
    log_info "Deploying namespaces..."
    kubectl apply -f namespaces/
    log_success "Namespaces deployed"
}

# Deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying infrastructure components..."
    kubectl apply -f infrastructure/
    log_success "Infrastructure components deployed"
}

# Deploy applications
deploy_applications() {
    log_info "Deploying applications..."
    
    # Deploy nginx app
    log_info "Deploying nginx application..."
    kubectl apply -f applications/nginx-app/
    
    # Deploy redis app
    log_info "Deploying redis application..."
    kubectl apply -f applications/redis-app/
    
    # Deploy postgres app
    log_info "Deploying postgres application..."
    kubectl apply -f applications/postgres-app/
    
    log_success "All applications deployed"
}

# Deploy monitoring
deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    
    # Deploy Prometheus
    log_info "Deploying Prometheus..."
    kubectl apply -f monitoring/prometheus/
    
    # Deploy Grafana
    log_info "Deploying Grafana..."
    kubectl apply -f monitoring/grafana/
    
    log_success "Monitoring stack deployed"
}

# Wait for deployments to be ready
wait_for_deployments() {
    log_info "Waiting for deployments to be ready..."
    
    # Wait for nginx
    kubectl wait --for=condition=available --timeout=300s deployment/nginx-app -n driftguard-demo
    
    # Wait for redis
    kubectl wait --for=condition=available --timeout=300s deployment/redis-app -n driftguard-demo
    
    # Wait for postgres
    kubectl wait --for=condition=available --timeout=300s deployment/postgres-app -n driftguard-demo
    
    # Wait for prometheus
    kubectl wait --for=condition=available --timeout=300s deployment/prometheus -n monitoring
    
    # Wait for grafana
    kubectl wait --for=condition=available --timeout=300s deployment/grafana -n monitoring
    
    log_success "All deployments are ready"
}

# Show deployment status
show_status() {
    log_info "Deployment Status:"
    echo
    
    log_info "Namespaces:"
    kubectl get namespaces | grep -E "(driftguard-demo|monitoring)"
    echo
    
    log_info "Applications in driftguard-demo:"
    kubectl get all -n driftguard-demo
    echo
    
    log_info "Monitoring in monitoring namespace:"
    kubectl get all -n monitoring
    echo
    
    log_info "Services:"
    kubectl get services -n driftguard-demo
    kubectl get services -n monitoring
    echo
    
    log_info "ConfigMaps:"
    kubectl get configmaps -n driftguard-demo
    kubectl get configmaps -n monitoring
    echo
    
    log_info "Secrets:"
    kubectl get secrets -n driftguard-demo
    kubectl get secrets -n monitoring
    echo
    
    log_info "PersistentVolumeClaims:"
    kubectl get pvc -n driftguard-demo
    kubectl get pvc -n monitoring
}

# Show access information
show_access_info() {
    log_info "Access Information:"
    echo
    
    log_info "Nginx Application:"
    echo "  - Internal: nginx-service.driftguard-demo.svc.cluster.local:80"
    echo "  - NodePort: <node-ip>:30080"
    echo "  - Ingress: nginx.driftguard-demo.local (if ingress controller is installed)"
    echo
    
    log_info "Redis Application:"
    echo "  - Internal: redis-service.driftguard-demo.svc.cluster.local:6379"
    echo
    
    log_info "PostgreSQL Application:"
    echo "  - Internal: postgres-service.driftguard-demo.svc.cluster.local:5432"
    echo
    
    log_info "Prometheus:"
    echo "  - Internal: prometheus-service.monitoring.svc.cluster.local:9090"
    echo "  - Ingress: prometheus.driftguard-demo.local (if ingress controller is installed)"
    echo
    
    log_info "Grafana:"
    echo "  - Internal: grafana-service.monitoring.svc.cluster.local:3000"
    echo "  - Ingress: grafana.driftguard-demo.local (if ingress controller is installed)"
    echo "  - Default credentials: admin/admin123"
    echo
    
    log_info "DriftGuard API:"
    echo "  - Health check: http://localhost:8080/health"
    echo "  - API docs: http://localhost:8080/api/v1/drift-records"
    echo "  - Metrics: http://localhost:8080/metrics"
}

# Cleanup function
cleanup() {
    log_warning "Cleaning up all resources..."
    
    # Delete monitoring
    kubectl delete -f monitoring/ --ignore-not-found=true
    
    # Delete applications
    kubectl delete -f applications/ --ignore-not-found=true
    
    # Delete infrastructure
    kubectl delete -f infrastructure/ --ignore-not-found=true
    
    # Delete namespaces
    kubectl delete -f namespaces/ --ignore-not-found=true
    
    log_success "Cleanup completed"
}

# Main function
main() {
    case "${1:-deploy}" in
        "deploy")
            check_kubectl
            deploy_namespaces
            deploy_infrastructure
            deploy_applications
            deploy_monitoring
            wait_for_deployments
            show_status
            show_access_info
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup
            ;;
        "help")
            echo "Usage: $0 [deploy|status|cleanup|help]"
            echo "  deploy  - Deploy all resources (default)"
            echo "  status  - Show deployment status"
            echo "  cleanup - Remove all resources"
            echo "  help    - Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 