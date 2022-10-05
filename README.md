# Terraform AWS template

This is a terraform template to launch an ubuntu instance in AWS. At launch the following are created:
- VPC
- Internet gateway
- Route table
- Subnet
- Subnet is associated to route table
- Security group to allow port 22(SSH), 80(HTTP), 443(HTTPS)
- Network interface
- Elastic IP
- Creating an ubuntu instance and install apache2 server
