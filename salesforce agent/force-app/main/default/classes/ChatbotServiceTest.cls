@isTest
private class ChatbotServiceTest {
    @testSetup
    static void setupSettings() {
        AI_Agent_Settings__c settings = new AI_Agent_Settings__c();
        settings.SetupOwnerId = UserInfo.getUserId();
        settings.LLM_API_Key__c = 'test-llm-key';
        insert settings;
    }

    private class ClaudeTwoStepMock implements HttpCalloutMock {
        private Integer callCount = 0;

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            callCount++;
            if (callCount == 1) {
                res.setBody(
                    '{"content":[{"type":"text","text":"{\\"objects\\":[\\"Account\\"],\\"nameKeyword\\":null,\\"opportunityCloseThisMonth\\":false,\\"opportunityCloseNextMonth\\":false,\\"taskIncompleteOnly\\":false,\\"maxRows\\":5}"}]}'
                );
            } else {
                res.setBody('{"content":[{"type":"text","text":"테스트 답변입니다."}]}');
            }
            return res;
        }
    }

    @isTest
    static void askSalesCloud_returnsMapWithAnswerAndRecords() {
        Test.setMock(HttpCalloutMock.class, new ClaudeTwoStepMock());

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('담당 Account 목록 알려줘');
        Test.stopTest();

        System.assertNotEquals(null, result, '결과가 있어야 합니다.');
        System.assertEquals('테스트 답변입니다.', result.get('answer'));
        System.assert(result.get('records') instanceof List<Object>, 'records는 리스트여야 합니다.');
    }

    @isTest
    static void askSalesCloud_blankQuestion_throws() {
        Boolean threw = false;
        try {
            ChatbotService.askSalesCloud('   ');
        } catch (AuraHandledException e) {
            threw = true;
            System.assert(e.getMessage().contains('질문'));
        }
        System.assert(threw, '빈 질문은 예외여야 합니다.');
    }
}
