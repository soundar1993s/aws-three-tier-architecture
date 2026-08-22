# AWS 3-Tier Architecture

## Building Scalable, Secure, and High-Performance Web Applications with AWS

This project demonstrates the deployment of a scalable, highly
available, and secure Python Flask web application using a 3-Tier
Architecture on Amazon Web Services (AWS).

The architecture separates the application into:

-   **Presentation Layer** -- Nginx on Amazon EC2
-   **Application Layer** -- Python Flask on private EC2 instances
-   **Database Layer** -- Amazon RDS MySQL

It also uses Amazon VPC, Internet Gateway, NAT Gateway, Route Tables,
Security Groups, and Application Load Balancers.

------------------------------------------------------------------------

## Architecture

``` text
                         INTERNET
                            |
                            v
                 +----------------------+
                 |     PUBLIC ALB       |
                 |       HTTP : 80      |
                 +----------+-----------+
                            |
                  +---------+---------+
                  |                   |
                  v                   v
            WEB EC2-A           WEB EC2-B
              Nginx               Nginx
            Public-A             Public-B
                  |                   |
                  +---------+---------+
                            |
                            v
                 +----------------------+
                 |    INTERNAL ALB      |
                 |      TCP : 5000      |
                 +----------+-----------+
                            |
                  +---------+---------+
                  |                   |
                  v                   v
             APP EC2-A           APP EC2-B
              Flask                Flask
             Private-A            Private-B
                  |                   |
                  +---------+---------+
                            |
                            | MySQL : 3306
                            v
                 +----------------------+
                 |      RDS MySQL       |
                 |    Private DB Tier   |
                 +----------------------+
```

------------------------------------------------------------------------

## Project Objectives

-   Create a custom AWS VPC.
-   Deploy six subnets across two Availability Zones.
-   Separate Web, Application, and Database tiers.
-   Deploy Nginx web servers on EC2.
-   Deploy Python Flask application servers on private EC2 instances.
-   Deploy MySQL using Amazon RDS.
-   Configure Public and Internal Application Load Balancers.
-   Configure Nginx as a reverse proxy.
-   Secure communication using Security Groups.
-   Store feedback submitted through the application in RDS.
-   Verify stored records using SQL.

------------------------------------------------------------------------

## AWS Services Used

  AWS Service                 Purpose
  --------------------------- ---------------------------------------
  Amazon VPC                  Isolated cloud network
  Amazon EC2                  Web and application servers
  Amazon RDS MySQL            Database
  Application Load Balancer   Traffic distribution
  NAT Gateway                 Internet access for private resources
  Internet Gateway            Internet access for public resources
  Elastic IP                  Static IP for NAT Gateway
  Route Tables                Network routing
  Security Groups             Network access control

------------------------------------------------------------------------

## Network Configuration

### VPC

``` text
CIDR: 10.0.0.0/16
Region: ap-south-1
```

### Public Web Subnets

  Name              CIDR          AZ
  ----------------- ------------- -------------
  Public-Subnet-A   10.0.1.0/24   ap-south-1a
  Public-Subnet-B   10.0.2.0/24   ap-south-1b

### Private Application Subnets

  Name           CIDR          AZ
  -------------- ------------- -------------
  App-Subnet-A   10.0.3.0/24   ap-south-1a
  App-Subnet-B   10.0.4.0/24   ap-south-1b

### Private Database Subnets

  Name          CIDR          AZ
  ------------- ------------- -------------
  DB-Subnet-A   10.0.5.0/24   ap-south-1a
  DB-Subnet-B   10.0.6.0/24   ap-south-1b

------------------------------------------------------------------------

## Routing

### Public Route Table

Associated with:

-   Public-Subnet-A
-   Public-Subnet-B

Route:

``` text
0.0.0.0/0 → Internet Gateway
```

### Private Application Route Table

Associated with:

-   App-Subnet-A
-   App-Subnet-B

Route:

``` text
0.0.0.0/0 → NAT Gateway
```

### Private Database Route Table

Associated with:

-   DB-Subnet-A
-   DB-Subnet-B

The database tier remains private and does not have direct Internet
access.

------------------------------------------------------------------------

## Security Groups

  Security Group      Port Source
  ----------------- ------ ------------------
  Public ALB SG         80 Internet
  Public ALB SG        443 Internet
  Web SG                80 Public ALB SG
  Web SG                22 Administrator IP
  Internal ALB SG     5000 Web SG
  App SG              5000 Internal ALB SG
  DB SG               3306 App SG

The database is not exposed directly to the Internet.

------------------------------------------------------------------------

## Web Tier

Two EC2 instances are deployed in the public subnets:

``` text
ThreeTier-Web-A
ThreeTier-Web-B
```

Nginx is installed on both instances and serves the frontend
application.

------------------------------------------------------------------------

## Application Tier

Two EC2 instances are deployed in private application subnets:

``` text
ThreeTier-App-A
ThreeTier-App-B
```

The backend uses:

-   Python
-   Flask
-   PyMySQL
-   Gunicorn

The Flask application runs on port:

``` text
5000
```

Health endpoint:

``` text
GET /
```

Expected response:

``` json
{
  "status": "Flask is running"
}
```

------------------------------------------------------------------------

## Database Tier

Amazon RDS MySQL is deployed using the private database subnets.

Database:

``` text
feedbackdb
```

Table:

``` text
feedback
```

Columns:

``` text
id
name
email
feedback
created
```

The RDS Security Group allows MySQL port `3306` only from the
Application Tier Security Group.

------------------------------------------------------------------------

## Public Application Load Balancer

The Internet-facing ALB distributes traffic between the Web EC2
instances.

``` text
Internet
   |
   v
Public ALB
   |
   +---- Web EC2-A
   |
   +---- Web EC2-B
```

Public ALB DNS:

``` text
<PUBLIC-ALB-DNS-NAME>
```

This will be replaced with the actual DNS name after deployment.

------------------------------------------------------------------------

## Internal Application Load Balancer

The Internal ALB distributes API traffic between the Flask application
instances.

``` text
Web EC2
   |
   v
Internal ALB : 5000
   |
   +---- App EC2-A
   |
   +---- App EC2-B
```

Internal ALB DNS:

``` text
<INTERNAL-ALB-DNS-NAME>
```

This will be replaced with the actual DNS name after deployment.

------------------------------------------------------------------------

## Nginx Reverse Proxy

Nginx serves the frontend and forwards API requests to the Internal ALB.

Example:

``` nginx
location / {
    try_files $uri $uri/ =404;
}

location /api/ {
    proxy_pass http://INTERNAL-ALB-DNS/;
}
```

The actual Internal ALB DNS name will be configured during deployment.

------------------------------------------------------------------------

## Application Flow

``` text
User Browser
     |
     v
Public Application Load Balancer
     |
     v
Nginx Web EC2
     |
     | /api/submit
     v
Internal Application Load Balancer
     |
     v
Flask Application EC2
     |
     | MySQL : 3306
     v
Amazon RDS MySQL
```

------------------------------------------------------------------------

## Feedback Application

The frontend provides a feedback form for:

-   Name
-   Email
-   Feedback

The frontend sends requests to:

``` text
/api/submit
```

The Flask application processes the request and stores the feedback in
Amazon RDS MySQL.

------------------------------------------------------------------------

## Database Verification

After submitting feedback:

``` sql
USE feedbackdb;

SELECT * FROM feedback;
```

The returned records are used as evidence that the complete application
flow is working.

------------------------------------------------------------------------

## Project Files

  File           Description
  -------------- -------------------------------------
  `app.py`       Flask backend
  `index.html`   Frontend
  `nginx.conf`   Nginx reverse proxy configuration
  `App.md`       Application deployment instructions
  `DB.md`        Database configuration and SQL
  `proxy.md`     Reverse proxy instructions
  `README.md`    Project documentation

------------------------------------------------------------------------

## Deployment Steps

1.  Create VPC.
2.  Create six subnets.
3.  Create and attach Internet Gateway.
4.  Allocate Elastic IP.
5.  Create NAT Gateway.
6.  Create and configure three route tables.
7.  Associate the subnets with route tables.
8.  Create Security Groups.
9.  Launch Web EC2 instances.
10. Install and configure Nginx.
11. Deploy the frontend.
12. Launch Application EC2 instances.
13. Install Python and Flask dependencies.
14. Deploy the Flask application.
15. Create RDS MySQL.
16. Configure the database and tables.
17. Create the Public ALB.
18. Create the Internal ALB.
19. Configure Nginx reverse proxy.
20. Connect Flask to RDS.
21. Submit test feedback.
22. Verify the feedback using SQL.

------------------------------------------------------------------------

## Validation Checklist

-   [ ] VPC available
-   [ ] Six subnets created
-   [ ] Internet Gateway attached
-   [ ] NAT Gateway available
-   [ ] Route tables correctly associated
-   [ ] Security Groups configured
-   [ ] Web EC2 instances running
-   [ ] Nginx running
-   [ ] Application EC2 instances running
-   [ ] Flask responding on port 5000
-   [ ] RDS MySQL available
-   [ ] Public ALB healthy
-   [ ] Internal ALB healthy
-   [ ] Nginx reverse proxy working
-   [ ] Feedback successfully submitted
-   [ ] Feedback record stored in RDS
-   [ ] SQL verification completed

------------------------------------------------------------------------

## Screenshots

Deployment evidence will be stored in:

``` text
screenshots/
├── 01-vpc.png
├── 02-subnets.png
├── 03-internet-gateway.png
├── 04-nat-gateway.png
├── 05-route-tables.png
├── 06-security-groups.png
├── 07-web-ec2.png
├── 08-nginx.png
├── 09-public-alb.png
├── 10-app-ec2.png
├── 11-flask.png
├── 12-rds.png
├── 13-internal-alb.png
├── 14-nginx-proxy.png
├── 15-feedback-success.png
└── 16-sql-output.png
```

------------------------------------------------------------------------

## Architecture Diagram

The final architecture diagram will be stored in:

``` text
architecture/aws-3-tier-architecture.png
```

------------------------------------------------------------------------

## Working Application

Public Application Load Balancer:

``` text
<PUBLIC-ALB-DNS-NAME>
```

The actual working DNS name will be added after successful deployment.

------------------------------------------------------------------------

## GitHub Repository

Repository:

https://github.com/soundar1993s/aws-three-tier-architecture

------------------------------------------------------------------------

## Technologies

### Frontend

-   HTML
-   CSS
-   JavaScript

### Backend

-   Python
-   Flask
-   PyMySQL
-   Gunicorn

### Web Server

-   Nginx

### Database

-   MySQL
-   Amazon RDS

### Cloud

-   Amazon Web Services (AWS)

------------------------------------------------------------------------

## Future Enhancements

Possible improvements include:

-   Amazon EC2 Auto Scaling
-   HTTPS using AWS Certificate Manager
-   CloudWatch monitoring
-   CI/CD deployment
-   AWS Systems Manager Session Manager
-   Terraform or CloudFormation infrastructure automation

------------------------------------------------------------------------

## Security Note

Do not commit sensitive information to this repository.

Never upload:

-   AWS access keys
-   AWS secret keys
-   EC2 `.pem` private keys
-   RDS passwords
-   `.env` files containing credentials

Database credentials should be configured securely on the application
server.

------------------------------------------------------------------------

## Conclusion

This project demonstrates a secure and scalable AWS 3-Tier Architecture
with separate Presentation, Application, and Database layers.

The architecture uses load balancing, private networking, NAT Gateway,
Security Groups, Nginx, Flask, and Amazon RDS MySQL to provide a secure
and highly available application environment.

The final application allows users to submit feedback through the web
interface, processes the request through the Flask backend, and stores
the feedback in Amazon RDS MySQL.
