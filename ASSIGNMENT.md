# Take-home Interview
For this role, we are looking for someone who is capable of leadership and
mentorship, but who is also unafraid of diving deep into the infrastructure
themselves. We value those who prioritize an exceptional developer experience,
focus on delivering high-level security, produce readable and maintainable code,
make wise financial decisions, strive for reversibility in their decisions when
possible, and lean on commodities and products whenever it makes sense.

This task should ideally take about an hour or two to complete. It involves AWS
and Terraform, and is designed to test your ability to create a scalable and
secure infrastructure setup.

Please follow these guidelines.

- Create a VPC with two subnets, one public and one private, each in a different
  availability zone for high availability.
- Set up an EC2 instance within the public subnet to serve as a bastion
  host/jump box. The associated security group should allow SSH access (Port 22)
  only from specific IP ranges.
- Set up another EC2 instance within the private subnet to act as an application
  server. This server should only permit incoming connections from the bastion
  host.
- Utilize a managed relational database service like RDS, ensuring it's within
  the same VPC and not publicly accessible.
- Set up an S3 bucket for storing application logs. The EC2 instance should have
  an IAM role allowing it to put objects in this S3 bucket.

Your approach should align with the principles of Infrastructure as Code (IaC),
promoting version control, repeatability, and testability for the infrastructure
setup.

In addition, please find the questionnaire.md in this directory. Please answer
the questions in that file, as described there.

Deliverables:

- Your `main.tf` file (or multiple `.tf` files, if necessary), which should
  contain the Terraform code.
- A `variables.tf` file for any utilized variables.
- A README.md file, providing the following:
  - an explanation of your design decisions and their relevance to good
    practices around security, cost efficiency, reversibility, and
    commodity/product usage;
  - any trade-offs or potential improvements that could be made given more time; and
  - clear instructions on how to run and test the infrastructure setup.

Enjoy!