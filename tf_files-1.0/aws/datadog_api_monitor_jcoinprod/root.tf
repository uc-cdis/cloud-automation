terraform {
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

provider "datadog" {
    api_key = var.api_key
    app_key = var.app_key
    api_url = var.api_url
}

resource "datadog_synthetics_test" "api_tester" {
  for_each = {for test in var.test_definitions: test.endpoint => test}

  type = "api"
  subtype = "http"

  request_definition {
    method = "GET"
    url = "${var.commons_url}${each.value.endpoint}"
  }

  assertion {
    type = "statusCode"
    operator = "is"
    target = each.value.target_status_code
  }

  assertion {
    type = "responseTime"
    operator = "lessThan"
    target = each.value.target_response_time
  }

  options_list {
    tick_every = var.test_run_frequency_secs
    min_failure_duration = 300
  }

  locations = var.locations

  name = "${each.value.name}${var.commons_name}"
  message = "${each.value.message}${var.commons_name} ${var.project_slack_channel}"
  
  tags = var.tags

  status = var.status

}