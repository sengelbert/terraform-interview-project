# Terraform Interview Project
Link - https://github.com/sengelbert/terraform-interview-project

Design & Architecture:
- 

Notes:
- RDS 

Improvements:
- Split to more Terraform files
- More configuration based on needs of the system and services
- More thought out networking, security, etc setup
- SSM agent instead of SSH keys...I started this but need to complete
- Tags!!!

Prerequisites & Assumptions:
- SSH key manually created and name passed into prompt

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
    - should have success