# /build-homepage

영업대표별 개인화된 홈화면을 생성한다.
담당 Account 목록, To-Do 목록, AI 챗봇을 하나의 화면에 통합 제공한다.

## 실행 순서

1. `@.cursor/skills/salesforce/SKILL.md` 참고하여 `HomePageService.cls` 생성
   - 담당 Account 목록 조회 메서드
   - 미완료 Task 목록 조회 메서드
   - Task 완료 처리 메서드
2. `@.cursor/skills/llm-analysis/SKILL.md` 참고하여 `ChatbotService.cls` 생성
   - 자연어 질문 → 동적 SOQL 생성 메서드
   - SF 데이터 기반 챗봇 응답 메서드
3. `@.cursor/skills/web-search/SKILL.md` 참고하여 뉴스 검색 로직을 `HomePageService.cls`에 추가
4. 아래 LWC 구조대로 컴포넌트 파일 생성
5. 생성 완료 후 `@.cursor/skills/salesforce-dx/SKILL.md` 참고하여 Sandbox 배포

## 전체 레이아웃
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
└───────────┬─────────────┴───────────────────────────┘
            │ Account 클릭 시 오른쪽 패널 확장
            ▼
┌───────────────────────────────────────────────────┐
│  📰 SK텔레콤 최신 기사                              │
│  1. [기사 제목] → 링크 클릭 시 원문 이동            │
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
5. 기사 링크 클릭 시 새 탭으로 원문 이동

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
5. Task 클릭 시 해당 SF 레코드로 이동

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

---

## (1-3) AI 챗봇

### 수행할 일
1. 화면 상단 검색창에 자연어 질문 입력
2. Claude API가 질문 분석 → 어떤 Object를 조회할지 판단
3. Apex에서 동적 SOQL 생성 후 SF 데이터 조회
4. 결과를 텍스트로 나열 + 각 레코드에 SF 이동 링크 제공

### 검색 가능 Object
- Account, Opportunity, Contact, Task/Activity

### 챗봇 응답 형식
```
질문: "이번 달 마감 예정인 Opportunity 알려줘"
답변:
이번 달 마감 예정인 Opportunity는 총 3건입니다.
1. [SK텔레콤 클라우드 전환] → SF 링크 / 금액: 5억 / 단계: Proposal / 마감: 2025-04-15
2. [삼성전자 ERP 구축] → SF 링크 / 금액: 3억 / 단계: Negotiation / 마감: 2025-04-28
```

### 레코드 링크 생성 패턴 (Apex)
```apex
String baseUrl = URL.getOrgDomainUrl().toExternalForm();
result.put('recordUrl', baseUrl + '/lightning/r/Opportunity/' + opp.Id + '/view');
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
    ├── HomePageService.cls
    ├── HomePageService.cls-meta.xml
    ├── ChatbotService.cls
    └── ChatbotService.cls-meta.xml
```
