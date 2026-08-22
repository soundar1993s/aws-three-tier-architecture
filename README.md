# AWS 3-Tier Architecture

## Building Scalable, Secure, and High-Performance Web Applications with AWS

This project demonstrates the deployment of a scalable, highly available, and secure Python Flask web application using a **3-Tier Architecture on Amazon Web Services (AWS)**.

The architecture separates the application into three independent layers:

- **Presentation Layer** – Nginx running on Amazon EC2
- **Application Layer** – Python Flask API running on private EC2 instances
- **Database Layer** – Amazon RDS MySQL

The solution also uses Application Load Balancers, Amazon VPC, NAT Gateway, Internet Gateway, Route Tables, and Security Groups to provide scalability, availability, and network security.

---

## Architecture Overview

```text
                         INTERNET
                            |
                            v
                 +----------------------+
                 |   PUBLIC ALB         |
                 |   HTTP : 80          |
                 +----------+-----------+
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          +-------------+       +-------------+
          | Web EC2 - A |       | Web EC2 - B |
          |   Nginx     |       |   Nginx     |
          |  Public-A   |       |  Public-B   |
          +------+------+       +------+------+
                 |                     |
                 +----------+----------+
                            |
                            v
                 +----------------------+
                 |   INTERNAL ALB       |
                 |   HTTP : 5000        |
                 +----------+-----------+
                            |
                 +----------+----------+
                 |                     |
                 v                     v
          +-------------+       +-------------+
          | App EC2 - A |       | App EC2 - B |
          |   Flask     |       |   Flask     |
          |  Private-A  |       |  Private-B  |
          +------+------+       +------+------+
                 |                     |
                 +----------+----------+
                            |
                            | MySQL : 3306
                            v
                 +----------------------+
                 |     RDS MySQL        |
                 |   Private DB Tier    |
                 +----------------------+
