# Terraform Interview Project
Link - https://github.com/sengelbert/terraform-interview-project

Design, Architecture & Notes:
- VPC
  - 2 subnets for applications, 1 private and 1 public in different AZs
  - 2 subnets for DBs in different AZs
  - Internet Gateway
  - NAT Gateway
  - Route table and routes
- Bastion Server
  - Public subnet
  - Access via port 22 and SSH key
  - SSM started but needs to be completed
  - Cloudwatch alarm, needs more
- Application Server
  - Private subnet
  - Access via Bastion, port 22 and SSH key
  - SSM started but needs to be completed
  - Cloudwatch alarm, needs more
  - IAM role with access to write to application log bucket
- RDS
  - 2 subnets
  - Snapshots configured but needs more work
  - Cloudwatch alarm, needs more
  - More setup needed when details are ready
  - Secrets created and stored in Secrets Manager
- SNS
  - Created for Cloudwatch alarms, needs more configuration for endpoint (email, API, etc)
- S3
  - Application log bucket
  - Extra logging bucket created for S3 access logs
- Cloudwatch
  - Mentioned above, alarms and dashboard would need to be built out more

The VPC subnets were created to separate resources by access (private/public) and resource type
(server/DB). The Bastion server was setup with only allowing access via key based SSH 
and from my local IP (this will need to be tweaked for testing). Egress is not turned
on but can be uncommented if needed. The application server was setup so that it can 
only be accessed via the Bastion host. This is controlled through the Security Group.
The application server can put files to the application log s3 bucket. That bucket
was setup with versioning turned on for DR needs. I created another s3 bucket for 
audit/access logging for the s3 application log bucket. Both buckets are private.
The RDS instance was left pretty basic and can be updated once more requirements are 
provided. It is encrypted, private, snapshotted and secrets stored in Secrets Manager. 
Example Cloudwatch alarms
were created for the EC2 and RDS instances along with an SNS topic for the alarms to 
go to. Alarms are created with alarm actions and ok actions so they can self close. An
example Cloudwatch dashboard is included. The Cloudwatch alarms and dashboard would
need to be further built out accordingly. Many variables were placed in the variables.tf 
file. 


Improvements:
- Split to more Terraform files
- More configuration based on needs of the system and services
- More thought out networking, security, etc setup
- SSM agent instead of SSH keys...I started this but need to complete
- A standardized approach for tags
- More Cloudwatch alarm and dashboard work needed
- More RDS setup and configuration when details are ready
- More HA and DR work needed
- Get latest Amazon Linux AMI always

Prerequisites & Assumptions:
- SSH key manually created and name passed into prompt
- Will need to update the "source_cidr" value in variables.tf

Creation Steps:
- `terraform init`
- `terraform validate`
- `terraform apply`
  - pass in SSH key name

Destruction Steps:
- `terraform destroy`

Test Steps:
- With SSH key manually created run
  - `scp -i <key file> <key file> ec2-user@<public bastion host ip>:/home/ec2-user/.ssh/`
  - `ssh -i <key file> ec2-user@<public bastion host ip>`
  - `aws s3 ls`
    - should be denied
  - `ssh -i <key file> ec2-user@<private application host ip>`
  - `aws s3 ls`
    - should have success
  - `touch test.txt`
  - `aws s3 cp test.txt s3://<bucket name>/`
    - should have success and file in application log bucket
    - should have log file(s) in S3 access log bucket as well