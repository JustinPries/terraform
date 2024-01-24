#vpc
resource "aws_vpc" "primaryrgi" {
  cidr_block = "172.24.0.0/16"
  tags = {
    name = "upgrade-vpc"
  }
}

#public subnets
resource "aws_subnet" "publicsubnet1" {
  vpc_id            = aws_vpc.primaryrgi.id
  cidr_block        = "172.24.107.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "upgrad-publicsubnet-1"
  }
}

resource "aws_subnet" "publicsubnet2" {
  vpc_id            = aws_vpc.primaryrgi.id
  cidr_block        = "172.24.108.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "upgrade-publicsubnet-2"
  }
}

#private subnets

resource "aws_subnet" "privatesubnet1" {
  vpc_id            = aws_vpc.primaryrgi.id
  cidr_block        = "172.24.109.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "upgrade-privatesubnet1"
  }
}
resource "aws_subnet" "privatesubnet2" {
  vpc_id            = aws_vpc.primaryrgi.id
  cidr_block        = "172.24.110.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "upgrade-privatesubnet2"
  }
}

#internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.primaryrgi.id
}

#elastic ip
resource "aws_eip" "eip" {
  domain = "vpc"
}

#nat gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.publicsubnet1.id

  tags = {
    Name = "upgrad-nat"
  }
}

#public route table
resource "aws_route_table" "publicroutetable1" {
  vpc_id = aws_vpc.primaryrgi.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public=rt"
  }
}

#private route table
resource "aws_route_table" "privateroutetable1" {
  vpc_id = aws_vpc.primaryrgi.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "private-rt"
  }

}

#route table association
resource "aws_route_table_association" "publicsubnet1" {
  subnet_id      = aws_subnet.publicsubnet1.id
  route_table_id = aws_route_table.publicroutetable1.id
}

resource "aws_route_table_association" "publicsubnet2" {
  subnet_id      = aws_subnet.publicsubnet2.id
  route_table_id = aws_route_table.publicroutetable1.id
}

resource "aws_route_table_association" "privatesubnet1" {
  subnet_id      = aws_subnet.privatesubnet1.id
  route_table_id = aws_route_table.privateroutetable1.id
}
resource "aws_route_table_association" "privatesubnet2" {
  subnet_id      = aws_subnet.privatesubnet2.id
  route_table_id = aws_route_table.privateroutetable1.id
}

#security group
resource "aws_security_group" "allow_ssh_to_wp" {
  name        = "allow_ssh_to-wp"
  description = "Allow inbound ssh traffic"
  vpc_id      = aws_vpc.primaryrgi.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_s3_bucket" "bucket" {
  bucket = "justinpriestioresumebucket"

}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "PublicReadGetObject",
          "Effect" : "Allow",
          "Principal" : "*",
          "Action" : "s3:GetObject",
          "Resource" : "arn:aws:s3:::${aws_s3_bucket.bucket.id}/*"
        }
      ]
    }
  )
}

resource "aws_s3_object" "file" {
  for_each     = fileset(path.module, "content/**/*.{html,css,js}")
  bucket       = aws_s3_bucket.bucket.id
  key          = replace(each.value, "/^content//", "")
  source       = each.value
  content_type = lookup(local.content_types, regex("\\.[^.]+$", each.value), null)
  etag         = filemd5(each.value)
}
resource "aws_s3_bucket_website_configuration" "hosting" {
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = "resume.html"
  }
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["justinpriest.io"]


  origin {
    domain_name = aws_s3_bucket_website_configuration.hosting.website_endpoint
    origin_id   = aws_s3_bucket.bucket.bucket_regional_domain_name

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = "arn:aws:acm:us-east-1:873948314717:certificate/ae97d06a-33fb-4e9c-a5a9-d0091dc8e702"
    minimum_protocol_version       = "TLSv1.2_2021"
    ssl_support_method             = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  default_cache_behavior {
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.bucket.bucket_regional_domain_name
  }
}



#EC2
#resource "aws_instance" "wordpress_server_1" {
# ami                         = "ami-0daaac8ef7c1d0e95"
#instance_type               = "t2.micro"
#key_name                    = "wordpresslab"
#subnet_id                   = aws_subnet.publicsubnet1.id
#security_groups             = [aws_security_group.allow_ssh_to_wp.id]
#associate_public_ip_address = true

#}

#rds subnet
#resource "aws_db_subnet_group" "rds_subnet_group" {
# name       = "rds-subnet-group"
#subnet_ids = [aws_subnet.privatesubnet1.id, aws_subnet.privatesubnet2.id]
#}

#rds instance
#resource "aws_db_instance" "rds_instancewordpress" {
# engine                    = "mysql"
#engine_version            = "5.7"
#skip_final_snapshot       = true
#final_snapshot_identifier = "my-final-snapshot"
#instance_class            = "db.t2.micro"
#allocated_storage         = 20
#identifier                = "my-rds-instance"
#db_name                   = "wordpress_db"
#username                  = "jmpriest91"
#password                  = "ufXy3!LbYC*q%Y"
#db_subnet_group_name      = aws_db_subnet_group.rds_subnet_group.name
#vpc_security_group_ids    = [aws_security_group.rds_security_group.id]

#}

#RDS Security Group
#resource "aws_security_group" "rds_security_group" {
# name        = "rds-security-group"
# description = "Security Group for RDS instance"
# vpc_id      = aws_vpc.primaryrgi.id

#ingress {
# from_port   = 3306
#to_port     = 3306
#protocol    = "tcp"
#cidr_blocks = ["172.24.0.0/16"]
#}
#}

