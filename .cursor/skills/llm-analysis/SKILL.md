# AI 분석 기능

## 개요
Claude API를 Apex Callout으로 호출하여 영업 인사이트, 이메일 초안,
미팅 준비, 로그 분석 등 AI 기반 콘텐츠를 생성하는 기능

## API 키 저장 위치
```
Setup → Custom Settings → AI_Agent_Settings__c
- LLM_API_Key__c (Claude API 키)
```

## Named Credential 설정
```
Setup → Security → Named Credentials → New
Label: Claude_API
Name: Claude_API
URL: https://api.anthropic.com
Identity Type: Anonymous
```

## Remote Site Settings 등록
```
Setup → Security → Remote Site Settings → New
Remote Site Name: Claude_API
Remote Site URL: https://api.anthropic.com
```

## 기본 Apex 호출 패턴
```apex
public class LLMService {
    private static final String MODEL = 'claude-sonnet-4-20250514';
    private static final Integer MAX_TOKENS = 2000;

    private static String callClaude(String prompt) {
        AI_Agent_Settings__c settings = AI_Agent_Settings__c.getInstance();

        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => MODEL,
            'max_tokens' => MAX_TOKENS,
            'messages' => new List<Object>{
                new Map<String, Object>{ 'role' => 'user', 'content' => prompt }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Claude_API/v1/messages');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('x-api-key', settings.LLM_API_Key__c);
        req.setHeader('anthropic-version', '2023-06-01');
        req.setBody(JSON.serialize(requestBody));
        req.setTimeout(30000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> content = (List<Object>) body.get('content');
                return (String) ((Map<String, Object>) content[0]).get('text');
            }
        } catch (Exception e) {
            System.debug('LLM 오류: ' + e.getMessage());
            throw new AuraHandledException('AI 분석 중 오류가 발생했습니다.');
        }
        return null;
    }
```

## 기능별 프롬프트 패턴

### 시장조사 분석
```apex
public static String analyzeMarketResearch(String accountName, Map<String, Object> data) {
    String prompt = accountName + ' 기업에 대한 영업 인사이트를 한국어로 작성해주세요.\n\n'
        + '데이터: ' + JSON.serialize(data) + '\n\n'
        + '1. 현재 상황 요약\n2. 영업 기회 포인트\n3. 주의사항\n4. 추천 액션 3가지';
    return callClaude(prompt);
}
```

### 이메일 초안
```apex
public static String generateEmail(Account acc, String purpose) {
    String prompt = '다음 정보로 영업 이메일 초안을 한국어로 작성해주세요.\n'
        + '고객사: ' + acc.Name + ' / 업종: ' + acc.Industry + ' / 목적: ' + purpose;
    return callClaude(prompt);
}
```

### 미팅 준비 체크리스트
```apex
public static String generateMeetingChecklist(Account acc, String meetingDate) {
    String prompt = acc.Name + ' 미팅(' + meetingDate + ') 준비 체크리스트와 예상 Q&A를 한국어로 작성해주세요.';
    return callClaude(prompt);
}
```

### 통화/미팅 로그 분석
```apex
public static Map<String, Object> analyzeCommLog(String logContent, String commType) {
    String prompt = commType + ' 내용을 분석하여 아래 JSON 형식으로만 응답해주세요.\n\n'
        + '내용: ' + logContent + '\n\n'
        + '{"summary":"5줄 요약","actionItems":[{"subject":"","description":"","priority":"High/Normal/Low","dueDate":"YYYY-MM-DD"}],"nextBestAction":"추천 액션"}';
    String response = callClaude(prompt);
    return (Map<String, Object>) JSON.deserializeUntyped(response);
}
```

### 영업전략 조언
```apex
public static String generateSalesStrategy(Account acc) {
    String prompt = acc.Name + ' 영업전략을 단기(이번 주)/중기(이번 달)/장기(분기)로 나눠 한국어로 작성해주세요.\n'
        + '업종: ' + acc.Industry + ' / 마지막 활동: ' + acc.LastActivityDate;
    return callClaude(prompt);
}
```

### 사업기회 추천
```apex
public static List<Map<String, Object>> recommendOpportunities(List<Opportunity> history, List<Account> accounts) {
    String prompt = '과거 영업 이력 기반으로 신규 사업기회를 추천해주세요.\n\n'
        + '이력: ' + JSON.serialize(history) + '\nAccount: ' + JSON.serialize(accounts) + '\n\n'
        + 'JSON 배열로만 응답: [{"accountName":"","reason":"","score":0,"nextAction":""}]';
    String response = callClaude(prompt);
    return (List<Map<String, Object>>) JSON.deserializeUntyped(response);
}
```

## 프롬프트 규칙
- 반드시 한국어 응답 요청
- JSON 응답 필요 시 형식 명확히 지정하고 JSON으로만 응답 요청
- 응답 길이 제한 명시 (토큰 절약)

### 미팅 내용 분석
```apex
public static Map<String, Object> analyzeMeetingTranscript(String transcript) {
    String prompt = '다음 미팅 녹취 내용을 분석하여 아래 JSON 형식으로만 응답해주세요.\n\n'
        + '녹취: ' + transcript + '\n\n'
        + '{"summary":"5줄 핵심 요약","actionItems":[{"subject":"","description":"","priority":"High/Normal/Low","dueDate":"YYYY-MM-DD"}]}';
    String response = callClaude(prompt);
    return (Map<String, Object>) JSON.deserializeUntyped(response);
}
```

### 이전 미팅 이력 종합 요약 + 영업전략
```apex
public static String analyzeMeetingHistory(String accountName, List<Task> pastMeetings) {
    String prompt = accountName + ' 고객사의 이전 미팅 이력을 종합하여 한국어로 작성해주세요.\n\n'
        + '미팅 이력: ' + JSON.serialize(pastMeetings) + '\n\n'
        + '다음 항목을 포함해주세요:\n'
        + '1. 이전 미팅 핵심 요약 (미팅별)\n'
        + '2. 주요 논의 주제 및 진행 현황\n'
        + '3. 미완료 Action Item\n'
        + '4. 영업전략 조언 (단기/중기/장기)';
    return callClaude(prompt);
}
```