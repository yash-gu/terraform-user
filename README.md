
<img width="944" height="535" alt="image" src="https://github.com/user-attachments/assets/ea4dfee9-fa21-4534-afe7-5e81021c4eac" />
 Uber-Scale System Design & Infrastructure (IaC) 🚗💨

A high-performance, distributed backend architecture designed to handle real-time ride-sharing logistics at scale. This project combines deep **System Design** principles with automated **Infrastructure as Code (IaC)** using Terraform on AWS.

## 🏗️ The Architecture

I mapped out the system to handle millions of concurrent requests, focusing on low-latency matching and high-availability data streams.

![Uber System Design Architecture](./architecture-diagram.png) 
> *Tip: Save your architecture image as 'architecture-diagram.png' in your repository root to display it here.*

### Key Architectural Decisions:
* **Microservices Orchestration:** Deployed via **Amazon EKS (Kubernetes)** for seamless scaling and management.
* **Event-Driven Communication:** Utilizing **Apache Kafka (Amazon MSK)** to decouple the matching engine from analytics and billing.
* **Hybrid Data Layer:** * **PostgreSQL (RDS):** Ensuring ACID compliance for user profiles and financial transactions.
    * **NoSQL (DynamoDB/Cassandra):** Handling high-velocity geospatial data and trip telemetry.
    * **Redis (ElastiCache):** For lightning-fast caching of driver locations and session data.

---

