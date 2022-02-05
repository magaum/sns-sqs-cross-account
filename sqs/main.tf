provider "aws" {
  region  = "us-east-1"
  profile = "sqs_account"
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "this" {
  description             = "SQS kms"
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
      "Sid": "Allow access for Key User (SQS/SNS Service Principals)",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "sqs.amazonaws.com",
          "sns.amazonaws.com"
        ]
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
  name          = "alias/sqs-kms"
  target_key_id = aws_kms_key.this.key_id
}


resource "aws_sqs_queue" "dlq" {
  name                              = "cross-account-dlq"
  kms_master_key_id                 = aws_kms_alias.this.id
  kms_data_key_reuse_period_seconds = 300
}

resource "aws_sqs_queue_policy" "dlq_policy" {
  queue_url = aws_sqs_queue.dlq.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "AllowQueueSendMessagesToDQL",
        "Effect": "Allow",
        "Action": "sqs:SendMessage",
        "Resource": "${aws_sqs_queue.dlq.arn}",
        "Condition": {
            "ArnEquals": {
                "aws:SourceArn": "${aws_sqs_queue.principal.arn}"
            }
        }
    }
  ]
}
POLICY
}

resource "aws_sqs_queue" "principal" {
  name                              = "cross-account-sqs"
  kms_master_key_id                 = aws_kms_alias.this.id
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 4
  })

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue",
    sourceQueueArns   = ["${aws_sqs_queue.dlq.arn}"]
  })
}
resource "aws_sqs_queue_policy" "principal_policy" {
  queue_url = aws_sqs_queue.principal.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReceiveMessagesFromSNSCrossAccount",
      "Effect": "Allow",
      "Principal": {
          "Service": "sns.amazonaws.com"
      },
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.principal.arn}",
      "Condition":{
        "ArnEquals":{
            "aws:SourceArn":"arn:aws:sns:us-east-1:${var.sns_account}:cross-account-sns"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_sns_topic_subscription" "cross_account_subscribe" {
  topic_arn = "arn:aws:sns:us-east-1:${var.sns_account}:cross-account-sns"
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.principal.arn
}
