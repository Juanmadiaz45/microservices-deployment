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

---

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

## Conclusion

The combination of Circuit Breaker and Health Endpoint Monitoring patterns improves the reliability, recoverability, and overall user experience of the microservices-based system. These patterns are foundational for operating distributed services in production environments.
