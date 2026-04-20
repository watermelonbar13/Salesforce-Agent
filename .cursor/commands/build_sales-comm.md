# /build-sales-comm

미팅/통화 내용을 AI로 분석하고 영업활동 결과 및 액션 아이템을 SF Custom Object에 저장하는 기능을 만든다.

## UI 기준
- 화면 구성은 Figma 시안 기준으로 구현: [Figma 시안](https://www.figma.com/make/nePRZ4rEa4VW0TH4jthVMC/%EC%A0%9C%EB%AA%A9-%EC%97%86%EC%9D%8C?t=M2d9iRM6e8jHlejs-1)
- 핵심 섹션:
  - Activity Information
  - Pre-Meeting Preparation
  - Post-Meeting Analysis
  - AI 분석 결과

## 전제 조건
- SalesActivity__c, SalesActionItem__c Custom Object는 수동으로 생성된 상태로 가정
- Setup → Session Settings → Lightning Web Security(LWS) 활성화 필요 (Web Speech API 사용)

## 오브젝트 명명 기준
- 표준 Activity(Task/Event)와 혼동을 피하기 위해 `Task__c` 대신 `SalesActionItem__c` 사용
- 용도: 미팅/통화 분석 결과에서 생성되는 후속 조치(Next Action) 관리 전용

---

## 실행 순서

1. `@.cursor/skills/llm-analysis/SKILL.md` 참고하여 `SalesCommService.cls` 생성
   - AI 영업비서 생성 메서드 (웹서칭 + 이전 활동 참고)
   - 녹음 텍스트 분석 → 영업활동 내용 요약 + Next Action 후보 추출 메서드
   - 이전 영업활동 이력 종합 요약 + 영업전략 조언 메서드
2. `@.cursor/skills/salesforce/SKILL.md` 참고하여 SF 저장 로직 추가
   - SalesActivity__c 저장 메서드
   - SalesActionItem__c 일괄 생성 메서드
   - 이전 영업활동 이력 조회 메서드
3. LWC 컴포넌트 2개 생성

---

## SalesCommService.cls 메서드 목록

### `getAISalesAdvice(contextRecordId, contextObjectApiName, subjectType, relatedAccountId, relatedOpportunityId)`
- `contextObjectApiName` 기준으로 Account / Opportunity / SalesActivity__c / 기타 지원 객체 분기
- 최근 1주일 기준 관련 SalesActivity__c 조회 (relatedAccountId, relatedOpportunityId 우선 사용)
- 외부 웹서칭으로 관련 회사/산업 최신 기사 및 Pain Point 수집
- `subjectType`이 '고객 미팅 진행' 또는 '전화 통화'인 경우:
  - 이전 활동 맥락 + 관련 기사 링크 포함한 미팅/통화 준비 브리핑 생성
- `subjectType`이 '이메일 커뮤니케이션'인 경우:
  - 이전 활동 맥락 + `EmailContent__c` 필드값 기반 메일 초안 생성
- 지원하지 않는 객체 타입은 사용자 메시지와 함께 기본 브리핑 모드로 fallback

### `getAISalesAdvice` 조회 우선순위 규칙
- 1순위: `relatedAccountId` 존재 시 Account 기준 조회
- 2순위: `relatedOpportunityId` 존재 시 Opportunity 기준 조회
- 3순위: `contextObjectApiName` + `contextRecordId` 기반 조회
- 4순위: 연결 정보 부족 시 최근 SalesActivity__c 5건 기반 일반 브리핑
- 모든 분기에서 조회 결과 0건이면 "이전 활동 없음" 메시지와 기본 브리핑 반환

### 컨텍스트별 입력/출력 매트릭스
- 공통 입력:
  - `contextRecordId` (Required)
  - `contextObjectApiName` (Required, 허용값: `Account`, `Opportunity`, `SalesActivity__c`)
  - `subjectType` (Required)
  - `relatedAccountId` (Optional)
  - `relatedOpportunityId` (Optional)
- 컨텍스트별 처리:
  - `Account`:
    - 기본 조회 키: `contextRecordId` 또는 `relatedAccountId`
    - 출력: 미팅/통화 브리핑 또는 이메일 초안
  - `Opportunity`:
    - 기본 조회 키: `contextRecordId` 또는 `relatedOpportunityId`
    - 출력: 딜 단계/리스크 중심 브리핑 또는 이메일 초안
  - `SalesActivity__c`:
    - 기본 조회 키: `contextRecordId` + 연결된 Account/Opportunity
    - 출력: 직전 활동 연계 브리핑 또는 이메일 초안
  - 기타 값:
    - 처리: 기본 브리핑 모드 fallback
    - 출력: 일반 브리핑 + 사용자 안내 메시지
- `subjectType` 분기:
  - `고객 미팅 진행`, `전화 통화` → 브리핑 생성
  - `이메일 커뮤니케이션` → 메일 초안 생성
  - 기타/null → 기본 브리핑 모드

### `analyzeRecording(transcriptText)`
- 녹음 텍스트 분석
- 영업활동 내용 요약 생성 (상급자 보고용으로 상세 작성)
- Next Action 후보 목록 추출 (Subject / Priority: High·Normal·Low / DueDate 포함)
- Next Best Action 후보 목록 생성 (단일 1건 제한 금지)
- `nextBestActions`와 `actionItems` 병합 시 제목 기준 중복 제거 로직 적용 (공백/기호 차이 무시)
- 아래 "AI 응답 스키마 계약" 형식으로 고정 반환

### `getPreMeetingPreparation(activityId)`
- 미팅 전 준비정보 생성
- 포함 항목:
  - 이전 미팅 이력 요약
  - 미완료 Task 알림
  - 추천 대화 주제 및 질문 리스트
- activityId 기준 RelatedAccount__c / RelatedOpportunity__c 컨텍스트 자동 해석

### `getPreviousActivities(accountId, opportunityId)`
- Account 또는 Opportunity 기준 SalesActivity__c 이력 조회
- 두 파라미터 모두 지원 (각각 Optional)

### `getAISalesStrategy(activities)`
- 이전 영업활동 이력 종합 요약
- 단기 / 중기 / 장기 영업전략 조언 생성

### `saveActivityContent(activityId, content)`
- SalesActivity__c 의 `ActivityContent__c` 필드 업데이트

### `saveActionItems(actionItemList, activityId)`
- 선택된 Next Action 항목 `SalesActionItem__c` 일괄 생성
- `SalesActivity__c` Lookup 포함하여 어떤 미팅에서 생성됐는지 추적
- 부분 성공 허용(성공/실패 항목 분리 리턴)

---

## AI 응답 스키마 계약

### `getAISalesAdvice` 반환 JSON (고정)
```json
{
  "mode": "briefing|emailDraft",
  "title": "string",
  "content": "string",
  "recommendedActions": ["string"],
  "referenceLinks": [
    {
      "title": "string",
      "url": "string"
    }
  ],
  "warnings": ["string"],
  "usedContext": {
    "contextObjectApiName": "Account|Opportunity|SalesActivity__c|Other",
    "accountId": "string|null",
    "opportunityId": "string|null"
  }
}
```

### `getAISalesAdvice` 스키마 규칙
- `mode`:
  - `subjectType`이 `이메일 커뮤니케이션`이면 `emailDraft`
  - 그 외는 `briefing`
- `content`는 한국어로 생성
- `referenceLinks`는 최대 5건, URL 유효성 실패 항목은 제외
- `recommendedActions`는 최대 5건
- 파싱 실패 또는 외부 검색 실패 시:
  - `warnings`에 실패 사유 추가
  - 내부 이력 기반 최소 브리핑 콘텐츠라도 반환

### `analyzeRecording` 반환 JSON (고정)
```json
{
  "summary": "string",
  "nextBestActions": ["string"],
  "actionItems": [
    {
      "subject": "string",
      "priority": "High|Normal|Low",
      "dueDate": "YYYY-MM-DD",
      "reason": "string"
    }
  ],
  "warnings": ["string"],
  "confidence": 0.0
}
```

### 스키마 규칙
- `summary`는 한국어, 상급자 보고용 상세 내용으로 생성
- `actionItems` 최대 10건
- `nextBestActions`는 회의 맥락에서 실행 가능한 후보를 다건으로 생성 (최대 10건)
- `dueDate` 누락 시 `null` 허용
- 파싱 실패 시 서버에서 기본값 반환:
  - `summary`: 빈 문자열
  - `actionItems`: 빈 배열
  - `warnings`: `["AI 응답 파싱 실패"]`
  - `confidence`: `0.0`

---

## 저장 트랜잭션 정책
- 1단계: `saveActivityContent`로 `ActivityContent__c` 저장
- 2단계: `saveActionItems`로 `SalesActionItem__c` 일괄 생성
- 2단계 일부 실패 시:
  - 성공 건은 커밋 유지
  - 실패 건은 에러 메시지와 함께 클라이언트에 반환
  - LWC는 "부분 저장 성공" 토스트 및 실패 항목 재시도 UI 제공
- 원칙: 활동 본문 저장 성공을 우선 보장하고 후속 액션은 재시도 가능하게 설계

### `SalesActionItem__c` 권장 필드 스펙
- `Name` (Auto Number 또는 Text): 액션 아이템 식별자
- `Subject__c` (Text 255, Required): 후속 조치 제목
- `Priority__c` (Picklist: High, Normal, Low): 우선순위
- `DueDate__c` (Date): 목표 완료일
- `Status__c` (Picklist: Not Started, In Progress, Completed, Cancelled): 진행 상태
- `Activity__c` (Lookup to SalesActivity__c, Required): 원본 활동 연결
- `OwnerId` (Lookup to User, Required): 담당자
- `Description__c` (Long Text): AI 생성 근거 또는 상세 메모

---

## LWC 1: salesActivityRecorder
**위치**: SalesActivity__c 레코드 페이지에 임베드  
**역할**: SalesActivity__c 레코드 저장 이후 미팅/통화 결과 녹음 및 AI 분석

### 탭1. Activity Information

- 영업활동 상세 내용 입력 (목적/참석자/니즈/리스크/결정사항 등)
- 상급자 보고용 참고 메모 입력

### 탭2. Pre-Meeting Preparation

- 미팅 전에 필요한 준비 정보 제공:
  - 이전 미팅 이력 요약
  - 미완료 task 알림
  - 미팅 대화 주제/질문 리스트 추천

### 탭3. Post-Meeting Analysis

- 마이크 아이콘 클릭 시 녹음 시작/중지
- STT 품질 개선 요구 반영:
  - final result만 누적하여 중복 텍스트 감소
  - overlap merge로 반복 단어 제거
  - 인식 중단 시 자동 재시작(onend)
  - interim 텍스트는 별도 표시
- "분석 시작" 클릭 시 AI 분석 결과 탭으로 자동 이동
- "취소" 클릭 시 분석 취소 처리 및 Post-Meeting 탭 유지

### 탭4. AI 분석 결과

- 분석 시작 후 자동 진입
- 분석 결과 표시:
  - **영업활동 내용**: 상급자 보고 가능한 상세 요약
  - **Next Best Action**: 단일 최우선 실행안
  - **Next Action 후보**: 체크박스 목록으로 표시 (Subject / Priority / DueDate)
  - **Next Action 추가** 버튼으로 사용자가 직접 항목 입력 가능
- "SF 저장" 버튼:
  - 영업활동 내용 → SalesActivity__c 의 `ActivityContent__c` 필드 업데이트
  - 체크된 Next Action → `SalesActionItem__c` 일괄 생성 (`SalesActivity__c` Lookup 포함)

---

## LWC 2: salesHistoryAssistant
**위치**: Account / Opportunity 레코드 페이지에 임베드  
**역할**: 이전 영업활동 이력 조회 및 AI 영업전략 조언

### 기능
- 레코드 페이지 진입 시 해당 Account 또는 Opportunity의 SalesActivity__c 이력 자동 로드
- 타임라인 형태로 이전 영업활동 목록 표시 (날짜 / Subject / 영업활동 내용 요약)
- "AI 전략 분석" 버튼 클릭 시:
  - 이전 영업활동 이력 종합 요약
  - 단기 / 중기 / 장기 영업전략 조언 자동 생성

---

## AI 영업비서 버튼명 규칙
- Subject가 '고객 미팅 진행' 또는 '전화 통화'인 경우: **"AI 브리핑 생성"**
- Subject가 '이메일 커뮤니케이션'인 경우: **"AI 메일 초안 생성"**
- Subject 값에 따라 버튼명 동적으로 변경되도록 구현

### Subject 매핑 및 예외 처리
- 허용 값:
  - `고객 미팅 진행`
  - `전화 통화`
  - `이메일 커뮤니케이션`
- 기타 값 또는 null:
  - 버튼명: **"AI 브리핑 생성"**
  - 처리 모드: 기본 브리핑 모드
  - 사용자 안내: "기본 브리핑으로 생성되었습니다. Subject를 확인해 주세요."

---

## 생성할 파일

```
force-app/main/default/
├── lwc/
│   ├── salesActivityRecorder/
│   │   ├── salesActivityRecorder.html
│   │   ├── salesActivityRecorder.js
│   │   ├── salesActivityRecorder.css
│   │   └── salesActivityRecorder.js-meta.xml
│   └── salesHistoryAssistant/
│       ├── salesHistoryAssistant.html
│       ├── salesHistoryAssistant.js
│       ├── salesHistoryAssistant.css
│       └── salesHistoryAssistant.js-meta.xml
└── classes/
    ├── SalesCommService.cls
    └── SalesCommService.cls-meta.xml
```