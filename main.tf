# Setting up the provider - AWS

provider "aws" {
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
    region = "us-east-1"
}

# Create a security group to allow port 80 and 22 access

resource "aws_security_group" "allow_http_ssh" {
  name        = "allow_http"
  description = "Allow http inbound traffic"


  ingress {
    description = "wordpress"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
 
  }
ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http_ssh"
  }
}

# Create a private key to allow SSH access from remote to the EC2 instance

resource "tls_private_key" "web_private_key" {
    algorithm   =  "RSA"
    rsa_bits    =  4096
}
resource "local_file" "private_key" {
    content         =  tls_private_key.web_private_key.private_key_pem
    filename        =  "webserver_key.pem"
    file_permission =  0400
}

# Create a key pair for the EC2 instance

resource "aws_key_pair" "my_key" {
  key_name   = "my_key"
  public_key = tls_private_key.web_private_key.public_key_openssh
}

# Create the EC2 instance

resource "aws_instance" "ec2_instance" {
  ami           = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  tags          = {
    Name = "${var.name}"
  }
  key_name = aws_key_pair.my_key.key_name
  security_groups=["${aws_security_group.allow_http_ssh.name}"]

# Create an SSH connection to run the post commands

  connection {
        type    = "ssh"
        user    = "ec2-user"
        host    = aws_instance.ec2_instance.public_ip
        port    = 22
        private_key = tls_private_key.web_private_key.private_key_pem
    }

# Run the post commands

   provisioner "remote-exec" {
        inline  = [
		"sudo yum install docker curl git -y",
    "git clone https://github.com/chosey85/wordpress.git",
    "sudo curl -L \"https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose",
    "sudo chmod +x /usr/local/bin/docker-compose",
    "sudo usermod -aG docker $USER",
    "sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose",
    "sudo systemctl enable docker --now",
    "sudo docker-compose -f /home/ec2-user/wordpress/docker-compose.yml up -d"

	]
    }
}