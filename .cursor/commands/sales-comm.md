# 통화/미팅 로그 정리

고객과의 통화/미팅 내용을 자동 정리하고 Action Item을 SF에 등록한다.

## 수행할 일
1. 통화/미팅 내용 텍스트 입력받기
2. AI로 핵심 내용 5줄 요약 + Action Item 추출
3. 추출된 Action Item 체크박스로 선택 후 SF Task 일괄 등록
4. 통화/미팅 로그 SF Activity에 저장
5. 현재 Account 상황 기반 영업전략 조언 제공

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

## 출력 화면 (LWC 탭 구성)
- **탭1. 로그 입력**: 통화/미팅 내용 텍스트 입력
- **탭2. AI 분석**: 핵심 요약 + Action Item 목록
- **탭3. Action Item 등록**: 체크박스 선택 → SF Task 일괄 등록
- **탭4. 영업전략 조언**: 단기/중기/장기 전략 제안

## 참고 기능
- Salesforce 조회/저장: @.cursor/skills/salesforce/SKILL.md
- AI 분석: @.cursor/skills/llm-analysis/SKILL.md