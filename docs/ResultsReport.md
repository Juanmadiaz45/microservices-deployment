# Branching Strategies

## Development Branching Strategy

Our development branching strategy follows a simplified Git Flow approach optimized for microservices:

### Main Branches

- **main**: Production-ready code that has passed all tests and reviews
- **develop**: Integration branch for features completed and ready for testing

### Supporting Branches

- **feature/[feature-name]**: For developing new features, branched from and merged back to develop
- **bugfix/[bug-description]**: For fixing bugs in development, branched from develop
- **hotfix/[hotfix-description]**: For critical production fixes, branched from main and merged to both main and develop

### Workflow

1. Developers create feature branches from develop
2. Code reviews are conducted via Pull Requests
3. CI pipeline runs tests on each PR
4. After approval, features are merged into develop
5. Develop is periodically merged to main after QA testing
6. Releases are tagged in main with semantic versioning (v1.0.0)

## Operations Branching Strategy

Our operations branching strategy employs GitOps principles to manage infrastructure and deployments:

### Environment Branches

- **env/dev**: Configuration for development environment
- **env/staging**: Configuration for staging/pre-production environment
- **env/prod**: Configuration for production environment

### Infrastructure Branches

- **infra/[component]**: For infrastructure code changes (Terraform, Ansible)
- **config/[service-name]**: For service-specific configuration changes

### Deployment Workflow

1. Infrastructure changes follow PR process with mandatory reviews
2. Successful merges to environment branches trigger automated deployments
3. Promotion between environments follows: dev → staging → prod
4. Each deployment is tagged with environment and timestamp
5. Rollbacks use previous stable tags when necessary

This dual-strategy approach enables rapid development while maintaining operational stability across our microservices architecture.

## Architecture

Take a look at the components diagram that describes them and their interactions.
![microservice-app-example](/arch-img/Microservices.png)

---

# Patterns

## 1. Circuit Breaker Pattern

### Purpose

The Circuit Breaker pattern prevents a service from making repeated requests to a failing or slow downstream dependency. This avoids resource exhaustion and gives the failing service time to recover.

### Implementation

- The Circuit Breaker is implemented using a Node.js library (Opossum).
- It is deployed inside an Azure Function that acts as a smart proxy between clients and backend microservices.
- Requests to microservices go through this proxy using the following URL structure:

```bash
https://<function-app>.azurewebsites.net/api/{service}/{*path}
```

- Each microservice (e.g., `auth`, `users`, `todos`, `frontend`) is mapped to a specific port on a virtual machine.
- The proxy sends requests to the target service using Axios, wrapped in a circuit breaker instance with configurable thresholds and timeouts.
- If a service fails multiple times consecutively, the circuit enters an OPEN state and returns a fallback response without attempting new requests.
- After a defined reset timeout, the breaker allows limited requests (HALF-OPEN) to test recovery. If successful, the circuit returns to CLOSED.

### Benefits

- Prevents backend overload by cutting off repeated failing requests
- Enables graceful degradation by providing fallback responses
- Improves system responsiveness and user experience
- Protects overall system health in the presence of partial failures

## 2. Health Endpoint Monitoring Pattern

### Purpose

The Health Endpoint Monitoring pattern allows systems to monitor the health status of components by exposing a dedicated endpoint, enabling automated recovery, alerting, or load balancing decisions.

### Implementation

- Each microservice exposes a `/health` endpoint returning `200 OK` if healthy, or an error code otherwise.
- Docker Compose defines health checks for each relevant container.

**Here’s the code** (health checks configured in the container definitions).

- Ansible is used to detect and restart unhealthy containers automatically after deployment.

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:<port>/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

- The Circuit Breaker indirectly uses these health checks by observing whether requests to `/health` succeed or fail.
- A series of failed health check responses (e.g., timeouts, 5xx errors) causes the breaker to open for that service.

### Benefits

- Enables proactive monitoring and automatic restarts
- Provides visibility into service status
- Integrates with deployment and orchestration tools
- Supports system observability and resilience strategies

---

# CI/CD Pipelines

The application uses a comprehensive CI/CD approach with GitHub Actions for continuous integration and Jenkins for continuous deployment.

## Development Pipelines (GitHub Actions)

The development workflow is powered by GitHub Actions which automate the build and publishing process:

1. **Build Docker Images Pipeline** (`.github/workflows/docker-build.yml`)

   - **Trigger**: Automatically runs when a pull request is merged to the main branch
   - **Purpose**: Builds Docker images for all microservices (auth-api, frontend, log-message-processor, todos-api, users-api)
   - **Process**: For each service, it runs `docker build` to create optimized container images

2. **Push Docker Images Pipeline** (`.github/workflows/docker-push.yml`)
   - **Trigger**: Automatically runs after the "Build Docker Images" workflow completes successfully
   - **Purpose**: Tags the built images and pushes them to Docker Hub
   - **Process**: Uses Docker Hub credentials from GitHub Secrets, tags each image with the repository name, and pushes them to the registry

This two-step process ensures that only successfully built images from merged code are published to the container registry.

## Infrastructure Pipelines (Jenkins)

For deployment and infrastructure management, two Jenkins pipelines are provided:

1. **Full Deployment Pipeline** (`Jenkinsfile`)

   - **Purpose**: Deploys the entire application stack to the production environment
   - **Key Features**:
     - Connects to deployment server via SSH
     - Pulls the latest Docker images from Docker Hub
     - Updates the docker-compose configuration
     - Performs a controlled restart of all services
     - Runs health checks to verify successful deployment

2. **Rolling Update Pipeline** (`Jenkinsfile.rolling`)
   - **Purpose**: Enables targeted updates of specific microservices
   - **Key Features**:
     - Parameterized build that accepts a service name to update
     - Options to update all services or a single component
     - Maintains system stability by only restarting the specified services
     - Performs post-deployment health checks

---

# Infrastructure

The system infrastructure is automated using Terraform for Azure resource provisioning and Ansible for application configuration and deployment.

## Azure Resources (Terraform)

### Virtual Machines

The system uses three types of virtual machines in Azure, each with a specific purpose:

1. **Microservices VM**

   - **Purpose**: Hosts Docker containers for the microservices
   - **Specifications**: Ubuntu 22.04 LTS, Standard_F1s size
   - **Exposed ports**:
     - 8000: Authentication API
     - 8080: Frontend
     - 8082: Tasks API (TODOs)
     - 8083: Users API
     - 6379: Redis
     - 9411: Zipkin (tracing)

2. **CI/CD VM**

   - **Purpose**: Hosts Jenkins and SonarQube for continuous integration and delivery
   - **Specifications**: Ubuntu 22.04 LTS, Standard_F1s size
   - **Services**:
     - Jenkins (port 8080)
     - SonarQube (port 9000)

3. **Monitoring VM**
   - **Purpose**: Hosts monitoring tools (Prometheus/Grafana)
   - **Specifications**: Ubuntu 22.04 LTS, Standard_F1s size
   - **Services**:
     - Prometheus (port 9090)
     - Grafana (port 3000)

### Network Components

- **Virtual Network**: Configured with address space 10.0.0.0/16
- **Subnet**: Configured with address space 10.0.2.0/24
- **Network Security Groups**: Configured for each virtual machine with specific rules for the corresponding services

### Azure Functions

- **Circuit Breaker Function**:
  - Implements the Circuit Breaker pattern using an Azure Function
  - Runtime: Node.js v20
  - Uses the Opossum library for circuit breaker implementation
  - Acts as a smart proxy between clients and microservices

## Configuration and Deployment (Ansible)

### Virtual Machine Preparation

- **Docker Installation**: A dedicated playbook is used to install Docker and Docker Compose on all virtual machines

### Application Deployment

1. **Microservices Deployment**

   - Uses Docker Compose to orchestrate containers
   - Containers include health checks for self-recovery
   - Configures inter-service communication through environment variables

2. **CI/CD Configuration**

   - **Jenkins**:

     - Deployed as a Docker container with Docker-in-Docker (DinD)
     - Configuration as Code (CasC) for automated setup
     - Multibranch Pipeline for GitHub integration

   - **SonarQube**:
     - Deployed with PostgreSQL in Docker containers
     - Configured with webhooks to integrate with Jenkins
     - API token automatically generated for Jenkins

3. **Monitoring**
   - Prometheus for metrics collection
   - Grafana for data visualization

### Operations Automation

- **Health Checks**: Ansible monitors and automatically restarts containers that fail health checks
- **Certificate Renewal**: Automated SSL certificate management
- **Disaster Recovery**: Scripts for backup/restore of critical data

This infrastructure architecture provides a complete environment for the development, deployment, and operation of the microservices application, with emphasis on resilience, observability, and automation.
