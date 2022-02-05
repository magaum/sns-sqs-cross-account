provider "aws" {
  region  = "us-east-1"
  profile = "sqs_account"
}

resource "aws_sqs_queue" "dlq" {
  name = "cross-account-dlq"
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
  name = "cross-account-sqs"
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
