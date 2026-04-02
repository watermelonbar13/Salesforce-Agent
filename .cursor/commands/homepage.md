# 개인화된 홈화면

영업대표별로 개인화된 홈화면을 구성한다.
담당 Account 목록, To-Do 목록, AI 챗봇을 하나의 화면에 통합 제공한다.

## 수행할 일

### 전체 레이아웃
```
┌─────────────────────────────────────────────────────┐
│  🔍 [Sales Cloud에 무엇이든 물어보세요...]           │  ← 챗봇 (1-3)
└─────────────────────────────────────────────────────┘

┌─────────────────────────┬───────────────────────────┐
│  📋 내 담당 Account     │  ✅ To-Do 목록             │
│  (1-1)                  │  (1-2)                    │
│  - SK텔레콤        >    │  □ SK텔레콤 미팅 준비      │
│  - 삼성전자        >    │  □ 제안서 발송             │
│  - LG유플러스      >    │  □ 계약서 검토             │
│                         │                           │
└───────────┬─────────────┴───────────────────────────┘
            │ Account 클릭 시 오른쪽 패널 확장
            ▼
┌───────────────────────────────────────────────────┐
│  📰 SK텔레콤 최신 기사                              │
│  1. [기사 제목] → 링크 클릭 시 원문 이동            │
│  2. [기사 제목] → 링크                              │
│  ...                                               │
│                                                    │
│  💡 IT Pain Point / 주요 관심사                     │
│  AI 분석 요약 내용...                               │
└───────────────────────────────────────────────────┘
```

---

## (1-1) 담당 Account 목록 + 우측 패널

### 수행할 일
1. 현재 로그인한 영업대표의 담당 Account 목록 조회 (SF SOQL)
2. Account 카드 형태로 리스트 표시 (이름, 업종, 최근 활동일)
3. Account 클릭 시 오른쪽 패널 슬라이드 확장
4. 패널에 표시할 내용:
   - DuckDuckGo로 기업명 뉴스 검색 → 최근 기사 5개 + 링크
   - Claude API로 IT Pain Point / 주요 관심사 AI 분석 요약
5. 기사 링크 클릭 시 새 탭으로 원문 이동 (`target="_blank"`)

### LWC 구조
```
homePage/
├── homePage.html          ← 전체 레이아웃
├── homePage.js
├── homePage.css
└── homePage.js-meta.xml

accountPanel/              ← 우측 확장 패널 (자식 컴포넌트)
├── accountPanel.html
├── accountPanel.js
└── accountPanel.js-meta.xml
```

### 핵심 LWC 패턴
```javascript
// 부모: Account 클릭 시 자식 패널에 accountId 전달
handleAccountClick(event) {
    this.selectedAccountId = event.currentTarget.dataset.id;
    this.isPanelOpen = true;
}

// 자식: @api로 accountId 받아서 기사+분석 로드
@api
set accountId(value) {
    this._accountId = value;
    if (value) this.loadPanelData();
}
```

---

## (1-2) To-Do 목록

### 수행할 일
1. 현재 로그인한 영업대표의 미완료 Task 조회 (Status != 'Completed')
2. 우선순위별 정렬 (High → Normal → Low)
3. 체크박스 클릭 시 해당 Task Completed 처리 → SF 즉시 업데이트
4. 기한 초과된 Task는 빨간색으로 강조 표시
5. Task 클릭 시 해당 SF 레코드로 이동 링크 제공

### SOQL
```apex
List<Task> todos = [
    SELECT Id, Subject, Priority, ActivityDate, Status,
           WhatId, What.Name, WhoId, Who.Name
    FROM Task
    WHERE OwnerId = :UserInfo.getUserId()
    AND Status != 'Completed'
    ORDER BY Priority DESC, ActivityDate ASC NULLS LAST
    LIMIT 20
];
```

### SF 레코드 링크 패턴
```javascript
// Task 레코드로 이동
navigateToRecord(taskId) {
    this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
            recordId: taskId,
            actionName: 'view'
        }
    });
}
```

---

## (1-3) AI 챗봇

### 수행할 일
1. 화면 상단 검색창에 자연어 질문 입력
2. Claude API가 질문 분석 → 어떤 Object를 조회할지 판단
3. Apex에서 동적 SOQL 생성 후 SF 데이터 조회
4. 결과를 텍스트로 나열
5. 각 레코드에 SF 이동 링크 제공

### 검색 가능 Object
- Account, Opportunity, Contact, Task/Activity, 전체 통합 검색

### 챗봇 응답 형식
```
질문: "이번 달 마감 예정인 Opportunity 알려줘"

답변:
이번 달 마감 예정인 Opportunity는 총 3건입니다.

1. [SK텔레콤 클라우드 전환 프로젝트] → SF 레코드 링크
   - 금액: 5억원 / 단계: Proposal / 마감: 2025-04-15

2. [삼성전자 ERP 구축] → SF 레코드 링크
   - 금액: 3억원 / 단계: Negotiation / 마감: 2025-04-28
```

### 레코드 링크 생성 패턴 (Apex)
```apex
// 각 레코드에 SF URL 추가
String baseUrl = URL.getOrgDomainUrl().toExternalForm();
result.put('recordUrl', baseUrl + '/lightning/r/Opportunity/' + opp.Id + '/view');
```

### Claude API 프롬프트 패턴 (챗봇용)
```apex
public static String chatWithSalesData(String question, String salesData) {
    String prompt = '다음 Salesforce 데이터를 바탕으로 질문에 한국어로 답변해주세요.\n\n'
        + '질문: ' + question + '\n\n'
        + 'SF 데이터: ' + salesData + '\n\n'
        + '각 레코드는 번호 목록으로 나열하고, 핵심 정보만 간결하게 표시해주세요.';
    return callClaude(prompt);
}
```

---

## 생성할 파일
```
force-app/main/default/
├── lwc/
│   ├── homePage/
│   │   ├── homePage.html
│   │   ├── homePage.js
│   │   ├── homePage.css
│   │   └── homePage.js-meta.xml
│   ├── accountPanel/
│   │   ├── accountPanel.html
│   │   ├── accountPanel.js
│   │   ├── accountPanel.css
│   │   └── accountPanel.js-meta.xml
│   └── salesChatbot/
│       ├── salesChatbot.html
│       ├── salesChatbot.js
│       ├── salesChatbot.css
│       └── salesChatbot.js-meta.xml
└── classes/
    ├── HomePageService.cls          ← Account 목록, To-Do 조회
    ├── HomePageService.cls-meta.xml
    ├── ChatbotService.cls           ← 챗봇 SOQL + AI 분석
    └── ChatbotService.cls-meta.xml
```

## 참고 기능
- Salesforce 조회/저장: @.cursor/skills/salesforce/SKILL.md
- 뉴스 검색: @.cursor/skills/web-search/SKILL.md
- AI 분석: @.cursor/skills/llm-analysis/SKILL.md