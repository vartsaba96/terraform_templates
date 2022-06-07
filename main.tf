provider "aws" {
  region = "ca-central-1"
}

data "aws_availability_zones" {}
data "aws_ami" "latest_amazon_linux" {
  owners = ["amazon"]
  most_recent = true
  filter {
    name= "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "my_webserver" {
    name = "Dynamic Sequrity Group"

    dynamic "ingress" {
      for_each = ["80","443"]
      content {
      from_port = ingress.value
      to_port = ingress.value
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/16"]
    }
}

    egress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = Dynamic Security Group
      Owner = "VPO"
    }
  }

resource "aws_launch_configuration" "web" {
  //name = "WebServer-Highly-Available-lc"
  name_prefix = "WebServer-Highly-Available-lc-"
  image_id = data.aws.ami.latest_amazon_linux.id
  instance_type = "t3.micro"
  security_group = [aws_security_group.my_webserver.id]
  user_data = file("user_data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

  resource "aws_autoscaling_group" "web" {
    name = "ASG-${aws_launch_configuration.web.name}"
    launch_configuration = aws_launch_configuration.web.name
    min_size = 2
    max_size = 2
    min_elb_capacity = 2
    vpc_zone_identifier = [aws_default_subnet.default_az1.id,aws_default_subnet.default_az2.id]
    health_check_type = "ELB"
    load_balancers = [aws.elb.web.name]


    dynamic "tag" {
      for_each = {
        Name = "WebServer in ASG"
        Owner = "VPO"
        TAGKEY = "TAGVALUE"
      }
      content {
        key = tag.key
        value = tag.value
        propagate_at_launch = true
      }
    }

    lifecycle {
      create_before_destroy = true
    }

    resource "aws_elb" "web" {
      name = "WebServer-HA-ELB"
      availability_zones = [data.aws.availability_zones.available.names[0], data.aws.availability_zones.available.names[1]]
      security_groups = [aws_security_group.web.id]
      listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = 80
        instance_protocol = "http"
      }
      health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        target = "HTTP:80/"
        interval = 10
      }
      tags = {
        Name = "WebServer-Highly-Available-ELB"
      }
    }
  }

  resource "aws_default_subnet" "default_az1" {
      availability_zone = data.aws_availability_zones.available.names[0]
  }
  resource "aws_default_subnet" "default_az2" {
      availability_zone = data.aws_availability_zones.available.names[1]
  }

  #------------------------------------------------
  output "web_loadbalancer_url" {
    value = aws_elb.web.dns_name
  }
