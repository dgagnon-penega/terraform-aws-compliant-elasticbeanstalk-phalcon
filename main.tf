terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 4.11.0"
      //noinspection HILUnresolvedReference
      configuration_aliases = [
        aws,
        aws.us
      ]
    }
  }
}

//--------------------------------------------------------------------

# domain or subdomain
resource "aws_route53_zone" "domain" {
  name = var.domain_name

  tags = {
    Env = var.env_version
  }
}

# s3 public bucket

# create EB and frontends

# cloudfront

# waf

