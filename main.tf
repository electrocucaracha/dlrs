# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}a"
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "dlrs_security_group"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

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
  key_name   = "dlrs_key_pair"
  public_key = "${file(pathexpand(var.public_key_path))}"
}

# aws ec2 describe-images \
#    --owners aws-marketplace \
#    --filters '[
#        {"Name": "name",                "Values": ["clear*"]},
#        {"Name": "virtualization-type", "Values": ["hvm"]},
#        {"Name": "architecture",        "Values": ["x86_64"]},
#        {"Name": "image-type",          "Values": ["machine"]}
#      ]' \
#    --query 'Images[*].[CreationDate,Name,ImageId]' \
#    --region us-east-1 \
#    --output table
data "aws_ami" "clearlinux" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["clear-*"]
  }
}

data "template_file" "dlrs_cpu_script" {
  count    = length(var.dlrs)
  template = "${file("dlrs-script.tpl")}"
  vars     = {
    type     = "${element(var.dlrs, count.index)}"
    user     = "clear"
    hostname = "cpu_${element(var.dlrs, count.index)}"
  }
}

resource "aws_instance" "dlrs_cpu_instance" {
  count                  = length(var.dlrs)
  instance_type          = "c5d.2xlarge" # CPU optimized 8vCPUs 16 GB $0.384/hr
  ami                    = "${data.aws_ami.clearlinux.image_id}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id              = "${aws_subnet.default.id}"
  user_data              = "${element(data.template_file.dlrs_cpu_script.*.rendered, count.index)}"
  availability_zone      = "${var.aws_region}a"
  root_block_device {
    volume_size           = 20
    delete_on_termination = true
  }
}

data "template_file" "dlrs_gpu_script" {
  count    = length(var.dlrs)
  template = "${file("dlrs-script.tpl")}"
  vars     = {
    type     = "${element(var.dlrs, count.index)}"
    user     = "ubuntu"
    hostname = "gpu_${element(var.dlrs, count.index)}"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "image-type"
    values = ["machine"]
  }

  filter {
    name   = "name"
    values = ["ubuntu*16.04*server*"]
  }
}

resource "aws_instance" "dlrs_gpu_instance" {
  count                  = length(var.dlrs)
  instance_type          = "g2.2xlarge" # GPU instaces 8vCPUs 15 GB $0.65/hr
  ami                    = "${data.aws_ami.ubuntu.image_id}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id              = "${aws_subnet.default.id}"
  user_data              = "${element(data.template_file.dlrs_gpu_script.*.rendered, count.index)}"
  availability_zone      = "${var.aws_region}a"
  root_block_device {
    volume_size           = 40
    delete_on_termination = true
  }
}
