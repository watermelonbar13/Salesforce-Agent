# 시장조사 보고서 작성

영업대표가 선택한 Account의 시장조사 보고서를 자동 생성한다.

## 수행할 일
1. 입력받은 accountId로 Salesforce에서 Account 상세 정보 조회
2. 기업명으로 최신 뉴스 5개 검색
3. 나라장터에서 관련 발주공고 조회
4. DART에서 기업 공시 정보 조회 (상장사인 경우)
5. 수집된 모든 데이터를 AI로 종합 분석
6. 탭 형태의 LWC 보고서 화면 생성

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

## 출력 화면 (LWC 탭 구성)
- **탭1. 기업 개요**: SF Account 정보 + 진행 중 Opportunity 목록
- **탭2. 최신 뉴스**: 뉴스 5개 + 요약
- **탭3. 발주공고**: 나라장터 관련 공고 5개
- **탭4. 기업 공시**: DART 최근 공시
- **탭5. AI 분석**: 전체 데이터 종합 영업 인사이트

## 참고 기능
- Salesforce 조회: @.cursor/skills/salesforce/SKILL.md
- 뉴스 검색: @.cursor/skills/web-search/SKILL.md
- 발주공고/공시: @.cursor/skills/public-data/SKILL.md
- AI 분석: @.cursor/skills/llm-analysis/SKILL.md