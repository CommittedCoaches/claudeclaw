# --- CloudTrail ---

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "claudeclaw-cloudtrail-${var.account_id}"
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${var.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
    ]
  })
}

resource "aws_cloudtrail" "audit" {
  name                       = "claudeclaw-audit"
  s3_bucket_name             = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail      = true
  enable_log_file_validation = true

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# --- GitHub Actions OIDC Deploy Role ---

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions_deploy" {
  name        = "claudeclaw-github-actions-deploy"
  description = "Allows GitHub Actions to deploy ClaudeClaw to EC2 instances via SSM"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:CommittedCoaches/claudeclaw:ref:refs/heads/master"
        }
      }
    }]
  })

  tags = {
    Name = "claudeclaw-github-actions-deploy"
  }
}

resource "aws_iam_policy" "github_actions_deploy" {
  name        = "claudeclaw-github-actions-deploy"
  description = "EC2 describe + SSM send-command for deploying via git pull"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
        ]
        Resource = "*"
      },
    ]
  })

  tags = {
    Name = "claudeclaw-github-actions-deploy"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_deploy" {
  role       = aws_iam_role.github_actions_deploy.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

# --- GitHub Actions Secrets Role (for devs to self-service store tokens) ---

resource "aws_iam_role" "github_actions_secrets" {
  name        = "claudeclaw-github-actions-secrets"
  description = "Allows GitHub Actions to write per-dev secrets to Secrets Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:CommittedCoaches/claudeclaw:*"
        }
      }
    }]
  })

  tags = { Name = "claudeclaw-github-actions-secrets" }
}

resource "aws_iam_policy" "github_actions_secrets" {
  name        = "claudeclaw-github-actions-secrets"
  description = "Create/update per-dev secrets in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:TagResource",
        ]
        Resource = "arn:aws:secretsmanager:us-east-2:${var.account_id}:secret:claudeclaw/dev/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_secrets" {
  role       = aws_iam_role.github_actions_secrets.name
  policy_arn = aws_iam_policy.github_actions_secrets.arn
}

# --- GitHub Actions Terraform Role (for infra provisioning with admin approval) ---

resource "aws_iam_role" "github_actions_terraform" {
  name        = "claudeclaw-github-actions-terraform"
  description = "Allows GitHub Actions to run terraform apply for ClaudeClaw infra"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:CommittedCoaches/claudeclaw:environment:production"
        }
      }
    }]
  })

  tags = { Name = "claudeclaw-github-actions-terraform" }
}

resource "aws_iam_policy" "github_actions_terraform" {
  name        = "claudeclaw-github-actions-terraform"
  description = "Permissions for terraform apply — EC2, IAM, Secrets Manager, S3 state, networking"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # EC2 — create/manage dev instances
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StartInstances",
          "ec2:StopInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeTags",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeImages",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeVolumes",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceAttribute",
          "ec2:ModifyInstanceAttribute",
        ]
        Resource = "*"
      },
      # IAM — manage dev instance roles
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
          "iam:TagPolicy",
        ]
        Resource = [
          "arn:aws:iam::${var.account_id}:role/claudeclaw-*",
          "arn:aws:iam::${var.account_id}:instance-profile/claudeclaw-*",
          "arn:aws:iam::${var.account_id}:policy/claudeclaw-*",
          "arn:aws:iam::aws:policy/*",
        ]
      },
      # Secrets Manager — read dev tokens + manage shared secrets
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue",
          "secretsmanager:TagResource",
          "secretsmanager:DeleteSecret",
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-2:${var.account_id}:secret:claudeclaw/*",
        ]
      },
      # S3 — terraform state
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketVersioning",
          "s3:GetBucketLocation",
        ]
        Resource = [
          "arn:aws:s3:::committed-coaches-terraform-state",
          "arn:aws:s3:::committed-coaches-terraform-state/*",
        ]
      },
      # CloudTrail + S3 for security module
      {
        Effect = "Allow"
        Action = [
          "cloudtrail:*",
          "s3:CreateBucket",
          "s3:PutBucketPolicy",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketPolicy",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketPublicAccessBlock",
        ]
        Resource = [
          "arn:aws:cloudtrail:*:${var.account_id}:trail/claudeclaw-*",
          "arn:aws:s3:::claudeclaw-cloudtrail-${var.account_id}",
          "arn:aws:s3:::claudeclaw-cloudtrail-${var.account_id}/*",
        ]
      },
      # SSM — for deploy workflow + onboarding
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:DescribeInstanceInformation",
        ]
        Resource = "*"
      },
      # STS
      {
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      },
      # OIDC provider (read-only, needed by security module)
      {
        Effect = "Allow"
        Action = [
          "iam:GetOpenIDConnectProvider",
        ]
        Resource = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_terraform" {
  role       = aws_iam_role.github_actions_terraform.name
  policy_arn = aws_iam_policy.github_actions_terraform.arn
}

# --- MFA Enforcement Policy ---

resource "aws_iam_policy" "mfa_enforcement" {
  name        = "claudeclaw-mfa-enforcement"
  description = "Deny all actions except MFA self-service when MFA is not present"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowMFASelfService"
        Effect = "Allow"
        Action = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:ListMFADevices",
          "iam:GetUser",
          "iam:ChangePassword",
        ]
        Resource = [
          "arn:aws:iam::${var.account_id}:mfa/*",
          "arn:aws:iam::${var.account_id}:user/$${aws:username}",
        ]
      },
      {
        Sid       = "DenyAllWithoutMFA"
        Effect    = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:ResyncMFADevice",
          "iam:ListMFADevices",
          "iam:GetUser",
          "iam:ChangePassword",
          "sts:GetSessionToken",
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      },
    ]
  })
}
