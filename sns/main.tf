provider "aws" {
  region = "us-east-1"
  profile = "sns_account"
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
          "AWS": "${var.sqs_account}"
      },
      "Action": "sns:Subscribe",
      "Resource": "${aws_sns_topic.this.arn}"
    }
  ]
}
POLICY
}
