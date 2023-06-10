# Terraform AWS Lambda API
AWS Lambda API from ECR Image

Creates a service using Cloudfront, apigateway, lambda (container image based) and respective image 

## Inputs (variables)

| Variable       | Description                                                                                                                     |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `name`         | Name of the service                                                                                                             |
| `domain`       | Domain name of the service. creates a stand alone service (E.g. https://api.example.com/<YOUR_API_HERE>)  |
| `lambda_image` | URI of your container image for this function. Defaults to `public.ecr.aws/m0q0z2r6/lambda-container-service:latest`.           |
| `environment`  | Prefix environment to resources identifiers/names created by this module.                                                       |
| `env_vars`     | map of environment variables to be set to lambda function.                                                                      |
| `tags`         | map of tags to be added to all the resources to be created by this module. name and environment are automatically added.        |

## Outputs
| Output                        | Description                                 |
| ----------------------------- | ------------------------------------------- |
| `name`                        | Name of the service.                        |
| `endpoint`                    | http(s) endpoint of the service             |
| `lambda_arn`                  | ARN of created lambda function.             |
| `apig_arn`                    | ARN of API Gateway.                         |
