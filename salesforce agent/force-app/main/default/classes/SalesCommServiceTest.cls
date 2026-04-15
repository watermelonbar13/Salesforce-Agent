@isTest
private class SalesCommServiceTest {
    @testSetup
    static void setupData() {
        insert new AI_Agent_Settings__c(Name = 'SalesComm Test', LLM_API_Key__c = 'test-llm-key');
    }

    private class LlmMock implements HttpCalloutMock {
        private final List<String> payloads;
        private Integer indexPos = 0;

        LlmMock(List<String> payloads) {
            this.payloads = payloads;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            String content = payloads[Math.min(indexPos, payloads.size() - 1)];
            indexPos++;
            res.setBody('{"choices":[{"message":{"role":"assistant","content":' + JSON.serialize(content) + '}}]}');
            return res;
        }
    }

    @isTest
    static void analyzeRecording_returnsSchema() {
        String llmJson =
            '{"summary":"요약입니다","actionItems":[{"subject":"후속 미팅","priority":"High","dueDate":"2026-04-20","reason":"고객 요청"}],'
            + '"warnings":[],"confidence":0.8}';
        Test.setMock(HttpCalloutMock.class, new LlmMock(new List<String>{ llmJson }));

        Test.startTest();
        Map<String, Object> result = SalesCommService.analyzeRecording('테스트 녹취 내용');
        Test.stopTest();

        System.assertEquals('요약입니다', result.get('summary'));
        System.assert(result.get('actionItems') instanceof List<Object>, 'actionItems는 리스트여야 합니다.');
    }

    @isTest
    static void analyzeRecording_parseFallback() {
        Test.setMock(HttpCalloutMock.class, new LlmMock(new List<String>{ 'JSON 아님' }));

        Test.startTest();
        Map<String, Object> result = SalesCommService.analyzeRecording('테스트 녹취');
        Test.stopTest();

        System.assertEquals('', result.get('summary'));
        System.assert(result.get('warnings') instanceof List<Object>, 'warnings는 리스트여야 합니다.');
    }

    @isTest
    static void getAISalesStrategy_returnsText() {
        Test.setMock(HttpCalloutMock.class, new LlmMock(new List<String>{ '단기/중기/장기 전략 제안' }));

        Test.startTest();
        String result = SalesCommService.getAISalesStrategy(new List<Object>{ new Map<String, Object>{ 'subject' => '미팅' } });
        Test.stopTest();

        System.assertEquals('단기/중기/장기 전략 제안', result);
    }
}
