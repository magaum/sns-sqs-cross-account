terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "account_2"
}

resource "aws_sns_topic" "this" {
  name         = "cross-account-sns"
  display_name = "cross-account-sns"
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
          "AWS": "${var.cross_account_id}"
      },
      "Action": "sns:Subscribe",
      "Resource": "${aws_sns_topic.this.arn}"
    }
  ]
}
POLICY
}
