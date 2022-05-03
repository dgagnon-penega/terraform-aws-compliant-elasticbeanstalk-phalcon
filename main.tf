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

# create EB and frontends

# cloudfront

# waf