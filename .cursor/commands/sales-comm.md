---
description: 통화/미팅 로그 정리, Action Item SF 등록, 영업전략 조언 LWC + Apex 생성
---

# /sales-comm 커맨드

## 참조 Skills
@skills/salesforce-data-model.md
@skills/llm-api.md

## 역할
고객과의 통화/미팅 내용을 자동 정리하고 Action Item을 SF에 등록하며
Next Best Action과 영업전략을 조언하는 LWC + Apex를 만든다.

## 생성할 파일
```
force-app/main/default/
├── lwc/salesCommAssistant/
│   ├── salesCommAssistant.html
│   ├── salesCommAssistant.js
│   ├── salesCommAssistant.css
│   └── salesCommAssistant.js-meta.xml
└── classes/
    ├── SalesCommService.cls
    └── SalesCommService.cls-meta.xml
```

## 입력
- accountId: 선택한 Account의 Salesforce Id
- logContent: 통화/미팅 내용 텍스트
- commType: 통화 or 미팅

## 출력 (LWC 탭 구성)
1. **로그 입력** - 통화/미팅 내용 입력 텍스트 영역
2. **AI 분석** - 핵심 요약 5줄 + Action Item 목록
3. **Action Item 등록** - 체크박스로 선택 후 SF Task 일괄 등록
4. **영업전략 조언** - 현재 Account 상황 기반 단기/중기/장기 전략

## Apex 구현 요구사항
- analyzeCommLog(): 통화/미팅 내용 AI 분석 (요약 + Action Item 추출)
- saveActionItems(): 선택된 Action Item SF Task 일괄 등록
- getSalesStrategyAdvice(): Account 전체 이력 기반 영업전략 생성
- saveCommLog(): 통화/미팅 로그 SF Activity 저장

## LWC 구현 요구사항
- Action Item 체크박스로 선택적 등록
- Task 우선순위 AI 자동 설정 (High/Normal/Low)
- 로그 저장 전 요약 내용 확인 모달
- 등록 완료 시 성공 토스트 메시지
- 모든 텍스트 한국어 표시
