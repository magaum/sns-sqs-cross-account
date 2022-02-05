provider "aws" {
  region  = "us-east-1"
  profile = "sns_account"
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "this" {
  description             = "SNS kms"
  deletion_window_in_days = 10
  policy                  = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow access for Key Administrator",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${data.aws_caller_identity.current.account_id}"
      },
      "Action": [
        "kms:GenerateDataKey*",
        "kms:Decrypt",
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow access for Key User (SNS Service Principal)",
      "Effect": "Allow",
      "Principal": {
        "Service": "sns.amazonaws.com"
      },
      "Action": [
        "kms:GenerateDataKey*",
        "kms:Decrypt"
      ],
      "Resource": "*"
    }
  ]
}
  POLICY
}

resource "aws_kms_alias" "this" {
  name          = "alias/sns-kms"
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_sns_topic" "this" {
  name              = "cross-account-sns"
  display_name      = "cross-account-sns"
  kms_master_key_id = aws_kms_alias.this.id
}

resource "aws_sns_topic_policy" "this" {
  arn = aws_sns_topic.this.arn

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountSubscription",
      "Effect": "Allow",
      "Principal": {
          "AWS": "${var.sqs_account}"
      },
      "Action": "sns:Subscribe",
      "Resource": "${aws_sns_topic.this.arn}"
    }
  ]
}
POLICY
}
