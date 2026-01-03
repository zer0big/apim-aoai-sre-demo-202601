# Azure API Management + Azure OpenAI Integration Demo

Terraform 기반 Azure API Management와 Azure OpenAI 통합 데모 프로젝트 (2026년 1월)

## 📋 개요

이 프로젝트는 Azure API Management(APIM)를 통해 Azure OpenAI 서비스에 안전하게 접근하는 Infrastructure as Code(IaC) 솔루션입니다.

**핵심 기능:**
- ✅ **Managed Identity 인증**: API 키 없이 안전한 Azure OpenAI 접근
- ✅ **로드 밸런싱**: 2개 리전(East US, West US)의 Azure OpenAI 인스턴스
- ✅ **Application Insights 통합**: 전체 API 트래픽 모니터링 및 트레이싱
- ✅ **Log Analytics 연동**: 진단 로그 및 메트릭 수집

## 🏗️ 아키텍처

```
Client Request
      ↓
[API Management]
      ↓ (Managed Identity Auth)
      ├─→ [Azure OpenAI - East US]
      └─→ [Azure OpenAI - West US]
      ↓
[Application Insights / Log Analytics]
```

## 🚀 빠른 시작

### 사전 요구사항

- Azure 구독
- Terraform >= 1.0
- Azure CLI
- PowerShell 7+

### 1️⃣ 배포

#### PowerShell로 배포

```powershell
# 1. 리포지토리 클론
git clone https://github.com/zer0big/apim-aoai-sre-demo-202601.git
cd apim-aoai-sre-demo-202601

# 2. terraform.tfvars 파일 생성
@'
subscription_id = "YOUR_SUBSCRIPTION_ID_HERE"
'@ | Set-Content -Path .\terraform.tfvars

# 3. Terraform 초기화 및 배포
terraform init
terraform plan
terraform apply -auto-approve
```

### 2️⃣ 테스트

배포 완료 후 자동 테스트 스크립트 실행:

```powershell
# 백엔드 로드 밸런싱 테스트 (5회)
.\Test-APIM-Backend.ps1 -Iterations 5
```

**예상 결과:**
```
🧪 Azure APIM → Azure OpenAI 백엔드 테스트
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/5] Status: ✅ 200 | Backend: zbho-xxx-02-aoai (West US) | Answer: 1+1은 2입니다! 😊
[2/5] Status: ✅ 200 | Backend: zbho-xxx-01-aoai (East US) | Answer: 1+1은 2입니다! 😊
[3/5] Status: ✅ 200 | Backend: zbho-xxx-01-aoai (East US) | Answer: 1+1은 2입니다! 😊
[4/5] Status: ✅ 200 | Backend: zbho-xxx-01-aoai (East US) | Answer: 1+1은 2입니다! :)
[5/5] Status: ✅ 200 | Backend: zbho-xxx-01-aoai (East US) | Answer: 1+1은 2입니다! 😊

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ 테스트 완료!
```

**또는 수동 테스트:**

```powershell
$uri = "https://zbho-xxx-apim.azure-api.net/openai/chat/completions?api-version=2024-12-01-preview"
$body = '{"messages":[{"role":"user","content":"1+1은?"}],"max_tokens":50}'

$r = Invoke-WebRequest -Uri $uri `
    -Method POST `
    -Headers @{"Content-Type"="application/json"} `
    -Body $body `
    -SkipHttpErrorCheck

Write-Host "Status: $($r.StatusCode)"
Write-Host "Backend: $($r.Headers['x-ms-deployment-name'])"
Write-Host "Region: $($r.Headers['x-ms-region'])"

$resp = $r.Content | ConvertFrom-Json
Write-Host "Answer: $($resp.choices[0].message.content)"
```

## 📦 주요 리소스

| 리소스 | 용도 |
|--------|------|
| API Management | API Gateway 및 정책 관리 |
| Azure OpenAI (East US) | GPT-4o 모델 배포 (20 PTU) |
| Azure OpenAI (West US) | GPT-4o 모델 배포 (20 PTU) |
| Application Insights | API 트레이싱 및 성능 모니터링 |
| Log Analytics Workspace | 진단 로그 및 메트릭 저장 |

## 🔐 보안 구성

### Managed Identity 인증

APIM의 System-Assigned Managed Identity를 사용하여 Azure OpenAI에 접근:

```xml
<authentication-managed-identity resource="https://cognitiveservices.azure.com" />
```

**역할 할당:**
- Role: `Cognitive Services OpenAI User`
- Principal: APIM Managed Identity
- Scope: Azure OpenAI 리소스

## 🛠️ 주요 정책

### API Policy (Inbound)

```xml
<policies>
    <inbound>
        <base />
        <!-- Managed Identity 인증 -->
        <authentication-managed-identity resource="https://cognitiveservices.azure.com" />
        
        <!-- Backend 라우팅 -->
        <set-backend-service backend-id="aoai-backend-pool" />
        
        <!-- URI Rewrite -->
        <rewrite-uri template="/openai/deployments/zbho-xxx-gpt-4o/chat/completions?api-version=2024-12-01-preview" />
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
```

## 📊 모니터링

### Application Insights

- **100% 샘플링**: 모든 API 호출 트레이싱
- **Frontend/Backend 로깅**: 요청/응답 헤더 및 바디 기록
- **에러 로깅**: 모든 에러 자동 기록

### Log Analytics

- **진단 설정**: Audit 및 AllLogs 카테고리 활성화
- **메트릭**: AllMetrics 수집
- **보존 기간**: 30일

## 🔧 커스터마이징

### 변수 수정 (`terraform.tfvars`)

```hcl
subscription_id = "YOUR_SUBSCRIPTION_ID"

# 선택적 변수들 (기본값 오버라이드)
location            = "eastus"
apim_sku_name      = "Developer_1"
apim_publisher_name = "Your Company"
apim_publisher_email = "admin@example.com"
```

### Azure OpenAI 모델 변경

`variables.tf`에서 `openai_services` 변수 수정:

```hcl
variable "openai_services" {
  default = {
    service01 = { 
      location        = "eastus"
      deployment_name = "gpt-4o"
      model_name      = "gpt-4o"
      model_version   = "2024-11-20"
      capacity        = 20
    }
    # 추가 서비스...
  }
}
```

## 📝 파일 구조

```
.
├── main.tf              # 메인 리소스 정의
├── variables.tf         # 입력 변수 정의
├── locals.tf            # 로컬 변수 및 명명 규칙
├── outputs.tf           # 출력 값
├── terraform.tfvars     # 변수 값 (사용자 제공)
├── .gitignore          # Git 제외 파일
└── README.md           # 프로젝트 문서
```

## 🧹 정리

리소스 삭제:

```bash
terraform destroy -auto-approve
```

## 📖 참고 문서

- [Azure API Management](https://learn.microsoft.com/azure/api-management/)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-services/openai/)
- [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)

## 📄 라이선스

MIT License

## 👤 작성자

**ZEROBIG**
- Email: azure-mvp@zerobig.kr
- GitHub: [@zer0big](https://github.com/zer0big)

## 🙏 감사의 말

이 프로젝트는 Azure API Management와 Azure OpenAI의 통합 패턴을 학습하고 공유하기 위해 만들어졌습니다.
