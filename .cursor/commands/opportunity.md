---
description: 제안 이력 + 발주공고 기반 신규 사업기회 추천 LWC + Apex 생성
---

# /opportunity 커맨드

## 참조 Skills
@skills/salesforce-data-model.md
@skills/g2b-api.md
@skills/llm-api.md

## 역할
Salesforce Opportunity 이력과 외부 발주공고를 분석하여
신규 사업기회를 추천하는 LWC 컴포넌트와 Apex 클래스를 만든다.

## 생성할 파일
```
force-app/main/default/
├── lwc/opportunityGenerator/
│   ├── opportunityGenerator.html
│   ├── opportunityGenerator.js
│   ├── opportunityGenerator.css
│   └── opportunityGenerator.js-meta.xml
└── classes/
    ├── OpportunityGeneratorService.cls
    └── OpportunityGeneratorService.cls-meta.xml
```

## 입력
- 현재 로그인한 영업대표의 UserId (UserInfo.getUserId())

## 출력 (LWC 탭 구성)
1. **이력 기반 추천** - 과거 Opportunity 패턴 분석 → 추천 5개
2. **발주공고 기반 추천** - 나라장터 공고 매칭 → 추천 5개
3. **추천 결과** - 우선순위 점수 + 추천 이유 + Opportunity 생성 버튼

## 우선순위 점수 기준
| 항목 | 점수 |
|------|------|
| 기존 거래 이력 있음 | +30점 |
| 최근 6개월 내 미팅 | +20점 |
| 업종 일치 | +20점 |
| 발주 금액 규모 | +15점 |
| 마감일 30일 이내 | +15점 |

## Apex 구현 요구사항
- getRecommendationsByHistory(): 과거 12개월 Opportunity 이력 분석
- getRecommendationsByBids(): 나라장터 공고와 내 Account 매칭
- createOpportunity(): 추천 항목으로 SF Opportunity 생성
- 기존 진행 중인 Opportunity와 중복 제외 로직 필수

## LWC 구현 요구사항
- Opportunity 생성 전 반드시 확인 모달 표시
- 추천 이유 툴팁으로 표시
- 점수 기준 설명 팝오버 제공
- 모든 텍스트 한국어 표시
