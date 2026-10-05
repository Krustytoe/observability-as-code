# Publishes the rendered dashboards (build/dashboards/*.json) to Grafana / Grafana Cloud.
# Run `make dashboards` first. Auth is a Grafana service-account token with Editor on the folder:
#   export TF_VAR_grafana_auth=glsa_...   (never commit it)

terraform {
  required_version = ">= 1.7"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 3.0"
    }
  }
}

variable "grafana_url" {
  description = "Grafana base URL, e.g. https://my-stack.grafana.net"
  type        = string
}

variable "grafana_auth" {
  description = "Service-account token."
  type        = string
  sensitive   = true
}

variable "folder_title" {
  description = "Folder that holds every dashboard from this repo."
  type        = string
  default     = "Observability as Code"
}

variable "dashboards_dir" {
  description = "Directory of rendered dashboard JSON."
  type        = string
  default     = "../../build/dashboards"
}

provider "grafana" {
  url  = var.grafana_url
  auth = var.grafana_auth
}

locals {
  dashboards = fileset(var.dashboards_dir, "*.json")
}

resource "grafana_folder" "this" {
  uid   = "observability-as-code"
  title = var.folder_title
}

resource "grafana_dashboard" "this" {
  for_each = local.dashboards

  folder      = grafana_folder.this.uid
  config_json = file("${var.dashboards_dir}/${each.value}")
  overwrite   = true
  message     = "Deployed by Terraform from observability-as-code"
}

output "dashboard_urls" {
  value = { for k, d in grafana_dashboard.this : k => "${var.grafana_url}${d.url}" }
}
