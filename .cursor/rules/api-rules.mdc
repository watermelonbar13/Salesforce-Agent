---
description: 외부 API Callout 및 에러 처리 공통 규칙
alwaysApply: true
---

# API Rules

## Named Credential 규칙
- 모든 외부 API는 반드시 Named Credential 사용
- URL 하드코딩 절대 금지
- API 키는 Custom Settings (AI_Agent_Settings__c) 에 저장

## Custom Settings 구조
```
AI_Agent_Settings__c
├── G2B_API_Key__c       (나라장터)
├── DART_API_Key__c      (DART)
├── LLM_API_Key__c       (Claude/GPT)
└── NewsAPI_Key__c       (NewsAPI)
```

## Callout 기본 패턴
```apex
public static String callAPI(String namedCredential, String path, String method, String body) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:' + namedCredential + path);
    req.setMethod(method);
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(30000);
    if (body != null) req.setBody(body);

    try {
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            return res.getBody();
        } else {
            throw new CalloutException('API 오류: ' + res.getStatusCode() + ' ' + res.getBody());
        }
    } catch (Exception e) {
        System.debug('Callout 실패: ' + e.getMessage());
        throw new AuraHandledException('외부 서비스 연결에 실패했습니다.');
    }
}
```

## LLM API 규칙
- 모델: claude-sonnet-4-20250514 (기본)
- max_tokens: 2000
- 응답은 반드시 한국어로 요청
- 프롬프트는 LLMService.cls에서 중앙 관리

## 에러 코드별 처리
| 코드 | 처리 방법 |
|------|---------|
| 400 | 요청 파라미터 확인 후 재시도 |
| 401 | API 키 확인 안내 메시지 |
| 429 | 잠시 후 재시도 안내 |
| 500 | "서비스 일시 중단" 안내 |
| timeout | "응답 시간 초과" 안내 |

## Remote Site Settings
외부 API 호출 전 반드시 등록:
```
Setup → Security → Remote Site Settings → New
```

## 응답 파싱 규칙
- JSON 파싱은 `JSON.deserializeUntyped()` 사용
- null 체크 반드시 수행
- 파싱 실패 시 빈 리스트 반환 (예외 던지지 않음)
