/**
 * Claude API 호출 공통 모듈. 프롬프트 조합은 각 기능 서비스에서 수행한다.
 */
public with sharing class LLMService {
    private static final String MODEL = 'claude-sonnet-4-20250514';
    private static final Integer MAX_TOKENS = 2000;

    public static String callClaude(String prompt) {
        if (String.isBlank(prompt)) {
            throw new AuraHandledException('프롬프트가 비어 있습니다.');
        }

        AI_Agent_Settings__c settings = AI_Agent_Settings__c.getInstance();
        if (settings == null || String.isBlank(settings.LLM_API_Key__c)) {
            System.debug('LLM API 키 미설정');
            throw new AuraHandledException('AI 설정(LLM API 키)을 확인해 주세요.');
        }

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
                if (content == null || content.isEmpty()) {
                    return null;
                }
                Map<String, Object> block = (Map<String, Object>) content[0];
                return (String) block.get('text');
            }
            System.debug('Claude API 오류: ' + res.getStatusCode() + ' ' + res.getBody());
            throw new AuraHandledException('AI 서비스 응답 오류: ' + res.getStatusCode());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('Callout 실패: ' + e.getMessage());
            throw new AuraHandledException('외부 AI 서비스 연결에 실패했습니다.');
        }
    }
}
