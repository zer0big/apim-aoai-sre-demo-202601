# variables.tf

# Azure 구독 ID (환경 변수 ARM_SUBSCRIPTION_ID 사용 권장)
variable "subscription_id" {
  description = "Azure 구독 ID. 환경 변수 ARM_SUBSCRIPTION_ID로 설정하거나 terraform.tfvars에서 지정"
  type        = string
  default     = null  # 기본값은 null로 설정하여 Azure CLI 기본 구독 사용
  sensitive   = true  # 민감한 정보로 표시
}

variable "resource_group_name" {
  description = "리소스 그룹의 이름"
  type        = string
  default     = "rg-apim-aoai-sre-agent-demo"
}

variable "location" {
  description = "리소스가 배포될 Azure 지역"
  type        = string
  default     = "eastus"
}

variable "apim_name" {
  description = "API Management 인스턴스의 이름"
  type        = string
  default     = "apim-sre-agent-demo"
}

variable "apim_publisher_name" {
  description = "APIM 게시자 이름"
  type        = string
  default     = "ZEROBIG"
}

variable "apim_publisher_email" {
  description = "APIM 게시자 이메일"
  type        = string
  default     = "azure-mvp@zerobig.kr"
}

variable "apim_sku_name" {
  description = "APIM의 SKU. (예: Developer_1, Basic_1, Standard_1, Premium_1)"
  type        = string
  default     = "Developer_1"
}

variable "openai_services" {
  description = "A map of Azure OpenAI service configurations."
  type = map(object({
    location        = string
    sku_name        = string
    deployment_name = string
    model_name      = string
    model_version   = string
    capacity        = number
  }))
  default = {
    service01 = { 
      location        = "eastus"
      sku_name        = "S0"
      deployment_name = "gpt-4o"
      model_name      = "gpt-4o"
      model_version   = "2024-11-20"
      capacity        = 20
},
    service02 = {
      location        = "westus"
      sku_name        = "S0"
      deployment_name = "gpt-4o"
      model_name      = "gpt-4o"
      model_version   = "2024-11-20"
      capacity        = 20
    }
  }
}
