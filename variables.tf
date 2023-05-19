variable "name" {
  description = "The name for the GraphQL API."
  type        = string
  nullable    = false
}

variable "authentication_types" {
  description = "A list of authentication types. Valid values: `API_KEY`, `AWS_IAM`, `AMAZON_COGNITO_USER_POOLS`, or `OPENID_CONNECT`."
  type        = list(string)
  nullable    = false
  validation {
    condition = (
      length(var.authentication_types) > 0
    )
    error_message = "The `authentication_types` variable must have at least one element."
  }
  validation {
    condition = (
      length(setsubtract(var.authentication_types, ["API_KEY", "AWS_IAM", "AMAZON_COGNITO_USER_POOLS", "OPENID_CONNECT"])) == 0
    )
    error_message = "The `authentication_types` variable only supports the following types: `API_KEY`, `AWS_IAM`, `AMAZON_COGNITO_USER_POOLS`, and `OPENID_CONNECT`."
  }
}

variable "schema" {
  description = "The schema definition, in GraphQL schema language format."
  type        = string
  default     = null
  nullable    = true
}

variable "tags" {
  description = "A mapping of tags to assign to the AppSync resource."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "openid_connect_config" {
  description = "The OpenID configuration block."
  type = object({
    issuer    = string
    auth_ttl  = optional(number, null)
    client_id = optional(string, null)
    iat_ttl   = optional(number, null)
  })
  default  = null
  nullable = true
}

variable "user_pool_config" {
  description = "The Cognito User Pool configuration block."
  type = object({
    default_action      = optional(string, null)
    user_pool_id        = string
    app_id_client_regex = optional(string, null)
    aws_region          = optional(string, null)
  })
  default  = null
  nullable = true
}

variable "lambda_authorizer_config" {
  description = "The Lambda Authorizer configuration block."
  type = object({
    authorizer_uri                   = string
    authorizer_result_ttl_in_seconds = optional(number, null)
    identity_validation_expression   = optional(string, null)
  })
  default  = null
  nullable = true
}

variable "xray_enabled" {
  description = "Whether tracing with X-ray is enabled."
  type        = bool
  default     = false
  nullable    = false
}

variable "logging_enabled" {
  description = "Whether logging should be enabled."
  type        = bool
  default     = true
  nullable    = false
}

variable "logging_level" {
  description = "The logging level. Valid values: `ALL`, `ERROR`, or `NONE`."
  type        = string
  default     = "ALL"
  nullable    = false
}

variable "log_retention_days" {
  description = "How many days to keep the AppSync logs in CloudWatch for."
  type        = number
  default     = 0
  nullable    = false
}

variable "logging_exclude_verbose_content" {
  description = "Set to `true` to exclude sections that contain information such as headers, context, and evaluated mapping templates, regardless of logging level."
  type        = bool
  default     = false
  nullable    = false
}

variable "create_custom_domain" {
  description = "Whether to configure a custom domain name for this API."
  type        = bool
  default     = false
  nullable    = false
}

variable "custom_domain" {
  description = "The custom domain name to associate with the API. Only used if `create_custom_domain` is `true`."
  type        = string
  default     = null
  nullable    = true
}

variable "custom_domain_description" {
  description = "A description for the custom domain to associate with the API. Only used if `create_custom_domain` is `true`."
  type        = string
  default     = null
  nullable    = true
}

variable "custom_domain_acm_certificate_arn" {
  description = "The ARN of the ACM certificate to use for the custom domain name. Only used if `create_custom_domain` is `true`."
  type        = string
  default     = null
  nullable    = true
}

variable "datasources" {
  description = "A list of AppSync datasource resources (`aws_appsync_datasource` resource objects). This list must contain all datasource resources that are used by any functions in the `functions` input variable or any unit resolvers in the `unit_resolvers` input variable."
  type = list(object({
    api_id = string
    name   = string
    type   = string
    arn    = string
  }))
  default  = []
  nullable = false
}

variable "functions" {
  description = "A map of key-map pairs of AppSync functions. The keys are only used for unique identification (e.g. a combination of datasource name and function name). The values are maps themselves."
  type = map(object({
    name                      = string
    datasource_name           = string
    request_mapping_template  = string
    response_mapping_template = string
  }))
  default = {}
}

variable "unit_resolvers" {
  description = "A map of key-map pairs of AppSync unit resolvers. The keys are only used for unique identification (e.g. a combination of datasource name and resolver name). The values are maps themselves."
  type = map(object({
    name                      = string
    type                      = string
    datasource_name           = string
    request_mapping_template  = string
    response_mapping_template = string
  }))
  default = {}
}

variable "pipeline_resolvers" {
  description = "A map of key-map pairs of AppSync pipeline resolvers. The keys are only used for unique identification (e.g. a combination of datasource name and resolver name). The values are maps themselves. The 'functions' field within the value map is a list of function keys, corresponding with the map keys provided for the 'functions' variable."
  type = map(object({
    name                      = string
    type                      = string
    request_mapping_template  = string
    response_mapping_template = string
    functions                 = list(string)
  }))
  default = {}
}

module "assert_cognito_config" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~> 0.2.4"
  error_message = "If `AMAZON_COGNITO_USER_POOLS` is provided as an authentication type in the `authentication_types` variable, the `user_pool_config` variable must also be provided."
  condition     = !(contains(var.authentication_types, "AMAZON_COGNITO_USER_POOLS") && var.user_pool_config == null)
}

module "assert_openid_config" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~> 0.2.4"
  error_message = "If `OPENID_CONNECT` is provided as an authentication type in the `authentication_types` variable, the `openid_connect_config` variable must also be provided."
  condition     = !(contains(var.authentication_types, "OPENID_CONNECT") && var.openid_connect_config == null)
}

module "assert_lambda_config" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~> 0.2.4"
  error_message = "If `AWS_LAMBDA` is provided as an authentication type in the `authentication_types` variable, the `lambda_authorizer_config` variable must also be provided."
  condition     = !(contains(var.authentication_types, "AWS_LAMBDA") && var.lambda_authorizer_config == null)
}

module "assert_no_duplicate_authorizers" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~> 0.2.4"
  error_message = "The `authentication_types` variable may not include any duplicate values."
  condition     = length(distinct(var.authentication_types)) == length(var.authentication_types)
}

module "assert_valid_authorizers" {
  source        = "Invicton-Labs/assertion/null"
  version       = "~> 0.2.4"
  error_message = "The `authentication_types` variable may only include \"API_KEY\", \"AWS_IAM\", \"AMAZON_COGNITO_USER_POOLS\", \"OPENID_CONNECT\", and \"AWS_LAMBDA\"."
  condition     = length(setsubtract(var.authentication_types, ["API_KEY", "AWS_IAM", "AMAZON_COGNITO_USER_POOLS", "OPENID_CONNECT", "AWS_LAMBDA"])) == 0
}
