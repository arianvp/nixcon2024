resource "aws_iam_role" "deploy" {
  name = "deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRole"
        Principal = { AWS = data.aws_caller_identity.self.arn }
      }
    ]
  })
}

data "aws_iam_policy_document" "nixos_deploy" {
  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = [module.nixos_deploy_ssm_document.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Name"
      values   = ["nixos"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["ssm:ListCommands", "ssm:ListCommandInvocations"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "nixos_deploy" {
  policy = data.aws_iam_policy_document.nixos_deploy.json
}


resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.nixos_deploy.arn
}

