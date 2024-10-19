# PROJECT OVERVIEW

This project deploys a simple web application using a pre-built Docker image on AWS EC2 instances. The infrastructure is managed using Terraform, with auto-scaling and load balancing to ensure high availability.

## To set up the application, the following were required:

1. An AWS account
2. AWS CLI configured on the local machine
3. Terraform installed for infrastructure automation
4. An SSH key pair for EC2 access
5. Docker installed locally (optional, for testing)

## Infrastructure as Code (IaC):

Terraform was used to automate the creation of resources like EC2 instances, security groups, and load balancers.
The steps involved initializing Terraform in the project directory and applying the configuration:

 ```python
 # initializes your Terraform working directory
 terraform init

 # To see what Terraform intends to do based on the configuration files (.tf) you have written.
 terraform plan

 # To execute the changes proposed in the plan and actually applies them to your infrastructure.
 terraform apply
 ```

 ## Provisioning EC2 Instances:

EC2 instances were launched using a specific AMI.
Necessary IAM roles and permissions were assigned to the EC2 instances for proper access and security.

## Installing Docker on EC2:

After connecting to the EC2 instance via SSH, Docker was installed with the following commands:

 ```python
  # Assign the Base64-encoded user data script to the variable 'user_data'
 user_data = base64encode(<<-EOF              

              #!/bin/bash    

              # Update the list of available packages               
              sudo apt-get update   

              # Install Docker using the package manager without prompts
              sudo apt-get install -y docker.io 

              # Start the Docker service to allow Docker to run containers
              sudo systemctl start docker     
              
              # Download the Docker image 'yeasy/simple-web' from Docker Hub
              sudo docker pull yeasy/simple-web 

              # Run the Docker container in detached mode (-d) and map port 80 of the container to port 80 of the host
              sudo docker run -d -p 80:80 yeasy/simple-web 
            EOF
  )

 ```
## Security Groups Configuration:

Security groups were configured to allow inbound traffic on port 80 for HTTP and port 22 for SSH access.
I ensured the rules followed best practices, restricting unnecessary traffic to the instance.

## Setting Up Auto-Scaling and Load Balancing:

An Auto Scaling group was created to launch new instances automatically when demand increased.
An Elastic Load Balancer (ELB) was configured to distribute traffic evenly across instances for better availability and fault tolerance.

## Assumptions and Troubleshooting
## Assumptions:

The provided AMI already had necessary permissions.
The application was configured to use port 80.

# Troubleshooting:

## EC2 Instance Launch Issues:

1. If the EC2 instance fails to launch, check the AWS Management Console for error messages or quota limits.
2. Verify that the selected AMI is available in the region where the instance is being launched.

## SSH Connection Problems:

1. Ensure the correct private key is used when connecting to the EC2 instance.
2. Verify that the security group allows inbound SSH (port 22) traffic from your IP address.

## Docker Image Pull Failures:

1. If pulling the Docker image fails, check internet connectivity on the EC2 instance.
2. Ensure that Docker is installed and running properly.

## Application Not Accessible:

1. If the application is not accessible via the public IP, check that the Docker container is running with:

 ```python
docker ps
 ```
2. Confirm that the security group allows inbound traffic on port 80.

## High CPU or Memory Usage:

1. If the application experiences high CPU or memory usage, consider resizing the EC2 instance type or optimizing the application code.
2. Monitor instance performance metrics in the AWS Management Console.

## Auto-Scaling Group Issues:

1. If the Auto Scaling group does not launch new instances, check the scaling policies and ensure that the health checks are configured correctly.
2. Verify that the desired capacity and minimum/maximum instance counts are set appropriately.

## Load Balancer Health Check Failures:

1. If the ELB indicates unhealthy instances, check the health check path and ensure the application is responding correctly on that endpoint.
2. Review the security group rules to ensure the health check requests can reach the instances.

## IAM Permission Denied Errors:

If there are permission errors related to AWS services, check the IAM role attached to the EC2 instance and ensure it has the necessary permissions for the actions being performed.

# The project included several configuration files:

$main.tf: The main Terraform configuration file used for defining the infrastructure.

