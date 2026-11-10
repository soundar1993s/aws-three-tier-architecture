# Project 01 deployment and evidence

This Terraform configuration deploys the supplied feedback form in Mumbai by default. It uses six /23 subnets across two Availability Zones, a zonal NAT gateway, private RDS MySQL, two Application Load Balancers, and separate EC2 Auto Scaling groups for the web and app tiers. Both groups start with two instances. The public lab endpoint uses HTTP and should be tested with synthetic feedback.

## Authenticate and review the plan

In PowerShell, select an authenticated AWS profile with deployment permissions.

```powershell
$env:AWS_PROFILE = 'guvi-project01'
$env:AWS_REGION = 'ap-south-1'
aws sts get-caller-identity
terraform init
terraform validate
terraform plan '-out=project01.tfplan'
terraform apply project01.tfplan
```

The default deploys a Multi-AZ DB instance. If you have chosen a lower-cost Single-AZ lab setup, set `multi_az_database = false` in an ignored local `lab.auto.tfvars` file before planning. EC2, RDS, ALBs, NAT, public IPv4 addresses, and secrets can incur charges. Keep state and plan files local and private because they can contain the generated database writer password.

## Initialize MySQL from a private app instance

1. In EC2, select a running instance tagged `Tier=app` and connect using **Session Manager**. Allow cloud-init to finish installing the application and dependencies.
2. Temporarily enable the role policy for the exact RDS master secret.

   ```powershell
   terraform apply '-var=enable_schema_bootstrap=true'
   ```

3. Run the following in the app instance's Session Manager terminal. Capture the health response and the schema output. The initialization script runs the database and table creation SQL and grants the separate application user permission to insert feedback.

   ```bash
   sudo cloud-init status --wait
   curl -fsS http://localhost:5000/
   sudo bash -c 'set -a; source /opt/feedback/feedback.env; exec /opt/feedback/venv/bin/python /opt/feedback/database.py initialize'
   ```

## Verify through both load balancers

1. In EC2 Target Groups, confirm both targets are healthy in each of the `guvi-project01-web` and `guvi-project01-app` target groups.
2. From a web instance's Session Manager terminal, run `sudo nginx -t` and `curl -fsS http://localhost/api/`. The latter should return Flask's health JSON through the internal ALB.
3. Run `terraform output -raw application_url`. Open that URL and submit synthetic data with a unique marker, such as `project01-e2e-001`. Capture the URL and success message together.
4. In the app Session Manager terminal, query for the marker you submitted and capture the result.

   ```bash
   sudo bash -c 'set -a; source /opt/feedback/feedback.env; exec /opt/feedback/venv/bin/python /opt/feedback/database.py verify project01-e2e-001'
   ```

5. Revoke the temporary schema access. Terraform defaults the bootstrap option to false. Flask retains only access to its dedicated writer secret.

   ```powershell
   terraform apply
   ```

The PowerShell helper runs the same checks on a managed instance through Systems Manager Run Command. For example, run `./deploy/Invoke-ProjectCheck.ps1 -Check Web` or `./deploy/Invoke-ProjectCheck.ps1 -Check Verify -FeedbackMarker project01-e2e-001`. The Schema and Verify checks require the temporary policy above.

## Capture the evidence

| Task | Capture |
|---|---|
| 1 Networking | VPC resource map with all six subnets, both gateway statuses, NAT Elastic IP, and the three explicit route tables with associations |
| 2 Web tier | Web instances in both AZs and the Nginx frontend |
| 3 App tier | Private app instances and the Session Manager response from `localhost:5000/` |
| 4 Database | Private RDS instance, DB subnet group, and schema output from the app terminal |
| 5 Security | Five security groups and their tier-to-tier source rules |
| 6 Public ALB | Public ALB DNS, listener, and healthy web targets |
| 7 Internal ALB | Internal ALB scheme, listener, and healthy app targets |
| 8 Nginx proxy | Successful `nginx -t` and `curl localhost/api/` from the web instance |
| 9 RDS integration | SQL query and the row matching the unique browser test marker |
| 10 End to end | Public ALB URL and the browser feedback success message |
| Bonus Auto Scaling | Both groups, launch templates, target tracking, and activity history |

Keep the public URL available for the assessment window. After grading, review a Terraform destroy plan before cleanup. The lab is configured to skip the final database snapshot, so export any records that must be retained before deleting it.
