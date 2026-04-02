---
description: 이메일 초안, 미팅 준비, 미팅 기록, Next Task 추천 LWC + Apex 생성
---

# /sales-activity 커맨드

## 참조 Skills
@skills/salesforce-data-model.md
@skills/llm-api.md

## 역할
영업대표의 고객 커뮤니케이션과 미팅 준비를 지원하는
LWC 컴포넌트와 Apex 클래스를 만든다.

## 생성할 파일
```
force-app/main/default/
├── lwc/salesActivityAssistant/
│   ├── salesActivityAssistant.html
│   ├── salesActivityAssistant.js
│   ├── salesActivityAssistant.css
│   └── salesActivityAssistant.js-meta.xml
└── classes/
    ├── SalesActivityService.cls
    └── SalesActivityService.cls-meta.xml
```

## 입력
- accountId: 선택한 Account의 Salesforce Id

## 출력 (LWC 탭 구성)
1. **이메일 초안** - 목적 입력 → AI 초안 생성 → 복사 버튼
2. **미팅 준비** - 날짜 입력 → 체크리스트 + 예상 Q&A 생성
3. **미팅 기록** - 내용 입력 → AI 요약 → SF Activity 저장
4. **Next Task** - AI 추천 Task 목록 → SF Task 등록

## Apex 구현 요구사항
- generateEmailDraft(): Account + Contact + Opportunity 조회 후 AI 초안 생성
- getMeetingPrep(): 이전 Activity 이력 조회 + AI 체크리스트/Q&A 생성
- saveActivityLog(): 미팅 내용 SF Task로 저장
- saveTask(): Next Task SF 등록

## LWC 구현 요구사항
- SF 저장 전 반드시 확인 모달 표시
- 이메일 초안 복사 버튼 제공
- AI 생성 내용은 수정 가능한 textarea로 표시
- Task 저장 시 성공 토스트 메시지 표시
- 모든 텍스트 한국어 표시
