variable "name" {
  type        = string
  description = "Service Name"
}

variable "domain" {
  type = object({
    domain          = string
    hosting_zone    = string
    ssl_certificate = string
  })
  default = null
}

variable "lambda_image" {
  type        = string
  default     = "045615149555.dkr.ecr.ap-southeast-2.amazonaws.com/lambda-container-service:latest"
  description = "URI of your container image for this function"
}
variable "additional_lambda_execution_policy" {
  type        = string
  default     = null
  description = "ARN of additional policy you want to attatch to lambda execution role."
}

variable "environment_variables" {
  default     = {}
  type        = map(string)
  description = "Map of environment variables to be set to lambda function"
}

variable "integrations" {
  description = "Map of API gateway routes with integrations"
  type        = map(any)
  default     = {}
}

variable "tags" {
  default     = {}
  type        = map(string)
  description = "Map of tags to be added to all the resources to be created by this module"
}