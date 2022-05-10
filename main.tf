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
data "aws_route53_zone" "domain" {
  id = var.zone_id
}

# s3 public bucket

# create EB and frontends

# cloudfront

# waf

