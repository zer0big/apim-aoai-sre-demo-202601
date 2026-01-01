# main.tf

# Terraform 및 Azure Provider 설정
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id  # 환경 변수 ARM_SUBSCRIPTION_ID 또는 terraform.tfvars에서 지정
}

provider "random" {
  # random provider는 특별한 설정 불필요
}

# 리소스 그룹 생성
resource "azurerm_resource_group" "rg" {
  name     = local.final_resource_group_name
  location = var.location
}

# API Management 인스턴스 생성
resource "azurerm_api_management" "apim" {
  name                = local.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name

  identity {
    type = "SystemAssigned"
  }
}

# Log Analytics Workspace 생성
resource "azurerm_log_analytics_workspace" "law" {
  name                = local.law_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Application Insights 생성 
resource "azurerm_application_insights" "appins" {
  name                = local.appins_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
}


# ==============================================================================
# APIM Diagnostic Setting 추가 (Log Analytics Workspace로 전송)
# ==============================================================================
resource "azurerm_monitor_diagnostic_setting" "apim_diag_settings" {
  name                        = local.apim_diag_settings_name
  target_resource_id          = azurerm_api_management.apim.id
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.law.id

 # Resource specific 테이블 전송
  log_analytics_destination_type = "Dedicated"

  # 로그 카테고리 그룹 (Category groups)
  enabled_log {
    category_group = "audit"
  }

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ==============================================================================
# APIM과 Application Insights 연동 (API 호출 트레이스 및 데이터 로깅)
# ==============================================================================
# APIM Logger 생성 (Application Insights 연결)
resource "azurerm_api_management_logger" "apim_ai_logger" {
  name                = local.apim_ai_logger_name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  resource_id         = azurerm_application_insights.appins.id

  application_insights {
    instrumentation_key = azurerm_application_insights.appins.instrumentation_key
  }
}

# APIM 진단 설정 (모든 API 트래픽 로깅)
resource "azurerm_api_management_diagnostic" "apim_diagnostic" {
  identifier          = "applicationinsights"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  api_management_logger_id = azurerm_api_management_logger.apim_ai_logger.id

  sampling_percentage = 100
  always_log_errors   = true
  log_client_ip       = true

  frontend_request {
    headers_to_log    = ["User-Agent", "Host", "Content-Type"]
  }
  frontend_response {
    headers_to_log    = ["Content-Type"]
  }
  backend_request {
    headers_to_log    = ["User-Agent", "Host", "Content-Type"]
  }
  backend_response {
    headers_to_log    = ["Content-Type"]
  }
}


# 2개의 Azure OpenAI 서비스 생성 (for_each 사용)
resource "azurerm_cognitive_account" "aoai" {
  for_each = var.openai_services

  name                = local.aoai_final_names[each.key]
  location            = each.value.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "OpenAI"
  sku_name            = each.value.sku_name

  custom_subdomain_name = local.aoai_subdomain_names[each.key]
  public_network_access_enabled = true
}

# 2개의 gpt-4o 모델 배포 (for_each 사용)
resource "azurerm_cognitive_deployment" "aoai_deployment" {
  for_each = var.openai_services

  name                = local.aoai_deployment_final_names[each.key]
  cognitive_account_id = azurerm_cognitive_account.aoai[each.key].id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name     = "Standard"
    capacity = each.value.capacity
  }
}
# ==============================================================================
# APIM API 설정: Azure OpenAI 채팅 완성도 API
# ==============================================================================

# Backend Pool 설정 (East US Azure OpenAI)
resource "azurerm_api_management_backend" "aoai_backend_pool" {
  name                = "aoai-backend-pool"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  protocol            = "https"
  url                 = "https://${azurerm_cognitive_account.aoai["service01"].custom_subdomain_name}.openai.azure.com/"

  # 연결 시간 초과 설정
  resource_id         = azurerm_cognitive_account.aoai["service01"].id
}

# API 생성: Azure OpenAI Chat Completions
resource "azurerm_api_management_api" "aoai_api" {
  name                = "aoai-api-lb"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "Azure OpenAI Load Balanced API"
  path                = "openai"
  protocols           = ["https"]
  
  # 구독 필수 여부 (false: 구독 키 없이 접근 가능)
  subscription_required = false
}

# Operation 생성: POST /chat/completions
resource "azurerm_api_management_api_operation" "chat_completions_operation" {
  operation_id        = "chat-completions"
  api_name            = azurerm_api_management_api.aoai_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Chat Completions"
  method              = "POST"
  url_template        = "/chat/completions"
  description         = "Create a completion for the chat message"
}

# API Policy 설정: Managed Identity 인증 + Backend 라우팅 + URI Rewrite
resource "azurerm_api_management_api_policy" "aoai_api_policy" {
  api_name            = azurerm_api_management_api.aoai_api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  xml_content = <<-EOT
<policies>
    <inbound>
        <base />
        <!-- Managed Identity를 사용한 Azure OpenAI 인증 -->
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
        <!-- East US Azure OpenAI 백엔드로 라우팅 -->
        <set-backend-service backend-id="aoai-backend-pool" />
        <!-- URI 경로 재작성: /openai/chat/completions → /openai/deployments/zbho-f9a-gpt-4o/chat/completions -->
        <rewrite-uri template="/openai/deployments/zbho-f9a-gpt-4o/chat/completions?api-version=2024-12-01-preview" />
    </inbound>
    <backend>
        <forward-request buffer-request-body="true" />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
EOT
}

# ==============================================================================
# APIM Managed Identity 권한 설정
# ==============================================================================

# APIM의 Managed Identity에 Azure OpenAI 액세스 권한 부여 (service01: East US)
resource "azurerm_role_assignment" "apim_aoai_access_01" {
  scope              = azurerm_cognitive_account.aoai["service01"].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id       = azurerm_api_management.apim.identity[0].principal_id
}

# APIM의 Managed Identity에 Azure OpenAI 액세스 권한 부여 (service02: West US - 향후 로드 밸런싱)
resource "azurerm_role_assignment" "apim_aoai_access_02" {
  scope              = azurerm_cognitive_account.aoai["service02"].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id       = azurerm_api_management.apim.identity[0].principal_id
}