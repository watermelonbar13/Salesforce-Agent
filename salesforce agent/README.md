# SF Sales Agent

Salesforce 기반 영업 AI 어시스턴트 프로젝트.  
영업대표의 일상 업무(시장조사, 미팅 기록, 사업기회 발굴)를 AI로 자동화한다.

---

## 기능 목록

| 기능 | 커맨드 | 설명 |
|------|--------|------|
| 개인화 홈화면 | `/build-homepage` | 담당 Account 목록, To-Do, AI 챗봇 통합 화면 |
| 시장조사 보고서 | `/build-market-research` | 뉴스·나라장터·DART 수집 후 AI 종합 분석 |
| 사업기회 발굴 | `/build-opportunity` | SF 이력 + 발주공고 기반 신규 기회 추천 |
| 미팅/통화 정리 | `/build-sales-comm` | 음성 녹음 → AI 요약 → SF Task 자동 등록 |

---

## 기술 스택

- **플랫폼**: Salesforce (LWC + Apex)
- **AI**: Claude API (`claude-sonnet-4-20250514`)
- **외부 API**: DuckDuckGo(뉴스), 나라장터 G2B, DART
- **개발 도구**: Cursor IDE + Salesforce DX MCP

---

## 프로젝트 구조

```
my-sf-agent-project/
├── .cursor/                        # Cursor AI 설정
│   ├── rules/                      # 항상 적용되는 코딩 규칙
│   │   ├── apex-rules.mdc          # Apex 네이밍/SOQL/에러처리 규칙
│   │   ├── api-rules.mdc           # 외부 API Callout 규칙
│   │   └── lwc-rules.mdc           # LWC 개발 규칙
│   ├── skills/                     # 요청에 따라 동적으로 로드되는 패턴
│   │   ├── salesforce/SKILL.md     # SF SOQL/DML 패턴
│   │   ├── llm-analysis/SKILL.md   # Claude API 호출 패턴
│   │   ├── web-search/SKILL.md     # DuckDuckGo 뉴스 검색 패턴
│   │   ├── public-data/SKILL.md    # 나라장터/DART 조회 패턴
│   │   └── salesforce-dx/SKILL.md  # DX MCP 개발 워크플로우
│   └── commands/                   # 슬래시 커맨드 지시서
│       ├── build-homepage.md
│       ├── build-market-research.md
│       ├── build-opportunity.md
│       └── build-sales-comm.md
│
└── force-app/main/default/         # SF 소스코드 (AI가 생성)
    ├── lwc/
    │   ├── homePage/
    │   ├── accountPanel/
    │   ├── salesChatbot/
    │   ├── marketResearchReport/
    │   ├── opportunityGenerator/
    │   └── salesCommAssistant/
    └── classes/
        ├── LLMService.cls              # Claude API 중앙 호출 관리
        ├── HomePageService.cls
        ├── ChatbotService.cls
        ├── MarketResearchService.cls
        ├── OpportunityGeneratorService.cls
        └── SalesCommService.cls
```

---

## 시작하기

### 1. 사전 준비

**Salesforce org 설정**

```
# Custom Settings 생성
Setup → Custom Settings → AI_Agent_Settings__c
필드: LLM_API_Key__c / G2B_API_Key__c / DART_API_Key__c

# Named Credentials 등록
Claude_API     → https://api.anthropic.com
DuckDuckGo_API → https://api.duckduckgo.com
G2B_API        → https://apis.data.go.kr
DART_API       → https://opendart.fss.or.kr

# Remote Site Settings 등록 (위 4개 URL 동일하게)
Setup → Security → Remote Site Settings
```

**Cursor MCP 설정**

```json
// Cursor Settings → MCP → Add Server
{
  "mcpServers": {
    "salesforce-dx": {
      "command": "npx",
      "args": ["@salesforce/mcp", "--orgs", "ax", "--toolsets", "data,metadata,orgs"]
    }
  }
}
```

### 2. 기능 생성

Cursor 채팅창에서 슬래시 커맨드를 입력하면 AI가 자동으로 파일을 생성하고 Sandbox에 배포한다.

```
/build-homepage          # 홈화면 생성
/build-market-research   # 시장조사 보고서 생성
/build-opportunity       # 사업기회 발굴 생성
/build-sales-comm        # 미팅/통화 정리 생성
```

---

## .cursor 폴더 구조 설명

Cursor IDE는 `.cursor/` 폴더 아래 세 가지 파일 유형으로 AI 동작을 제어한다.

### Rules — 항상 적용되는 규칙

모든 요청에 자동으로 포함되는 정적 컨텍스트.  
"절대 하지 마라 / 반드시 해라"를 정의하며 `alwaysApply: true`로 설정한다.

```
apex-rules.mdc  → SOQL in loop 금지, with sharing 필수, 테스트 커버리지 75% 등
api-rules.mdc   → Named Credential 필수, URL 하드코딩 금지, 에러코드별 처리 등
lwc-rules.mdc   → @track/@api/@wire 사용법, SLDS 클래스 강제, NavigationMixin 등
```

### Skills — 요청과 관련 있을 때만 로드

각 `SKILL.md` 상단의 `description`에 적힌 키워드가 요청에 포함될 때만 동적으로 로드된다.  
토큰을 아끼면서도 필요한 패턴을 정확히 제공한다.

```
salesforce/     → "Account 조회", "Task 생성", "SOQL" 키워드 시 로드
llm-analysis/   → "AI 분석", "요약", "이메일 초안" 키워드 시 로드
web-search/     → "뉴스 검색", "기사" 키워드 시 로드
public-data/    → "나라장터", "발주공고", "DART" 키워드 시 로드
salesforce-dx/  → "배포", "Sandbox", "org 조회" 키워드 시 로드
```

### Commands — 멀티스텝 작업 지시서

`/커맨드명`으로 호출하면 AI가 지시서를 읽고 순서대로 여러 파일을 자동 생성한다.  
각 Command는 관련 Skills를 `@` 참조로 명시해서 필요한 패턴을 가져오게 한다.

---

## 주의사항

- Sandbox에서만 개발/테스트 (Production org 직접 배포 금지)
- API 키는 코드에 절대 하드코딩하지 않고 Custom Settings에 저장
- AI가 생성한 코드는 반드시 검토 후 배포
- Callout과 DML은 같은 트랜잭션에서 사용 불가 (SF 플랫폼 제약)
