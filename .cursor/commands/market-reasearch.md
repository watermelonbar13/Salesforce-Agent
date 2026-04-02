---
description: 선택한 Account의 시장조사 보고서 LWC + Apex 생성
---

# /market-research 커맨드

## 참조 Skills
@skills/salesforce-data-model.md
@skills/g2b-api.md
@skills/dart-api.md
@skills/llm-api.md

## 역할
영업대표가 Account를 선택하면 시장조사 보고서를 자동 생성하는
LWC 컴포넌트와 Apex 클래스를 만든다.

## 생성할 파일
```
force-app/main/default/
├── lwc/marketResearchReport/
│   ├── marketResearchReport.html
│   ├── marketResearchReport.js
│   ├── marketResearchReport.css
│   └── marketResearchReport.js-meta.xml
└── classes/
    ├── MarketResearchService.cls
    └── MarketResearchService.cls-meta.xml
```

## 입력
- accountId: 선택한 Account의 Salesforce Id

## 출력 (LWC 탭 구성)
1. **기업 개요** - SF Account 정보 + 진행 중인 Opportunity 목록
2. **최신 뉴스** - 기업명으로 검색한 뉴스 5개 + 요약
3. **발주공고** - 나라장터 관련 공고 5개
4. **기업 공시** - DART 최근 공시 (상장사인 경우)
5. **AI 분석** - 전체 데이터 종합 영업 인사이트

## Apex 구현 요구사항
- getAccountDetail(): Account + Opportunity + Contact 조회
- getFullReport(): 뉴스 + 발주공고 + DART + AI분석 통합
- 각 외부 API는 @skills 참조하여 구현
- 모든 Callout은 api-rules.mdc 패턴 준수

## LWC 구현 요구사항
- 탭별 독립 로딩 (전체 로딩 대기 X)
- AI 분석 탭은 나머지 완료 후 생성
- 보고서 새로고침 버튼 포함
- 모든 텍스트 한국어 표시
