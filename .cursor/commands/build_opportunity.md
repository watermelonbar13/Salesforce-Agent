# /build-opportunity

Salesforce 이력과 외부 발주공고를 분석하여 신규 사업기회를 추천하는 기능을 만든다.

## 실행 순서

1. `@.cursor/skills/salesforce/SKILL.md` 참고하여 Opportunity 이력 + 담당 Account 조회 로직 구현
2. `@.cursor/skills/public-data/SKILL.md` 참고하여 나라장터 발주공고 조회 로직 구현
3. `@.cursor/skills/llm-analysis/SKILL.md` 참고하여 AI 패턴 분석 + 추천 로직 구현
4. `@.cursor/skills/salesforce/SKILL.md` 참고하여 Opportunity 생성 로직 구현
5. 위 1~4를 묶어서 `OpportunityGeneratorService.cls` 생성
6. 추천 카드 + Opportunity 생성 버튼 포함한 LWC 화면 생성
7. 완료 후 `@.cursor/skills/salesforce-dx/SKILL.md` 참고하여 Sandbox 배포

## 수행할 일
1. 현재 로그인한 영업대표의 과거 12개월 Opportunity 이력 조회
2. 진행 중인 Opportunity가 없는 담당 Account 목록 조회
3. 나라장터에서 관련 발주공고 조회
4. AI가 패턴 분석 후 우선순위 점수화하여 추천 5개 생성
5. 추천 항목 클릭 시 SF Opportunity 바로 생성

## 출력 화면 (LWC 탭 구성)
- **탭1. 이력 기반 추천**: 과거 성공 패턴 분석 → 추천 리스트
- **탭2. 발주공고 기반 추천**: 나라장터 공고 매칭 → 추천 리스트

### 추천 카드 구성
- 우선순위 점수 (0~100)
- 추천 이유 (AI 생성)
- Opportunity 생성 버튼 → 클릭 시 SF에 바로 Opportunity 생성

## 우선순위 점수 기준
| 항목 | 점수 |
|------|------|
| 기존 거래 이력 있음 | +30점 |
| 최근 6개월 내 미팅 | +20점 |
| 업종 일치 | +20점 |
| 발주 금액 규모 | +15점 |
| 마감일 30일 이내 | +15점 |

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
