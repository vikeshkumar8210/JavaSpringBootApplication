provider "aws" {
  region = "us-east-1"  
}

resource "aws_lambda_function" "spring_boot_lambda" {
  filename         = "path/to/your/spring-boot-application.jar"
  function_name    = "spring-boot-lambda"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "com.example.mypkg::HelloWorldApplication"
  runtime          = "java17"
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE = "lambda"
    }
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

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

resource "aws_iam_policy_attachment" "lambda_exec_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_exec_role.name
}

resource "aws_apigatewayv2_api" "api_gateway" {
  name          = "spring-boot-api"
  protocol_type = "HTTP"
}

resource "aws_lambda_permission" "apigateway_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.spring_boot_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = aws_apigatewayv2_api.api_gateway.execution_arn
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                = aws_apigatewayv2_api.api_gateway.id
  integration_type      = "AWS_PROXY"
  integration_uri       = aws_lambda_function.spring_boot_lambda.invoke_arn
  integration_method    = "POST"
  integration_timeout_milliseconds = 30000
}

resource "aws_apigatewayv2_route" "api_gateway_route" {
  api_id    = aws_apigatewayv2_api.api_gateway.id
  route_key = "$default"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "api_gateway_stage" {
  api_id      = aws_apigatewayv2_api.api_gateway.id
  name        = "prod"
  auto_deploy = true
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.api_gateway.api_endpoint
}
