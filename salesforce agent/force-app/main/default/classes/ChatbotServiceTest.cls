@isTest
private class ChatbotServiceTest {
    @testSetup
    static void setupData() {
        insert new AI_Agent_Settings__c(Name = 'Test Settings', LLM_API_Key__c = 'test-llm-key');

        Id uid = UserInfo.getUserId();
        Account acc = new Account(Name = 'Coverage Test Account', Industry = 'Technology', Type = 'Customer');
        insert acc;

        Date thisMonthMid = Date.today().toStartOfMonth().addDays(10);
        Date nextMonthMid = Date.today().toStartOfMonth().addMonths(1).addDays(10);

        Opportunity oppThis = new Opportunity(
            Name = 'This Month Opp',
            StageName = 'Prospecting',
            CloseDate = thisMonthMid,
            AccountId = acc.Id,
            OwnerId = uid,
            Amount = 50000
        );
        Opportunity oppNext = new Opportunity(
            Name = 'Next Month Opp',
            StageName = 'Prospecting',
            CloseDate = nextMonthMid,
            AccountId = acc.Id,
            OwnerId = uid,
            Amount = 75000
        );
        insert new List<Opportunity>{ oppThis, oppNext };

        Contact con = new Contact(LastName = 'CoverageContact', Email = 'cov@test.example', AccountId = acc.Id, OwnerId = uid);
        insert con;

        Task openTask = new Task(
            Subject = 'Coverage Task Open',
            OwnerId = uid,
            Status = 'Not Started',
            Priority = 'Normal',
            ActivityDate = Date.today()
        );
        Task closedTask = new Task(
            Subject = 'Coverage Task Closed',
            OwnerId = uid,
            Status = 'Completed',
            Priority = 'Low',
            ActivityDate = Date.today()
        );
        insert new List<Task>{ openTask, closedTask };
    }

    private class TwoStepMock implements HttpCalloutMock {
        private final String firstCallText;
        private final String secondAnswer;
        private Integer callCount = 0;

        TwoStepMock(String firstCallText, String secondAnswer) {
            this.firstCallText = firstCallText;
            this.secondAnswer = String.isNotBlank(secondAnswer) ? secondAnswer : '답변';
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            callCount++;
            if (callCount == 1) {
                res.setBody('{"content":[{"type":"text","text":' + JSON.serialize(firstCallText) + '}]}');
            } else {
                res.setBody('{"content":[{"type":"text","text":' + JSON.serialize(secondAnswer) + '}]}');
            }
            return res;
        }
    }

    @isTest
    static void askSalesCloud_returnsMapWithAnswerAndRecords() {
        String intent =
            '{"objects":["Account"],"nameKeyword":null,"opportunityCloseThisMonth":false,'
            + '"opportunityCloseNextMonth":false,"taskIncompleteOnly":false,"maxRows":5}';
        Test.setMock(HttpCalloutMock.class, new TwoStepMock(intent, '테스트 답변입니다.'));

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
        }
        System.assert(threw, '빈 질문은 예외여야 합니다.');
    }

    @isTest
    static void askSalesCloud_questionTooLong_throws() {
        List<String> chunks = new List<String>();
        for (Integer i = 0; i < 251; i++) {
            chunks.add('xxxxxxxx');
        }
        String longQuestion = String.join(chunks, '');
        System.assert(longQuestion.length() > 2000, '질문은 2000자를 초과해야 합니다. 실제=' + longQuestion.length());

        Boolean threw = false;
        try {
            ChatbotService.askSalesCloud(longQuestion);
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, '2000자 초과 질문은 예외여야 합니다.');
    }

    @isTest
    static void askSalesCloud_intentInCodeFence_parses() {
        String intent =
            '```json\n{"objects":["Contact"],"nameKeyword":null,"opportunityCloseThisMonth":false,'
            + '"opportunityCloseNextMonth":false,"taskIncompleteOnly":false,"maxRows":10}\n```';
        Test.setMock(HttpCalloutMock.class, new TwoStepMock(intent, '펜스 파싱 OK'));

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('연락처 알려줘');
        Test.stopTest();

        System.assertEquals('펜스 파싱 OK', result.get('answer'));
    }

    @isTest
    static void askSalesCloud_malformedIntent_usesFallback() {
        Test.setMock(HttpCalloutMock.class, new TwoStepMock('이건 JSON이 아님', '폴백 후 답변'));

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('아무 질문');
        Test.stopTest();

        System.assertNotEquals(null, result.get('records'));
    }

    @isTest
    static void askSalesCloud_opportunityCloseThisMonth_filter() {
        String intent =
            '{"objects":["Opportunity"],"nameKeyword":null,"opportunityCloseThisMonth":true,'
            + '"opportunityCloseNextMonth":false,"taskIncompleteOnly":false,"maxRows":20}';
        Test.setMock(HttpCalloutMock.class, new TwoStepMock(intent, '이번 달 기회'));

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('이번 달 마감 기회');
        Test.stopTest();

        System.assertEquals('이번 달 기회', result.get('answer'));
    }

    @isTest
    static void askSalesCloud_opportunityCloseNextMonth_filter() {
        String intent =
            '{"objects":["Opportunity"],"nameKeyword":null,"opportunityCloseThisMonth":false,'
            + '"opportunityCloseNextMonth":true,"taskIncompleteOnly":false,"maxRows":20}';
        Test.setMock(HttpCalloutMock.class, new TwoStepMock(intent, '다음 달 기회'));

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('다음 달 마감 기회');
        Test.stopTest();

        System.assertEquals('다음 달 기회', result.get('answer'));
    }

    @isTest
    static void askSalesCloud_tasksIncompleteOnly() {
        String intent =
            '{"objects":["Task"],"nameKeyword":null,"opportunityCloseThisMonth":false,'
            + '"opportunityCloseNextMonth":false,"taskIncompleteOnly":true,"maxRows":20}';
        Test.setMock(HttpCalloutMock.class, new TwoStepMock(intent, '미완료 할 일'));

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('할 일');
        Test.stopTest();

        System.assertEquals('미완료 할 일', result.get('answer'));
    }

    @isTest
    static void askSalesCloud_nameKeywordAndMultiType_trim() {
        String intent =
            '{"objects":["Account","Opportunity"],"nameKeyword":"Coverage",'
            + '"opportunityCloseThisMonth":false,"opportunityCloseNextMonth":false,'
            + '"taskIncompleteOnly":false,"maxRows":8}';
        Test.setMock(HttpCalloutMock.class, new TwoStepMock(intent, '키워드 및 다중 객체'));

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('Coverage 검색');
        Test.stopTest();

        System.assertEquals('키워드 및 다중 객체', result.get('answer'));
        List<Object> recs = (List<Object>) result.get('records');
        System.assert(recs != null && recs.size() <= 8, 'maxRows 초과 시 잘려야 합니다.');
    }

    @isTest
    static void askSalesCloud_invalidObjects_rewritesDefaults() {
        String intent =
            '{"objects":["CustomObject__c"],"nameKeyword":null,"opportunityCloseThisMonth":false,'
            + '"opportunityCloseNextMonth":false,"taskIncompleteOnly":false,"maxRows":10}';
        Test.setMock(HttpCalloutMock.class, new TwoStepMock(intent, '기본 객체로 대체'));

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('허용되지 않은 객체');
        Test.stopTest();

        System.assertEquals('기본 객체로 대체', result.get('answer'));
    }

    @isTest
    static void askSalesCloud_maxRowsFromStringAndBounds() {
        String intent =
            '{"objects":["Account"],"nameKeyword":null,"opportunityCloseThisMonth":false,'
            + '"opportunityCloseNextMonth":false,"taskIncompleteOnly":false,"maxRows":"3"}';
        Test.setMock(HttpCalloutMock.class, new TwoStepMock(intent, 'maxRows 문자열'));

        Test.startTest();
        Map<String, Object> result = ChatbotService.askSalesCloud('소수만');
        Test.stopTest();

        System.assertEquals('maxRows 문자열', result.get('answer'));
    }
}
