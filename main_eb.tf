resource "aws_security_group" "app" {
  name                   = "${var.env_client}-${var.env_version}-Application-SG"
  description            = "Application Servers"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

#  ingress {
#    description     = "Allow all from workstation"
#    from_port       = 0
#    to_port         = 0
#    protocol        = "-1"
#    security_groups = [
#      var.wks_sg_id
#    ]
#  }

  #  ingress {
  #    description     = "Allow all from load-balancer"
  #    from_port       = 0
  #    to_port         = [80, 443]
  #    protocol        = "tcp"
  #    security_groups = [
  #      aws_security_group.lb.id
  #    ]
  #  }

  #  TODO: can we restrict this?
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${var.env_client}-${var.env_version}-Application-SG"
    Env  = var.env_version
  }
}


data "aws_iam_policy_document" "role_eb_instance" {
  statement {
    sid     = "1"
    effect  = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

data "aws_iam_policy_document" "role_eb_instance_jobs" {
  statement {
    sid     = "1"
    effect  = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "eb_instance" {
  name = "${var.env_client}-${var.env_version}-Instance-Role"

  assume_role_policy = data.aws_iam_policy_document.role_eb_instance.json

  tags = {
    Name = "${var.env_client}-${var.env_version}-Instance-Role"
    Env  = var.env_version
  }
}
resource "aws_kms_grant" "instance" {
  grantee_principal = aws_iam_role.eb_instance.arn
  key_id            = var.kms_arn
  operations        = [
    "GenerateDataKey",
    "DescribeKey",
    "Decrypt",
    "Encrypt"
  ]
  retire_on_delete = true
}
resource "aws_kms_grant" "instance_global" {
  grantee_principal = aws_iam_role.eb_instance.arn
  key_id            = var.kms_global_arn
  operations        = [
    "GenerateDataKey",
    "DescribeKey",
    "Decrypt",
    "Encrypt"
  ]
  retire_on_delete = true
}
resource "aws_iam_instance_profile" "eb_instance_profile" {
  role = aws_iam_role.eb_instance.name
  name = "${var.env_client}-${var.env_version}-Instance-Profile"
  path = "/"
  tags = {
    Env = var.env_version
  }
}
data "aws_iam_policy" "ssmcore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

// map the policy needed for cloudwatch monitoring
data "aws_iam_policy" "cloudwatch" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
resource "aws_iam_role_policy_attachment" "eb_instance_ssm" {
  policy_arn = data.aws_iam_policy.ssmcore.arn
  role       = aws_iam_role.eb_instance.name
}

resource "aws_iam_role_policy_attachment" "eb_instance_cw" {
  policy_arn = data.aws_iam_policy.cloudwatch.arn
  role       = aws_iam_role.eb_instance.name
}


data "aws_iam_policy_document" "eb_policy" {
  version = "2012-10-17"
  statement {
    sid     = "1"
    effect  = "Allow"
    actions = [
      "ssm:GetParametersByPath",
      "ssm:GetParameters",
      "ssm:GetParameter"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.default.account_id}:parameter/${var.env_version}/*",
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.default.account_id}:parameter/${var.env_version}"
    ]
    condition {
      test   = "ForAllValues:StringEquals"
      values = [
        var.vpc_id
      ]
      variable = "aws:SourceVpc"
    }
  }

  statement {
    sid     = "2"
    effect  = "Allow"
    actions = [
      "rds-db:connect"
    ]
    resources = [
      "arn:aws:rds-db:${var.aws_region}:${data.aws_caller_identity.default.account_id}:dbuser:${var.cluster_id}/dbuser"
    ]
    condition {
      test   = "ForAllValues:StringEquals"
      values = [
        var.vpc_id
      ]
      variable = "aws:SourceVpc"
    }
  }

  statement {
    sid     = "5"
    effect  = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetEncryptionConfiguration",
      "s3:GetBucketEncryption",
      "s3:ListBucket",
      "s3:PutObjectAcl"
    ]
    //TOOD: whats th exact path ssm needs?
    resources = [
      "${var.log_bucket_arn}/*",
      var.log_bucket_arn,
      local.pub_bucket_arn,
      "${local.pub_bucket_arn}/*"
    ]
  }

  statement {
    sid     = "6"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "${var.scripts_bucket_arn}/*",
      var.scripts_bucket_arn
    ]
  }

  statement {
    sid       = "AllowSSMBuckets"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::aws-windows-downloads-ca-central-1/*",
      "arn:aws:s3:::amazon-ssm-ca-central-1/*",
      "arn:aws:s3:::amazon-ssm-packages-ca-central-1/*",
      "arn:aws:s3:::ca-central-1-birdwatcher-prod/*",
      "arn:aws:s3:::aws-ssm-document-attachments-ca-central-1/*",
      "arn:aws:s3:::patch-baseline-snapshot-ca-central-1/*",
      "arn:aws:s3:::aws-ssm-ca-central-1/*",
      "arn:aws:s3:::aws-patchmanager-macos-ca-central-1/*"
    ]
  }
# Todo: add ses
#  statement {
#    sid       = "AllowSesSend"
#    effect    = "Allow"
#    actions   = ["ses:SendRawEmail"]
#    resources = [var.ses_identity]
#  }

}

resource "aws_iam_policy" "eb_instance_policy" {
  name   = "${var.env_version}-EB-Instance-Policy"
  policy = data.aws_iam_policy_document.eb_policy.json
  tags   = {
    Env = var.env_version
  }
}
resource "aws_iam_role_policy_attachment" "eb_instance_policy" {
  policy_arn = aws_iam_policy.eb_instance_policy.arn
  role       = aws_iam_role.eb_instance.name
}
resource "aws_acm_certificate" "eb" {
  domain_name       = local.eb_cname
  validation_method = "DNS"

  tags = {
    Name = "${var.env_version}-BackendHTTPS-Cert"
    Env  = var.env_version
  }
}

resource "aws_route53_record" "verif_eb" {
  for_each = {
  for dvo in aws_acm_certificate.eb.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    record = dvo.resource_record_value
    type   = dvo.resource_record_type
  }
  }

  allow_overwrite = true
  //noinspection HILUnresolvedReference
  name            = each.value.name
  //noinspection HILUnresolvedReference
  records         = [
    each.value.record
  ]
  ttl     = 60
  //noinspection HILUnresolvedReference
  type    = each.value.type
  zone_id = var.zone_id
}

resource "aws_acm_certificate_validation" "eb" {
  certificate_arn         = aws_acm_certificate.eb.arn
  validation_record_fqdns = [for record in aws_route53_record.verif_eb : record.fqdn]
}


resource "aws_elastic_beanstalk_environment" "backend" {
  name         = "${var.env_version}-Backend-EB"
  application  = var.eb_app_name
  // uncomment when creating
    solution_stack_name = "64bit Amazon Linux 2 v3.3.13 running PHP 8.0"
  cname_prefix = lower("${var.env_version}-${var.app_name}-eb")
  description  = "https://${var.domain_name}"
  tier         = "WebServer"

  setting {
    name      = "DisableIMDSv1"
    namespace = "aws:autoscaling:launchconfiguration"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "XRayEnabled"
    namespace = "aws:elasticbeanstalk:xray"
    resource  = ""
    value     = var.xray_enabled
  }
  setting {
    name      = "EC2KeyName"
    namespace = "aws:autoscaling:launchconfiguration"
    resource  = ""
    value     = var.ec2_key_name
  }
  setting {
    name      = "ELBSubnets"
    namespace = "aws:ec2:vpc"
    resource  = ""
    value     = join(",", sort(var.vpc_subnets_public_ids))
  }
  setting {
    name      = "IamInstanceProfile"
    namespace = "aws:autoscaling:launchconfiguration"
    resource  = ""
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }
  setting {
    name      = "IgnoreHealthCheck"
    namespace = "aws:elasticbeanstalk:command"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "EnableCapacityRebalancing"
    namespace = "aws:autoscaling:asg"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "SharedLoadBalancer"
    namespace = "aws:elbv2:loadbalancer"
    resource  = ""
    value     = var.shared_alb_arn
  }
  setting {
    name      = "ListenerEnabled"
    namespace = "aws:elbv2:listener:443"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "ManagedSecurityGroup"
    namespace = "aws:elbv2:loadbalancer"
    resource  = ""
    value     = var.sg_lb_id
  }
  setting {
    name      = "SecurityGroups"
    namespace = "aws:elbv2:loadbalancer"
    resource  = ""
    value     = var.sg_lb_id
  }
  setting {
    name      = "MaxSize"
    namespace = "aws:autoscaling:asg"
    resource  = ""
    value     = var.asg_max_size
  }
  setting {
    name      = "MinSize"
    namespace = "aws:autoscaling:asg"
    resource  = ""
    value     = var.asg_min_size
  }
  setting {
    name      = "Protocol"
    namespace = "aws:elbv2:listener:443"
    resource  = ""
    value     = "HTTPS"
  }
  setting {
    name      = "RootVolumeSize"
    namespace = "aws:autoscaling:launchconfiguration"
    resource  = ""
    value     = "20"
  }
  setting {
    name      = "RootVolumeType"
    namespace = "aws:autoscaling:launchconfiguration"
    resource  = ""
    value     = "gp3"
  }
  setting {
    name      = "RootVolumeIOPS"
    namespace = "aws:autoscaling:launchconfiguration"
    resource  = ""
    value     = "3000"
  }
#  setting {
#    name      = "HealthCheckPath"
#    namespace = "aws:elasticbeanstalk:environment:process:default"
#    resource  = ""
#    value     = "/api/checkstatus"
#  }
  setting {
    name      = "AssociatePublicIpAddress"
    namespace = "aws:ec2:vpc"
    resource  = ""
    value     = "false"
  }

  setting {
    name      = "ConfigDocument"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    resource  = ""
    value     = "{\"Version\":1,\"CloudWatchMetrics\":{\"Instance\":{\"RootFilesystemUtil\":60,\"CPUIrq\":null,\"LoadAverage5min\":null,\"ApplicationRequests5xx\":null,\"ApplicationRequests4xx\":null,\"CPUUser\":null,\"LoadAverage1min\":null,\"ApplicationLatencyP50\":null,\"CPUIdle\":null,\"InstanceHealth\":60,\"ApplicationLatencyP95\":null,\"ApplicationLatencyP85\":null,\"ApplicationLatencyP90\":null,\"CPUSystem\":null,\"ApplicationLatencyP75\":null,\"CPUSoftirq\":null,\"ApplicationLatencyP10\":null,\"ApplicationLatencyP99\":null,\"ApplicationRequestsTotal\":null,\"ApplicationLatencyP99.9\":null,\"ApplicationRequests3xx\":null,\"ApplicationRequests2xx\":null,\"CPUIowait\":null,\"CPUNice\":null},\"Environment\":{\"InstancesSevere\":null,\"InstancesDegraded\":null,\"ApplicationRequests5xx\":null,\"ApplicationRequests4xx\":null,\"ApplicationLatencyP50\":null,\"ApplicationLatencyP95\":null,\"ApplicationLatencyP85\":null,\"InstancesUnknown\":null,\"ApplicationLatencyP90\":null,\"InstancesInfo\":null,\"InstancesPending\":null,\"ApplicationLatencyP75\":null,\"ApplicationLatencyP10\":null,\"ApplicationLatencyP99\":null,\"ApplicationRequestsTotal\":null,\"InstancesNoData\":null,\"ApplicationLatencyP99.9\":null,\"ApplicationRequests3xx\":null,\"ApplicationRequests2xx\":null,\"InstancesOk\":null,\"InstancesWarning\":null}},\"Rules\":{\"Environment\":{\"ELB\":{\"ELBRequests4xx\":{\"Enabled\":false}},\"Application\":{\"ApplicationRequests4xx\":{\"Enabled\":false}}}}}"
  }
  setting {
    name      = "RetentionInDays"
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    resource  = ""
    value     = 90
  }
  setting {
    name      = "StreamLogs"
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "DefaultProcess"
    namespace = "aws:elbv2:listener:443"
    resource  = ""
    value     = "default"
  }
  setting {
    name      = "EnableSpot"
    namespace = "aws:ec2:instances"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "EnvironmentType"
    namespace = "aws:elasticbeanstalk:environment"
    resource  = ""
    value     = "LoadBalanced"
  }
  setting {
    name      = "InstanceTypes"
    namespace = "aws:ec2:instances"
    resource  = ""
    value     = var.ec2_instance_size
  }
  setting {
    name      = "LoadBalancerType"
    namespace = "aws:elasticbeanstalk:environment"
    resource  = ""
    value     = "application"
  }
  setting {
    name      = "LowerThreshold"
    namespace = "aws:autoscaling:trigger"
    resource  = ""
    value     = "50"
  }
  setting {
    name      = "ManagedActionsEnabled"
    namespace = "aws:elasticbeanstalk:managedactions"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "InstanceRefreshEnabled"
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    resource  = ""
    value     = "false"
  }
  setting {
    name      = "MeasureName"
    namespace = "aws:autoscaling:trigger"
    resource  = ""
    value     = "CPUUtilization"
  }
  //  setting {
  //    name      = "Notification Endpoint"
  //    namespace = "aws:elasticbeanstalk:sns:topics"
  //    resource  = ""
  //    value     = var.sns_sysops
  //  }
  setting {
    name      = "PreferredStartTime"
    namespace = "aws:elasticbeanstalk:managedactions"
    resource  = ""
    value     = "Tue:09:00"
  }
#  FIXME: should allow from master
  setting {
    name      = "SSHSourceRestriction"
    namespace = "aws:autoscaling:launchconfiguration"
    resource  = ""
    value     = "tcp,22,22,${var.wks_ip}/32"
  }
  setting {
    name      = "SSLCertificateArns"
    namespace = "aws:elbv2:listener:443"
    resource  = ""
    value     = aws_acm_certificate.eb.arn
  }
  setting {
    name      = "SSLPolicy"
    namespace = "aws:elbv2:listener:443"
    resource  = ""
    value     = "ELBSecurityPolicy-FS-1-2-Res-2019-08"
  }
  setting {
    name      = "SecurityGroups"
    namespace = "aws:autoscaling:launchconfiguration"
    resource  = ""
    value     = aws_security_group.app.id
  }
  setting {
    name      = "ServiceRole"
    namespace = "aws:elasticbeanstalk:environment"
    resource  = ""
    value     = var.eb_service_role_arn
  }
  setting {
    name      = "SpotFleetOnDemandAboveBasePercentage"
    namespace = "aws:ec2:instances"
    resource  = ""
    value     = "0"
  }
  setting {
    name      = "Subnets"
    namespace = "aws:ec2:vpc"
    resource  = ""
    value     = join(",", var.vpc_subnets_private_ids)
  }
  setting {
    name      = "Unit"
    namespace = "aws:autoscaling:trigger"
    resource  = ""
    value     = "Percent"
  }
  setting {
    name      = "UpdateLevel"
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    resource  = ""
    value     = "minor"
  }
  setting {
    name      = "UpperThreshold"
    namespace = "aws:autoscaling:trigger"
    resource  = ""
    value     = "90"
  }
  setting {
    name      = "VPCId"
    namespace = "aws:ec2:vpc"
    resource  = ""
    value     = var.vpc_id
  }

  setting {
    name      = "AWS_REGION"
    namespace = "aws:elasticbeanstalk:application:environment"
    resource  = ""
    value     = var.aws_region
  }

  setting {
    name      = "ENV"
    namespace = "aws:elasticbeanstalk:application:environment"
    resource  = ""
    value     = var.env_version
  }
  setting {
    name      = "PROJECT"
    namespace = "aws:elasticbeanstalk:application:environment"
    resource  = ""
    value     = var.env_project
  }
  setting {
    name      = "CLIENT"
    namespace = "aws:elasticbeanstalk:application:environment"
    resource  = ""
    value     = var.env_client
  }
  setting {
    name      = "DEBUG"
    namespace = "aws:elasticbeanstalk:application:environment"
    resource  = ""
    value     = "1"
  }
  setting {
    name      = "EnhancedHealthAuthEnabled"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "DeploymentPolicy"
    namespace = "aws:elasticbeanstalk:command"
    resource  = ""
    value     = "Rolling"
  }
  setting {
    name      = "BatchSizeType"
    namespace = "aws:elasticbeanstalk:command"
    resource  = ""
    value     = "Percentage"
  }
  setting {
    name      = "BatchSize"
    namespace = "aws:elasticbeanstalk:command"
    resource  = ""
    value     = "50"
  }
  setting {
    name      = "RollingUpdateEnabled"
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    resource  = ""
    value     = "true"
  }
  setting {
    name      = "RollingUpdateType"
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    resource  = ""
    value     = "Health"
  }
  setting {
    name      = "MinInstancesInService"
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    resource  = ""
    value     = "1"
  }
  setting {
    name      = "MaxBatchSize"
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    resource  = ""
    value     = "2"
  }
  setting {
    name      = "Period"
    namespace = "aws:autoscaling:trigger"
    resource  = ""
    value     = "1"
  }
  setting {
    name      = "BreachDuration"
    namespace = "aws:autoscaling:trigger"
    resource  = ""
    value     = "2"
  }

  setting {
    name      = "LowerBreachScaleIncrement"
    namespace = "aws:autoscaling:trigger"
    resource  = ""
    value     = "-2"
  }
  setting {
    name      = "UpperBreachScaleIncrement"
    namespace = "aws:autoscaling:trigger"
    resource  = ""
    value     = "2"
  }

  tags = {
    Env = var.env_version
  }
}

resource "aws_route53_record" "eb_cname" {
  name    = local.eb_cname
  type    = "CNAME"
  zone_id = var.zone_id
  ttl     = 600
  records = [
    lower(aws_elastic_beanstalk_environment.backend.cname)
  ]
  #  depends_on = [
  #    aws_elastic_beanstalk_environment.backend
  #  ]

  allow_overwrite = true
}
