provider "aws" {
  region = "us-west-2"
  shared_credentials_file = "$HOME/.aws/credentials"
}

resource "aws_vpc" "vpc_api" {
  cidr_block = "172.31.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "NanoNets API VPC"
  }
}

# Public subnet for load balancer
resource "aws_subnet" "public_subnet_us-west-2a" {
  vpc_id                  = "${aws_vpc.vpc_api.id}"
  cidr_block              = "172.31.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2a"
  tags = {
  	Name =  "NanoNets API Public Subnet"
  }
}

# Private subnet 1 for server instances
resource "aws_subnet" "private_1_subnet_us-west-2a" {
  vpc_id                  = "${aws_vpc.vpc_api.id}"
  cidr_block              = "172.31.2.0/24"
  availability_zone = "us-west-2a"
  tags = {
  	Name =  "NanoNets API Private Subnet 1"
  }
}
 
# Private subnet 2 for database instance
resource "aws_subnet" "private_2_subnet_us-west-2a" {
  vpc_id                  = "${aws_vpc.vpc_api.id}"
  cidr_block              = "172.31.3.0/24"
  availability_zone = "us-west-2a"
  tags = {
  	Name =  "NanoNets API Private Subnet 2"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.vpc_api.id}"
  tags {
        Name = "NanoNets API Internet Gateway"
    }
}

# Add in main route table for VPC
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.vpc_api.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

# Create elastic ip for NAT Gateway for instance in private subnet
resource "aws_eip" "nat_eip" {
  vpc      = true
  depends_on = ["aws_internet_gateway.gw"]
}

# Create NAT gateway for instances in private gateway to connect to internet
resource "aws_nat_gateway" "nat" {
    allocation_id = "${aws_eip.nat_eip.id}"
    subnet_id = "${aws_subnet.public_subnet_us-west-2a.id}"
    depends_on = ["aws_internet_gateway.gw"]
}

# Create secondary route table
resource "aws_route_table" "private_route_table" {
    vpc_id = "${aws_vpc.vpc_api.id}"
 
    tags {
        Name = "NanoNets API Secondary Route Table"
    }
}

# Add NAT Gateway to public internet
resource "aws_route" "private_route" {
	route_table_id  = "${aws_route_table.private_route_table.id}"
	destination_cidr_block = "0.0.0.0/0"
	nat_gateway_id = "${aws_nat_gateway.nat.id}"
}

# Add public subnet in main route table
resource "aws_route_table_association" "public_subnet_us-west-2a_association" {
    subnet_id = "${aws_subnet.public_subnet_us-west-2a.id}"
    route_table_id = "${aws_vpc.vpc_api.main_route_table_id}"
}

# Add private subnets in secondary route tables
resource "aws_route_table_association" "pr_1_subnet_eu_west_1a_association" {
    subnet_id = "${aws_subnet.private_1_subnet_us-west-2a.id}"
    route_table_id = "${aws_route_table.private_route_table.id}"
}

# Add private subnets in secondary route tables
resource "aws_route_table_association" "pr_2_subnet_eu_west_1a_association" {
    subnet_id = "${aws_subnet.private_2_subnet_us-west-2a.id}"
    route_table_id = "${aws_route_table.private_route_table.id}"
}

# Default security group
resource "aws_security_group" "web" {
  name        = "web"
  description = "Used for web instance"
  vpc_id      = "${aws_vpc.vpc_api.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Default security group
resource "aws_security_group" "api" {
  name        = "api"
  description = "Used for api instance"
  vpc_id      = "${aws_vpc.vpc_api.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Worker security group
resource "aws_security_group" "worker" {
  name        = "worker"
  description = "Used for worker instance"
  vpc_id      = "${aws_vpc.vpc_api.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Cassandra security group
resource "aws_security_group" "cassandra" {
  name        = "cassandra"
  description = "Used for cassandra instance"
  vpc_id      = "${aws_vpc.vpc_api.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Nginx instance
resource "aws_instance" "web" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"

    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, "cpu")}"

  key_name = "${aws_key_pair.auth.id}"

  vpc_security_group_ids = ["${aws_security_group.web.id}"]

  subnet_id = "${aws_subnet.public_subnet_us-west-2a.id}"

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get -y update",
      "sudo apt-get -y install nginx",
      "sudo service nginx start",
    ]
  }
}

# Cassandra instance
resource "aws_instance" "cassandra" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"

    # The connection will use the local SSH agent for authentication.
  }

  count = "1"

  instance_type = "t2.large"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, "cpu")}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.api.id}"]

  subnet_id = "${aws_subnet.private_2_subnet_us-west-2a.id}"
}

# Api Instance
resource "aws_instance" "api" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"

    # The connection will use the local SSH agent for authentication.
  }

  count = "2"

  instance_type = "t2.xlarge"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, "cpu")}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.api.id}"]

  subnet_id = "${aws_subnet.private_1_subnet_us-west-2a.id}"
}

# Worker instance
resource "aws_instance" "worker" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"

    # The connection will use the local SSH agent for authentication.
  }

  count = "2"

  instance_type = "g2.2xlarge"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, "gpu")}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.worker.id}"]

  subnet_id = "${aws_subnet.private_1_subnet_us-west-2a.id}"
}