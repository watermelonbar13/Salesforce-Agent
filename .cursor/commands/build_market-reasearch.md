# /build-market-research

영업대표가 선택한 Account의 시장조사 보고서를 자동 생성하는 기능을 만든다.

## 실행 순서

1. `@.cursor/skills/salesforce/SKILL.md` 참고하여 Account 상세 조회 로직 구현
2. `@.cursor/skills/web-search/SKILL.md` 참고하여 뉴스 검색 로직 구현
3. `@.cursor/skills/public-data/SKILL.md` 참고하여 나라장터/DART 조회 로직 구현
4. `@.cursor/skills/llm-analysis/SKILL.md` 참고하여 AI 종합 분석 로직 구현
5. 위 1~4를 묶어서 `MarketResearchService.cls` 생성
6. 탭 형태의 LWC 보고서 화면 생성
7. 완료 후 `@.cursor/skills/salesforce-dx/SKILL.md` 참고하여 Sandbox 배포

## 수행할 일
1. 입력받은 accountId로 Salesforce에서 Account 상세 정보 조회
2. 기업명으로 최신 뉴스 5개 검색
3. 나라장터에서 관련 발주공고 5개 조회
4. DART에서 기업 공시 정보 조회 (상장사인 경우)
5. 수집된 모든 데이터를 AI로 종합 분석하여 영업 인사이트 생성
6. 탭 형태의 LWC 보고서 화면 생성

## 출력 화면 (LWC 탭 구성)
- **탭1. 기업 개요**: SF Account 정보 + 진행 중 Opportunity 목록
- **탭2. 최신 뉴스**: 뉴스 5개 + 링크
- **탭3. 발주공고**: 나라장터 관련 공고 5개 (공고명, 기관, 예산, 마감일)
- **탭4. 기업 공시**: DART 최근 공시 5개
- **탭5. AI 분석**: 전체 데이터 종합 영업 인사이트
  - 현재 상황 요약
  - 영업 기회 포인트
  - 주의사항
  - 추천 액션 3가지

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
