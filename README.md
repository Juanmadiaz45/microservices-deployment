# Microservices Deployment

This repository contains Infrastructure as Code (IaC) for implementing, managing, and monitoring a microservices architecture.

## Repository Structure

### Terraform

The `terraform/` folder contains Terraform configurations to provision the necessary cloud infrastructure. It includes:

- **Infrastructure Modules**:
  - `function-app`: Azure Function Apps implementation, including a circuit breaker
  - `microservices-vm`: Virtual machines for deploying microservices
  - `networking`: Virtual network configuration and related resources
  - `vms`: Infrastructure for CI/CD and monitoring services

### Ansible

The `ansible/` folder contains Ansible configurations to automate the deployment and configuration of services. It includes:

- **Roles**:

  - `docker`: Docker installation and configuration
  - `jenkins`: Jenkins CI/CD server configuration
  - `microservices`: Microservices deployment using Docker Compose
  - `sonarqube`: SonarQube configuration for code quality analysis

- **Playbooks**:
  - Automated deployment of Jenkins and SonarQube
  - Docker installation
  - Container deployment

### Documentation

The `docs/` folder contains project documentation, including results reports.

## Prerequisites

- Terraform >= 0.14
- Ansible >= 2.9
- Azure Account
- Docker and Docker Compose

## Usage

1. Configure variables in `terraform/terraform.tfvars`
2. Provision infrastructure with Terraform
   ```bash
   cd terraform
   terraform init
   terraform apply
   ```
3. Run Ansible playbooks to configure services
   ```bash
   cd ansible
   ./deploy.sh
   ```

## System Components

- **CI/CD**: Jenkins for continuous integration and deployment
- **Code Analysis**: SonarQube for quality testing
- **Resilience**: Circuit Breaker implemented with Azure Functions
- **Containers**: Docker for microservices management
