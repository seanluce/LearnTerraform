provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "seanluce" {
  key_name   = "seanluce"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDbiir97HKZw0XZTyYZwPr37cF+HmsRpDEiVdUoqgFW0JOiGq3xowZVjPbVgTRe5XPqTWlKtSbYH0sgSIY8u4XE2F1smiHt7i+ZIVxrhNNzYUt3Z5juVmJJIqYAcpELt+2JMKmjCRXvmGj2KRk+jSObQj2WsfZ653qRQqpxG1ExMQ+zmovfUe3gzMpmr9udJhkLyqs5w9Kilv6vuud6vdlLiiSTH6BR9pGcxSeDrh3nQlV+6oUJtlXmyezEd1CGMq7uwh2jgdrTxbv2WQscWVdD3sfkbBAQ22nnAji5jjmEmdywTfxG73YRRYGT5Rpv3BeuQH2VpTr77CwQNPXmOs5qJfBcOdvMSvwt3nLtqN+YcH28g7BWLN5yLnHFOIrekwGUBkz0n/oLEan1pXLqmVXc+5FNDWegrjRtrPiRIXq+3kTSY4vThFNys/5n85umAnKng/c6+ymO+zFwgZ1Lt/h5K4VXAdzIslzsAslyjpska014vS+BdO21CsJeMHmvN8IqZLsuWJAQPJZccBiMXRN+jJKOFYlF8xdtZYVw3INP1o7YFivNIzA1LXarNPHFrdZK1j6eQM63gmvh+HJnHpMYTGCoTxmlhG4aSomp+lmSIW2UwiAFIe+df6Q2wJwh8KSOmDvEAOLSak4S2yLZJhkl++fVoPuQcqRWE0YYtcfrrQ== lucesean@gmail.com"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "backend" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "r" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

resource "aws_security_group" "sshworld" {
  vpc_id      = "${aws_vpc.main.id}"
  name        = "sshworld"
  description = "Allow SSH from the world"

  ingress {
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
}

resource "aws_instance" "example" {
  subnet_id                   = "${aws_subnet.backend.id}"
  ami                         = "ami-b374d5a5"
  associate_public_ip_address = 1
  instance_type               = "t2.micro"
  key_name                    = "${aws_key_pair.seanluce.id}"
  vpc_security_group_ids      = ["${aws_security_group.sshworld.id}"]
}

output "ip" {
  value = "${aws_instance.example.public_ip}"
}
