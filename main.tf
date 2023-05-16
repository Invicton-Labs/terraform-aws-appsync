data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

// Create a role that allows the AppSync API to do logging
resource "aws_iam_role" "appsync_logging" {
  name_prefix        = "AppSyncLogging-"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

// Create a policy for linking to the AppSync logging role
resource "aws_iam_role_policy" "appsync_logging" {
  name_prefix = "AppSyncLogging-"
  role        = aws_iam_role.appsync_logging.id
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:/aws/appsync/apis/*"
            ]
        }
    ]
}
EOF
}

// Create the GraphQL API
resource "aws_appsync_graphql_api" "this" {
  authentication_type = var.authentication_types[0]
  name                = var.name
  schema              = var.schema
  xray_enabled        = var.xray_enabled
  tags                = var.tags

  dynamic "log_config" {
    for_each = var.logging_enabled ? [1] : []
    content {
      cloudwatch_logs_role_arn = aws_iam_role.appsync_logging.arn
      exclude_verbose_content  = var.logging_exclude_verbose_content
      field_log_level          = var.logging_level
    }
  }

  // Only put the openid_connect_config block in the main block if OpenID is the first auth mechanism
  dynamic "openid_connect_config" {
    for_each = var.authentication_types[0] == "OPENID_CONNECT" ? [1] : []
    content {
      issuer    = var.openid_connect_config.issuer
      auth_ttl  = var.openid_connect_config.auth_ttl
      client_id = var.openid_connect_config.client_id
      iat_ttl   = var.openid_connect_config.iat_ttl
    }
  }

  // Only put the lambda_authorizer_config block in the main block if OpenID is the first auth mechanism
  dynamic "lambda_authorizer_config" {
    for_each = var.authentication_types[0] == "AWS_LAMBDA" ? [1] : []
    content {
      authorizer_uri                   = var.lambda_authorizer_config.issauthorizer_uriuer
      authorizer_result_ttl_in_seconds = var.lambda_authorizer_config.authorizer_result_ttl_in_seconds
      identity_validation_expression   = var.lambda_authorizer_config.identity_validation_expression
    }
  }

  // Only put the user_pool_config block in the main block if Cognito is the first auth mechanism
  dynamic "user_pool_config" {
    for_each = var.authentication_types[0] == "AMAZON_COGNITO_USER_POOLS" ? [1] : []
    content {
      default_action      = var.user_pool_config.default_action
      user_pool_id        = var.user_pool_config.user_pool_id
      app_id_client_regex = var.user_pool_config.app_id_client_regex
      aws_region          = var.user_pool_config.aws_region
    }
  }

  // Add all additional auth mechanisms
  dynamic "additional_authentication_provider" {
    // Loop for all except the first one
    for_each = length(var.authentication_types) > 1 ? slice(var.authentication_types, 1, length(var.authentication_types)) : []
    content {
      authentication_type = additional_authentication_provider.value
      // Only add the 'openid_connect_config' block if this is an OpenID mechanism
      dynamic "openid_connect_config" {
        for_each = additional_authentication_provider.value == "OPENID_CONNECT" ? [1] : []
        content {
          issuer    = var.openid_connect_config.issuer
          auth_ttl  = var.openid_connect_config.auth_ttl
          client_id = var.openid_connect_config.client_id
          iat_ttl   = var.openid_connect_config.iat_ttl
        }
      }
      dynamic "lambda_authorizer_config" {
        // Only add the 'lambda_authorizer_config' block if this is a Lambda mechanism
        for_each = additional_authentication_provider.value == "AWS_LAMBDA" ? [1] : []
        content {
          authorizer_uri                   = var.lambda_authorizer_config.issauthorizer_uriuer
          authorizer_result_ttl_in_seconds = var.lambda_authorizer_config.authorizer_result_ttl_in_seconds
          identity_validation_expression   = var.lambda_authorizer_config.identity_validation_expression
        }
      }
      dynamic "user_pool_config" {
        // Only add the 'user_pool_config' block if this is a Cognito mechanism
        for_each = additional_authentication_provider.value == "AMAZON_COGNITO_USER_POOLS" ? [1] : []
        content {
          user_pool_id        = var.user_pool_config.user_pool_id
          app_id_client_regex = var.user_pool_config.app_id_client_regex
          aws_region          = var.user_pool_config.aws_region
        }
      }
    }
  }
}

// Create the custom domain, if desired
resource "aws_appsync_domain_name" "this" {
  count           = var.create_custom_domain == true ? 1 : 0
  description     = var.custom_domain_description
  domain_name     = var.custom_domain
  certificate_arn = var.custom_domain_acm_certificate_arn
}

// Associate the custom domain, if one was created
resource "aws_appsync_domain_name_api_association" "this" {
  count       = var.create_custom_domain == true ? 1 : 0
  api_id      = aws_appsync_graphql_api.this.id
  domain_name = aws_appsync_domain_name.this[0].domain_name
}

// Get the log group that was automatically created by the GraphQL API
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.this.id}"
  retention_in_days = var.log_retention_days
}

module "appsync_resolvers" {
  source             = "./modules/resolvers"
  api_id             = aws_appsync_graphql_api.this.id
  datasources        = var.datasources
  unit_resolvers     = var.unit_resolvers
  functions          = var.functions
  pipeline_resolvers = var.pipeline_resolvers
}
