aws_region     = "us-east-1"
cluster_name   = "prod-eks"
worker_ami_id  = "ami-0abcd1234efgh5678"

subnet_ids = [
  "subnet-0123456789abcdef0",
  "subnet-0fedcba9876543210"
]

min_size         = 2
max_size         = 5
desired_capacity = 3
