locals {
  service_name = format("service_%s", var.name)
}

resource "aws_iam_role" "iam_for_lambda" {
  name = format("iam_role_lambda_%s", local.service_name)

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "service_lambda" {

  function_name = local.service_name
  role          = aws_iam_role.iam_for_lambda.arn

  package_type = var.lambda_code_type == "zip" ? "Zip" : "Image"

  # If using container, image_uri is required
  image_uri = var.lambda_code_type == "container" ? var.lambda_image : null

  # If using zip, filename, source_code_hash, runtime and handler are required
  filename         = var.lambda_code_type == "zip" ? var.lambda_code.path : null
  source_code_hash = var.lambda_code_type == "zip" ? filebase64sha256(var.lambda_code.path) : null
  runtime          = var.lambda_code_type == "zip" ? var.lambda_code.runtime : null
  handler          = var.lambda_code_type == "zip" ? var.lambda_code.handler : null

  environment {
    variables = merge({
      SERVICE = var.name
    }, var.environment_variables)
  }


  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.service_log,
  ]

  lifecycle {
    ignore_changes = [
      image_uri
    ]
  }
}

resource "aws_cloudwatch_log_group" "service_log" {
  name              = "/aws/lambda/${local.service_name}"
  retention_in_days = 3
}

resource "aws_iam_policy" "lambda_ec2_networking" {
  name        = "lambda_ec2_networking_${local.service_name}"
  path        = "/"
  description = "IAM policy for ec2 networking from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "lambda_ec2_networking" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_ec2_networking.arn
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging_${local.service_name}"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "additional_policy" {
  name        = "additional_policy_${local.service_name}"
  path        = "/"
  description = "IAM policy for additional permissions for lambda"

  policy = var.additional_lambda_execution_policy
}

resource "aws_iam_role_policy_attachment" "additional_policy" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.additional_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

# API Gateway
resource "aws_apigatewayv2_api" "service_apig" {
  name          = local.service_name
  protocol_type = "HTTP"

  description = "Api Gateway for ${local.service_name} Service."

  route_selection_expression   = "$request.method $request.path"
  api_key_selection_expression = "$request.header.x-api-key"
  # Change to true
  disable_execute_api_endpoint = false
  cors_configuration {
    // allow_credentials = lookup(cors_configuration.value, "allow_credentials", null)
    allow_headers = [
      "content-type",
      "x-amz-date",
      "authorization",
      "x-api-key",
      "x-amz-security-token",
      "x-amz-user-agent"
    ]

    allow_methods = ["*"]
    allow_origins = ["*"]
    // expose_headers    = lookup(cors_configuration.value, "expose_headers", null)
    // max_age           = lookup(cors_configuration.value, "max_age", null)

  }

  tags = merge(var.tags, { Name = local.service_name })

}

resource "aws_lambda_permission" "lambda_execute_permission" {

  statement_id  = "${local.service_name}_apig_execute_permission"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.service_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_apigatewayv2_api.service_apig.execution_arn}/*/*/*"
}

# Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.service_apig.id
  name        = "$default"
  auto_deploy = true

  tags = var.tags

  # Bug in terraform-aws-provider with perpetual diff
  lifecycle {
    ignore_changes = [deployment_id]
  }
}

# Mapping
resource "aws_apigatewayv2_api_mapping" "this" {
  count       = tobool(var.domain == null) ? 0 : 1
  api_id      = aws_apigatewayv2_api.service_apig.id
  domain_name = aws_apigatewayv2_domain_name.this[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

# Route 
resource "aws_apigatewayv2_route" "this" {
  for_each  = var.integrations
  api_id    = aws_apigatewayv2_api.service_apig.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"

  api_key_required                    = lookup(each.value, "api_key_required", null)
  authorization_type                  = lookup(each.value, "authorization_type", "NONE")
  authorizer_id                       = lookup(each.value, "authorizer_id", null)
  model_selection_expression          = lookup(each.value, "model_selection_expression", null)
  operation_name                      = lookup(each.value, "operation_name", null)
  route_response_selection_expression = lookup(each.value, "route_response_selection_expression", null)
}

# Integration
resource "aws_apigatewayv2_integration" "this" {
  for_each = var.integrations

  lifecycle {
    create_before_destroy = true
  }

  api_id      = aws_apigatewayv2_api.service_apig.id
  description = lookup(each.value, "description", null)

  integration_type       = "AWS_PROXY"
  payload_format_version = "2.0"

  integration_subtype = lookup(each.value, "integration_subtype", null)
  integration_method  = lookup(each.value, "integration_method", lookup(each.value, "integration_subtype", null) == null ? "POST" : null)
  integration_uri     = aws_lambda_function.service_lambda.arn

  connection_type = "INTERNET"

  timeout_milliseconds      = lookup(each.value, "timeout_milliseconds", null)
  passthrough_behavior      = lookup(each.value, "passthrough_behavior", null)
  content_handling_strategy = lookup(each.value, "content_handling_strategy", null)
  credentials_arn           = lookup(each.value, "credentials_arn", null)
  request_parameters        = try(jsondecode(each.value["request_parameters"]), each.value["request_parameters"], null)

  dynamic "tls_config" {
    for_each = flatten([try(jsondecode(each.value["tls_config"]), each.value["tls_config"], [])])
    content {
      server_name_to_verify = tls_config.value["server_name_to_verify"]
    }
  }

  dynamic "response_parameters" {
    for_each = flatten([try(jsondecode(each.value["response_parameters"]), each.value["response_parameters"], [])])
    content {
      status_code = response_parameters.value["status_code"]
      mappings    = response_parameters.value["mappings"]
    }
  }
}


# Domain (If passed)
resource "aws_apigatewayv2_domain_name" "this" {
  count = tobool(var.domain == null) ? 0 : 1

  domain_name = var.domain.domain

  domain_name_configuration {
    certificate_arn = var.domain.ssl_certificate
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

resource "aws_route53_record" "api" {
  count = tobool(var.domain == null) ? 0 : 1

  zone_id = var.domain.hosting_zone
  name    = aws_apigatewayv2_domain_name.this[0].domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.this[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.this[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}