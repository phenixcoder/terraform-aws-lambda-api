data "aws_region" "current" {}

output "name" {
  value = var.name
}
output "endpoint" {
  value = tobool(var.domain == null) ? "${aws_apigatewayv2_api.service_apig.id}.execute-api.${data.aws_region.current.name}.amazonaws.com" : aws_apigatewayv2_domain_name.this[0].domain_name
}

output "apig_endpoint" {
  value = aws_apigatewayv2_api.service_apig.api_endpoint
}
output "lambda_arn" {
  value = aws_lambda_function.service_lambda.arn
}
output "apig_arn" {
  value = aws_apigatewayv2_api.service_apig.arn
}
