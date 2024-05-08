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
output "lambda_execution_role" {
  value = aws_iam_role.iam_for_lambda.name
}
output "apig_arn" {
  value = aws_apigatewayv2_api.service_apig.arn
}
output "exposed_params" {
  value = var.expose_outputs_to_parameters && var.parameter_prefix != "" ? [
    aws_ssm_parameter.endpoint[0].name,
    aws_ssm_parameter.lambda[0].name,
    aws_ssm_parameter.apig_endpoint[0].name,
    aws_ssm_parameter.apig_arn[0].name
  ] : []
}
