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
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
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

# Data source to fetch the latest Amazon Linux AMI ID for the specified region
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]  # Only fetch AMIs owned by Amazon

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]  # Adjust this to match your requirements
  }
}

resource "aws_instance" "web" {
  ami                  = data.aws_ami.amazon_linux.id  # Use the dynamically fetched AMI ID
  instance_type       = "t2.micro"
  subnet_id           = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.secure_sg.id]  # Updated parameter

  tags = {
    Name = "web-instance"
  }
}

resource "aws_s3_bucket" "secure_bucket" {
  bucket = format("my-secure-bucket-%d", random_integer.bucket_suffix.result)  # Use random suffix

  # Removed acl argument
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
