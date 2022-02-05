output "dlq_arn" {
    value = aws_sqs_queue.dlq.arn
}

output "principal_arn" {
    value = aws_sqs_queue.principal.arn
}