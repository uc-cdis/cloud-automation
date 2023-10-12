terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

locals {
  api_key = var.secrets_manager_enabled ? jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["api-key"] : var.api_key
  app_key = var.secrets_manager_enabled ? jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["application-key"] : var.app_key
  api_url = var.secrets_manager_enabled ? jsondecode(data.aws_secretsmanager_secret_version.secrets.secret_string)["url"] : var.api_url
}

provider "datadog" {
    api_key = local.api_key
    app_key = local.app_key
    api_url = local.api_url
}

resource "datadog_synthetics_test" "api_tests" {
  name      = "${var.commons_name} tests"
  message   = "@slack-gpe-alarms Service failure on ${var.commons_name} ${var.project_slack_channel}"
  tags      = var.tags
  type      = "api"
  subtype   = "multi"
  status    = var.status
  locations = var.locations

  dynamic "api_step" {
    for_each = var.test_definitions
    content {
    name     = "${api_step.value.name}${var.commons_name}"
    subtype  = "http"
    allow_failure   = true
    is_critical     = true

    assertion {
      type = "statusCode"
      operator = "is"
      target = api_step.value.target_status_code
    }

    assertion {
      type = "responseTime"
      operator = "lessThan"
      target = api_step.value.target_response_time
    }

    request_definition {
      method = "GET"
      url    = "${var.commons_url}${api_step.value.endpoint}"
    }

    retry {
      count    = 3
      interval = 3000
    }
    }
  }

  options_list {
    tick_every = 300
    min_failure_duration = 300
  }
}
