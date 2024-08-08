provider "aws" {
  region = "us-west-1"
}

resource "random_integer" "bucket_suffix" {
  min = 10000  # Minimum 5-digit number
  max = 99999  # Maximum 5-digit number
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-internet-gateway"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}

resource "aws_security_group" "secure_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from anywhere (consider security)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP traffic from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-sg"
  }
}

# Create a Lightsail instance with Nginx
resource "aws_lightsail_instance" "web" {
  name                = "nginx-instance"
  availability_zone   = "us-west-1a"  # Choose your preferred availability zone
  blueprint_id       = "amazon_linux_2"  # Use the Amazon Linux 2 blueprint
  bundle_id          = "micro_1_0"  # Choose the appropriate instance bundle

  tags = {
    Name = "nginx-instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update packages
              sudo su
              yum update -y

              # Install Nginx
              sudo amazon-linux-extras install nginx1 -y

              # Start Nginx service
              systemctl start nginx
              systemctl enable nginx  # Enable Nginx to start on boot

              # Create index.html with the redirect to the new site
              echo '<html>
              <head>
                  <meta http-equiv="Refresh" content="0; url=https://websim.ai/@bluebreath06050310/textgram-a-text-only-social-experience">
                  <title>Redirecting...</title>
              </head>
              <body>
                  <p>If you are not redirected automatically, follow this <a href="https://websim.ai/@bluebreath06050310/textgram-a-text-only-social-experience">link</a>.</p>
              </body>
              </html>' > /usr/share/nginx/html/index.html
              EOF
}

resource "aws_s3_bucket" "secure_bucket" {
  bucket = format("my-secure-bucket-%d", random_integer.bucket_suffix.result)  # Use random suffix

  tags = {
    Name = "secure-bucket"
  }
}

resource "aws_s3_bucket_public_access_block" "secure_bucket_block" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "secure_bucket_versioning" {
  bucket = aws_s3_bucket.secure_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_bucket_encryption" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Elastic IP for the Lightsail instance (Static IP)
resource "aws_lightsail_static_ip" "web_static_ip" {
  name = "web-static-ip"
}

resource "aws_lightsail_static_ip_attachment" "static_ip_attachment" {
  static_ip_name = aws_lightsail_static_ip.web_static_ip.name
  instance_name  = aws_lightsail_instance.web.name
}

# Output the static IP
output "static_ip" {
  description = "The static IP address attached to the Lightsail instance"
  value       = aws_lightsail_static_ip.web_static_ip.ip_address
}
