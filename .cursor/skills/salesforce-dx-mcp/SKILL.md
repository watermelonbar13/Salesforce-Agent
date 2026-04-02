# Salesforce DX MCP Server 활용

## 개요
Cursor에서 Salesforce DX MCP Server를 활용하여
코드 작성, 배포, org 관리를 자연어로 수행한다.
이 skill은 **개발 단계**에서만 사용하며, 실제 앱 로직은 Apex로 구현한다.

## 연결 설정
```json
// Cursor Settings → MCP → Add Server
{
  "mcpServers": {
    "salesforce-dx": {
      "command": "npx",
      "args": [
        "@salesforce/mcp",
        "--orgs", "ax",
        "--toolsets", "data,metadata,orgs"
      ]
    }
  }
}
```

## 사용 가능한 Toolset
| Toolset | 기능 |
|---------|------|
| `orgs` | org 정보 조회, 사용자 확인 |
| `metadata` | Apex 클래스, LWC 생성/배포 |
| `data` | SOQL 쿼리, 레코드 조회 |

---

## 개발 시 활용 패턴

### 1. org 구조 파악 (코드 작성 전)
```
Cursor에게: "Account 오브젝트의 필드 목록 알려줘"
Cursor에게: "내 Sandbox org에 어떤 Custom Object 있어?"
Cursor에게: "Opportunity 오브젝트의 Picklist 값 알려줘"
```

### 2. 코드 생성 및 배포
```
Cursor에게: "MarketResearchService Apex 클래스 만들고 Sandbox에 배포해줘"
Cursor에게: "homePage LWC 컴포넌트 생성해줘"
Cursor에게: "변경된 파일들 Sandbox에 배포해줘"
```

### 3. 데이터 확인 (개발 중 테스트)
```
Cursor에게: "내 담당 Account 5개 조회해줘"
Cursor에게: "Task 중 완료 안된 것들 보여줘"
Cursor에게: "이 SOQL이 제대로 동작하는지 확인해줘:
             SELECT Id, Name FROM Account WHERE OwnerId = '내Id'"
```

### 4. 메타데이터 관리
```
Cursor에게: "AI_Agent_Settings__c Custom Settings 만들어줘
             필드: G2B_API_Key__c, DART_API_Key__c, LLM_API_Key__c"
Cursor에게: "Named Credential Claude_API 설정 확인해줘"
Cursor에게: "현재 배포된 Apex 클래스 목록 보여줘"
```

---

## 개발 워크플로우

```
1. Cursor에서 DX MCP로 org 구조 파악
        ↓
2. Cursor Rules + Skills 참고하여 코드 작성
        ↓
3. DX MCP로 Sandbox에 즉시 배포
        ↓
4. DX MCP로 SOQL 테스트
        ↓
5. LWC 화면에서 동작 확인
        ↓
6. 반복
```

## 주의사항
- DX MCP Server는 **개발/테스트 전용** (Sandbox org만 사용)
- 실제 앱의 데이터 조회/저장은 반드시 **Apex 코드**로 구현
- `--orgs ax` : Sandbox alias (변경 시 수정 필요)
- Production org 접근 절대 금지