/**
 * Sales Cloud 자연어 질의: Claude로 조회 의도(JSON) 파싱 → 안전한 SOQL 조회 → Claude로 한국어 답변.
 */
public with sharing class ChatbotService {
    private static final Integer ABSOLUTE_MAX_ROWS = 50;
    private static final Integer DEFAULT_MAX_ROWS = 20;

    @AuraEnabled
    public static Map<String, Object> askSalesCloud(String question) {
        try {
            if (String.isBlank(question)) {
                throw new AuraHandledException('질문을 입력해 주세요.');
            }
            String trimmed = question.trim();
            if (trimmed.length() > 2000) {
                throw new AuraHandledException('질문은 2000자 이내로 입력해 주세요.');
            }

            String intentRaw = LLMService.callClaude(buildIntentPrompt(trimmed));
            Map<String, Object> intent = parseIntent(intentRaw);
            List<Map<String, Object>> salesRecords = fetchSalesRecords(intent);
            String dataPayload = JSON.serialize(salesRecords);
            String answerText = LLMService.callClaude(buildAnswerPrompt(trimmed, dataPayload));

            return new Map<String, Object>{
                'answer' => answerText,
                'records' => salesRecords
            };
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('ChatbotService 오류: ' + e.getMessage());
            throw new AuraHandledException('챗봇 처리 중 오류가 발생했습니다.');
        }
    }

    private static String buildIntentPrompt(String question) {
        return '당신은 Salesforce Sales Cloud 조회 의도 분석기입니다. 사용자 질문을 보고 JSON 한 개만 출력하세요. '
            + '설명·마크다운·코드펜스는 절대 쓰지 마세요.\n\n'
            + '허용 스키마:\n'
            + '{"objects":["Account","Opportunity","Contact","Task"],"nameKeyword":null,"opportunityCloseThisMonth":false,'
            + '"opportunityCloseNextMonth":false,"taskIncompleteOnly":true,"maxRows":20}\n\n'
            + '규칙:\n'
            + '- objects: 질문에 맞게 1개 이상. 전체/통합 검색이면 네 종류 모두 포함.\n'
            + '- nameKeyword: 회사명·이름·제목 일부 검색이 필요할 때만 문자열. 불필요하면 null.\n'
            + '- opportunityCloseThisMonth: "이번 달 마감" 등이면 true.\n'
            + '- opportunityCloseNextMonth: "다음 달 마감"이면 true.\n'
            + '- taskIncompleteOnly: 할 일/미완료 Task 위주면 true, 아니면 false.\n'
            + '- maxRows: 5~' + ABSOLUTE_MAX_ROWS + ' 정수. 기본 20.\n\n'
            + '질문: ' + question;
    }

    private static String buildAnswerPrompt(String question, String salesDataJson) {
        return '다음 Salesforce에서 조회한 실제 데이터(JSON)만 근거로, 사용자 질문에 한국어로 답변하세요.\n'
            + '데이터에 없는 사실은 만들지 마세요. 결과가 없으면 그렇게 말하세요.\n'
            + '번호 목록으로 레코드를 나열하고, 각 항목은 핵심 필드(금액, 단계, 마감일, 상태 등)를 한두 줄로 요약하세요.\n\n'
            + '질문: ' + question + '\n\n'
            + 'SF 데이터(JSON): ' + salesDataJson;
    }

    private static String stripJsonNoise(String raw) {
        if (String.isBlank(raw)) {
            return '{}';
        }
        String t = raw.trim();
        if (t.startsWith('```')) {
            Integer start = t.indexOf('{');
            Integer end = t.lastIndexOf('}');
            if (start >= 0 && end > start) {
                return t.substring(start, end + 1);
            }
        }
        return t;
    }

    private static Map<String, Object> parseIntent(String intentRaw) {
        Map<String, Object> fallback = new Map<String, Object>{
            'objects' => new List<Object>{ 'Account', 'Opportunity', 'Contact', 'Task' },
            'nameKeyword' => null,
            'opportunityCloseThisMonth' => false,
            'opportunityCloseNextMonth' => false,
            'taskIncompleteOnly' => true,
            'maxRows' => DEFAULT_MAX_ROWS
        };

        try {
            String jsonStr = stripJsonNoise(intentRaw);
            Object parsed = JSON.deserializeUntyped(jsonStr);
            if (!(parsed instanceof Map<String, Object>)) {
                return fallback;
            }
            Map<String, Object> m = (Map<String, Object>) parsed;
            Set<String> allowed = new Set<String>{ 'Account', 'Opportunity', 'Contact', 'Task' };
            List<Object> objs = (List<Object>) m.get('objects');
            List<String> cleanObjs = new List<String>();
            if (objs != null) {
                for (Object o : objs) {
                    String name = String.valueOf(o);
                    if (allowed.contains(name)) {
                        cleanObjs.add(name);
                    }
                }
            }
            if (cleanObjs.isEmpty()) {
                cleanObjs.add('Opportunity');
                cleanObjs.add('Account');
            }

            Object maxObj = m.get('maxRows');
            Integer maxRows = DEFAULT_MAX_ROWS;
            if (maxObj instanceof Integer) {
                maxRows = (Integer) maxObj;
            } else if (maxObj instanceof Decimal) {
                maxRows = ((Decimal) maxObj).intValue();
            } else if (maxObj instanceof String && String.isNotBlank((String) maxObj)) {
                try {
                    maxRows = Integer.valueOf((String) maxObj);
                } catch (Exception e) {
                    maxRows = DEFAULT_MAX_ROWS;
                }
            }
            if (maxRows < 5) {
                maxRows = 5;
            }
            if (maxRows > ABSOLUTE_MAX_ROWS) {
                maxRows = ABSOLUTE_MAX_ROWS;
            }

            return new Map<String, Object>{
                'objects' => cleanObjs,
                'nameKeyword' => m.get('nameKeyword'),
                'opportunityCloseThisMonth' => toBoolean(m.get('opportunityCloseThisMonth')),
                'opportunityCloseNextMonth' => toBoolean(m.get('opportunityCloseNextMonth')),
                'taskIncompleteOnly' => toBoolean(m.get('taskIncompleteOnly')),
                'maxRows' => maxRows
            };
        } catch (Exception e) {
            System.debug('의도 JSON 파싱 실패, 기본값 사용: ' + e.getMessage());
            return fallback;
        }
    }

    private static String sanitizeLikeToken(String keyword) {
        if (String.isBlank(keyword)) {
            return null;
        }
        String t = keyword.replace('%', '').replace('_', '').trim();
        return String.isBlank(t) ? null : t;
    }

    private static String baseOrgUrl() {
        return URL.getOrgDomainUrl().toExternalForm();
    }

    private static void addRecord(
        List<Map<String, Object>> bucket,
        String objectApiName,
        Id recordId,
        String title,
        String snippet
    ) {
        bucket.add(
            new Map<String, Object>{
                'objectApiName' => objectApiName,
                'recordId' => String.valueOf(recordId),
                'recordUrl' => baseOrgUrl() + '/lightning/r/' + objectApiName + '/' + recordId + '/view',
                'title' => title,
                'snippet' => snippet
            }
        );
    }

    private static List<Map<String, Object>> fetchSalesRecords(Map<String, Object> intent) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        List<Object> objList = (List<Object>) intent.get('objects');
        Integer maxRows = (Integer) intent.get('maxRows');
        if (maxRows == null) {
            maxRows = DEFAULT_MAX_ROWS;
        }

        String rawKw = intent.get('nameKeyword') != null ? String.valueOf(intent.get('nameKeyword')) : null;
        String kw = sanitizeLikeToken(rawKw);
        String likePattern = String.isNotBlank(kw) ? ('%' + kw + '%') : null;

        Boolean closeThis = (Boolean) intent.get('opportunityCloseThisMonth');
        Boolean closeNext = (Boolean) intent.get('opportunityCloseNextMonth');
        Boolean tasksOpen = (Boolean) intent.get('taskIncompleteOnly');

        Id uid = UserInfo.getUserId();
        Date today = Date.today();
        Date startThis = today.toStartOfMonth();
        Date endThis = startThis.addMonths(1).addDays(-1);
        Date startNext = startThis.addMonths(1);
        Date endNext = startNext.addMonths(1).addDays(-1);

        Set<String> types = new Set<String>();
        for (Object o : objList) {
            types.add(String.valueOf(o));
        }

        Integer perType = maxRows;
        if (types.size() > 1) {
            perType = Math.max(5, maxRows / types.size());
        }

        if (types.contains('Account')) {
            fetchAccounts(out, uid, likePattern, perType);
        }
        if (types.contains('Opportunity')) {
            fetchOpportunities(out, uid, likePattern, closeThis, closeNext, startThis, endThis, startNext, endNext, perType);
        }
        if (types.contains('Contact')) {
            fetchContacts(out, uid, likePattern, perType);
        }
        if (types.contains('Task')) {
            fetchTasks(out, uid, likePattern, tasksOpen, perType);
        }

        if (out.size() > maxRows) {
            List<Map<String, Object>> trimmed = new List<Map<String, Object>>();
            for (Integer i = 0; i < maxRows; i++) {
                trimmed.add(out[i]);
            }
            return trimmed;
        }
        return out;
    }

    private static Boolean toBoolean(Object o) {
        if (o == null) {
            return false;
        }
        if (o instanceof Boolean) {
            return (Boolean) o;
        }
        String s = String.valueOf(o);
        return 'true'.equalsIgnoreCase(s) || '1'.equals(s);
    }

    private static void fetchAccounts(List<Map<String, Object>> out, Id uid, String likePattern, Integer lim) {
        String soql =
            'SELECT Id, Name, Industry, Type FROM Account WHERE OwnerId = :uid';
        if (String.isNotBlank(likePattern)) {
            soql += ' AND Name LIKE :likePattern';
        }
        soql += ' ORDER BY LastModifiedDate DESC LIMIT :lim';
        List<Account> rows = Database.query(soql);
        for (Account a : rows) {
            String snip = '';
            if (String.isNotBlank(a.Industry)) {
                snip += '업종: ' + a.Industry + ' ';
            }
            if (String.isNotBlank(a.Type)) {
                snip += '유형: ' + a.Type;
            }
            addRecord(out, 'Account', a.Id, a.Name, snip.trim());
        }
    }

    private static void fetchOpportunities(
        List<Map<String, Object>> out,
        Id uid,
        String likePattern,
        Boolean closeThis,
        Boolean closeNext,
        Date startThis,
        Date endThis,
        Date startNext,
        Date endNext,
        Integer lim
    ) {
        String soql =
            'SELECT Id, Name, Amount, StageName, CloseDate, Account.Name FROM Opportunity WHERE OwnerId = :uid';
        if (Boolean.TRUE.equals(closeThis)) {
            soql += ' AND CloseDate >= :startThis AND CloseDate <= :endThis';
        } else if (Boolean.TRUE.equals(closeNext)) {
            soql += ' AND CloseDate >= :startNext AND CloseDate <= :endNext';
        }
        if (String.isNotBlank(likePattern)) {
            soql += ' AND (Name LIKE :likePattern OR Account.Name LIKE :likePattern)';
        }
        soql += ' ORDER BY CloseDate ASC NULLS LAST LIMIT :lim';
        List<Opportunity> rows = Database.query(soql);
        for (Opportunity o : rows) {
            String amt = o.Amount != null ? String.valueOf(o.Amount) : '-';
            String snip = '금액: ' + amt + ' / 단계: ' + (o.StageName != null ? o.StageName : '-') + ' / 마감: ' + String.valueOf(o.CloseDate);
            addRecord(out, 'Opportunity', o.Id, o.Name, snip);
        }
    }

    private static void fetchContacts(List<Map<String, Object>> out, Id uid, String likePattern, Integer lim) {
        String soql =
            'SELECT Id, Name, Email, Account.Name FROM Contact WHERE (OwnerId = :uid OR Account.OwnerId = :uid)';
        if (String.isNotBlank(likePattern)) {
            soql += ' AND (Name LIKE :likePattern OR Account.Name LIKE :likePattern)';
        }
        soql += ' ORDER BY LastModifiedDate DESC LIMIT :lim';
        List<Contact> rows = Database.query(soql);
        for (Contact c : rows) {
            String snip = '이메일: ' + (String.isNotBlank(c.Email) ? c.Email : '-') + ' / Account: ' +
                (c.Account != null ? c.Account.Name : '-');
            addRecord(out, 'Contact', c.Id, c.Name, snip);
        }
    }

    private static void fetchTasks(
        List<Map<String, Object>> out,
        Id uid,
        String likePattern,
        Boolean incompleteOnly,
        Integer lim
    ) {
        String soql =
            'SELECT Id, Subject, Status, ActivityDate, Priority, What.Name FROM Task WHERE OwnerId = :uid';
        if (Boolean.TRUE.equals(incompleteOnly)) {
            soql += ' AND IsClosed = false';
        }
        if (String.isNotBlank(likePattern)) {
            soql += ' AND Subject LIKE :likePattern';
        }
        soql += ' ORDER BY ActivityDate ASC NULLS LAST LIMIT :lim';
        List<Task> rows = Database.query(soql);
        for (Task t : rows) {
            String snip = '상태: ' + (t.Status != null ? t.Status : '-') + ' / 우선순위: ' +
                (t.Priority != null ? t.Priority : '-') + ' / 기한: ' + String.valueOf(t.ActivityDate);
            String title = String.isNotBlank(t.Subject) ? t.Subject : '(제목 없음)';
            addRecord(out, 'Task', t.Id, title, snip);
        }
    }
}
