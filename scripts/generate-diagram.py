#!/usr/bin/env python3
"""
Generate Axelar Kubernetes Architecture Diagram
"""

import os
from diagrams import Diagram, Cluster, Edge
from diagrams.k8s.compute import Deployment, Pod, ReplicaSet
from diagrams.k8s.network import Service, Ingress
from diagrams.k8s.storage import PersistentVolume, PersistentVolumeClaim
from diagrams.k8s.rbac import ServiceAccount, ClusterRole
from diagrams.k8s.others import CRD
from diagrams.onprem.gitops import ArgoCD
from diagrams.onprem.monitoring import Prometheus, Grafana
from diagrams.programming.language import Go
from diagrams.generic.blank import Blank

def generate_architecture_diagram():
    """Generate the main architecture diagram"""
    
    # Ensure diagrams directory exists
    os.makedirs("diagrams", exist_ok=True)
    
    with Diagram("Axelar Kubernetes Architecture", 
                 filename="diagrams/axelar-architecture-diagram",
                 show=False,
                 direction="TB"):
        
        # GitOps Layer
        with Cluster("GitOps Layer"):
            argocd = ArgoCD("ArgoCD")
            git_repo = Blank("Git Repository")
            
        # Operator Layer
        with Cluster("Operator Layer"):
            operator = Deployment("Axelar Operator")
            crds = CRD("AxelarNode CRD")
            rbac = ServiceAccount("RBAC")
            
        # Application Layer
        with Cluster("Axelar Testnet"):
            with Cluster("Node Components"):
                axelar_node = Deployment("Axelar Node")
                node_service = Service("Node Service")
                node_pvc = PersistentVolumeClaim("Node Data")
                
        with Cluster("Axelar Mainnet"):
            with Cluster("Validator Components"):
                validator = Deployment("Validator")
                validator_service = Service("Validator Service")
                validator_pvc = PersistentVolumeClaim("Validator Data")
                
        # Monitoring Layer
        with Cluster("Monitoring"):
            prometheus = Prometheus("Prometheus")
            grafana = Grafana("Grafana")
            
        # Connections
        git_repo >> argocd
        argocd >> operator
        argocd >> axelar_node
        argocd >> validator
        
        operator >> crds
        rbac >> operator
        
        axelar_node >> node_service
        axelar_node >> node_pvc
        
        validator >> validator_service
        validator >> validator_pvc
        
        node_service >> prometheus
        validator_service >> prometheus
        prometheus >> grafana

def generate_operator_workflow_diagram():
    """Generate operator workflow diagram"""
    
    with Diagram("Axelar Operator Workflow",
                 filename="diagrams/operator-workflow-diagram", 
                 show=False,
                 direction="LR"):
        
        # User creates AxelarNode
        user = Blank("User")
        axelar_node_cr = CRD("AxelarNode CR")
        
        # Operator processes
        operator = Go("Axelar Operator")
        
        # Generated resources
        with Cluster("Generated Resources"):
            deployment = Deployment("Node Deployment")
            service = Service("Node Service")
            pvc = PersistentVolumeClaim("Storage")
            configmap = Blank("ConfigMap")
            
        # Connections
        user >> axelar_node_cr
        axelar_node_cr >> operator
        operator >> deployment
        operator >> service
        operator >> pvc
        operator >> configmap

if __name__ == "__main__":
    print("Generating Axelar Kubernetes architecture diagrams...")
    
    try:
        generate_architecture_diagram()
        print("✅ Main architecture diagram generated")
        
        generate_operator_workflow_diagram()
        print("✅ Operator workflow diagram generated")
        
        print("📁 Diagrams saved to diagrams/ directory")
        
    except Exception as e:
        print(f"❌ Error generating diagrams: {e}")
        exit(1)
