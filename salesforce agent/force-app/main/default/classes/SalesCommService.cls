public with sharing class SalesCommService {
    private static final Integer RECENT_ACTIVITY_LIMIT = 5;
    private static final Integer ACTION_ITEM_LIMIT = 10;
    private static final Integer INCOMPLETE_TASK_LIMIT = 10;

    @AuraEnabled
    public static String getAISalesAdvice(
        Id contextRecordId,
        String contextObjectApiName,
        String subjectType,
        Id relatedAccountId,
        Id relatedOpportunityId
    ) {
        try {
            if (contextRecordId == null || String.isBlank(contextObjectApiName)) {
                throw new AuraHandledException('컨텍스트 정보가 부족합니다. 레코드를 다시 확인해 주세요.');
            }

            List<String> warnings = new List<String>();
            String resolvedObject = normalizeContextObject(contextObjectApiName);
            Map<String, Id> resolvedContext = resolveContextIds(
                contextRecordId,
                resolvedObject,
                relatedAccountId,
                relatedOpportunityId
            );
            Id accountId = resolvedContext.get('accountId');
            Id opportunityId = resolvedContext.get('opportunityId');

            List<Map<String, Object>> previousActivities = loadPreviousActivitiesForAdvice(accountId, opportunityId);
            if (previousActivities.isEmpty()) {
                warnings.add('이전 활동이 없어 기본 브리핑으로 생성되었습니다.');
            }

            List<Map<String, String>> referenceLinks = fetchReferenceLinks(accountId, opportunityId);
            if (referenceLinks.isEmpty()) {
                warnings.add('외부 참고 링크를 찾지 못해 내부 이력 중심으로 작성했습니다.');
            }

            String mode = '이메일 커뮤니케이션'.equals(subjectType) ? 'emailDraft' : 'briefing';
            if (!isSupportedSubject(subjectType)) {
                warnings.add('기본 브리핑으로 생성되었습니다. Subject를 확인해 주세요.');
                mode = 'briefing';
            }
            if (!isSupportedContext(contextObjectApiName)) {
                warnings.add('지원하지 않는 객체 타입으로 기본 브리핑 모드로 처리했습니다.');
            }

            String emailContent = loadEmailContentIfNeeded(contextRecordId, resolvedObject, mode);
            String llmRaw = LLMService.callClaude(
                buildAdvicePrompt(
                    mode,
                    subjectType,
                    resolvedObject,
                    previousActivities,
                    referenceLinks,
                    emailContent
                )
            );
            Map<String, Object> parsed = parseAdviceResponse(llmRaw, mode, warnings, resolvedObject, accountId, opportunityId);
            return JSON.serialize(parsed);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('getAISalesAdvice 오류: ' + e.getMessage());
            throw new AuraHandledException('AI 브리핑 생성 중 오류가 발생했습니다.');
        }
    }

    @AuraEnabled
    public static Map<String, Object> analyzeRecording(String transcriptText) {
        try {
            if (String.isBlank(transcriptText)) {
                throw new AuraHandledException('분석할 녹음 텍스트를 입력해 주세요.');
            }
            String prompt = buildAnalyzePrompt(transcriptText);
            String raw = LLMService.callClaude(prompt);
            return parseAnalyzeResponse(raw);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('analyzeRecording 오류: ' + e.getMessage());
            throw new AuraHandledException('녹음 분석 중 오류가 발생했습니다.');
        }
    }

    @AuraEnabled
    public static Map<String, Object> getPreMeetingPreparation(Id activityId) {
        try {
            if (activityId == null) {
                throw new AuraHandledException('활동 레코드 정보가 없습니다.');
            }
            Map<String, Id> contextIds = resolveContextIds(activityId, 'SalesActivity__c', null, null);
            Id accountId = contextIds.get('accountId');
            Id opportunityId = contextIds.get('opportunityId');

            List<Map<String, Object>> previousActivities = loadPreviousActivitiesForAdvice(accountId, opportunityId);
            List<Map<String, Object>> incompleteTasks = loadIncompleteTasks(accountId, opportunityId);

            String prompt = buildPreMeetingPrompt(previousActivities, incompleteTasks);
            String raw = LLMService.callClaude(prompt);

            return parsePreMeetingResponse(raw, previousActivities, incompleteTasks);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('getPreMeetingPreparation 오류: ' + e.getMessage());
            throw new AuraHandledException('미팅 전 준비 정보 생성 중 오류가 발생했습니다.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPreviousActivities(Id accountId, Id opportunityId) {
        try {
            return loadPreviousActivitiesForAdvice(accountId, opportunityId);
        } catch (Exception e) {
            System.debug('getPreviousActivities 오류: ' + e.getMessage());
            throw new AuraHandledException('이전 영업활동 조회 중 오류가 발생했습니다.');
        }
    }

    @AuraEnabled
    public static String getAISalesStrategy(List<Object> activities) {
        try {
            List<Object> safeActivities = activities == null ? new List<Object>() : activities;
            String prompt =
                '당신은 B2B 영업 코치입니다. 아래 영업활동 이력을 바탕으로 한국어로 전략을 작성하세요.\n'
                + '- 1) 이력 요약\n- 2) 단기 전략(1주)\n- 3) 중기 전략(1개월)\n- 4) 장기 전략(분기)\n'
                + '- 가능한 실행 액션을 각 구간별 3개 이내로 제시\n'
                + '영업활동 JSON: '
                + JSON.serialize(safeActivities);
            String result = LLMService.callClaude(prompt);
            return String.isBlank(result) ? '전략 생성 결과가 없습니다.' : result;
        } catch (Exception e) {
            System.debug('getAISalesStrategy 오류: ' + e.getMessage());
            throw new AuraHandledException('AI 영업전략 생성 중 오류가 발생했습니다.');
        }
    }

    @AuraEnabled
    public static Map<String, Object> saveActivityContent(Id activityId, String content) {
        try {
            if (activityId == null) {
                throw new AuraHandledException('저장할 활동 레코드를 찾을 수 없습니다.');
            }
            if (String.isBlank(content)) {
                throw new AuraHandledException('영업활동 내용을 입력해 주세요.');
            }

            Schema.SObjectType activityType = Schema.getGlobalDescribe().get('SalesActivity__c');
            if (activityType == null) {
                throw new AuraHandledException('SalesActivity__c 오브젝트가 존재하지 않습니다.');
            }

            SObject row = activityType.newSObject(activityId);
            if (!setIfFieldExists(row, 'ActivityContent__c', content)) {
                throw new AuraHandledException('ActivityContent__c 필드를 찾을 수 없습니다.');
            }
            update row;

            return new Map<String, Object>{
                'success' => true,
                'message' => '영업활동 내용이 저장되었습니다.'
            };
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('saveActivityContent 오류: ' + e.getMessage());
            throw new AuraHandledException('영업활동 저장 중 오류가 발생했습니다.');
        }
    }

    @AuraEnabled
    public static Map<String, Object> saveActionItems(List<Object> actionItemList, Id activityId) {
        try {
            if (activityId == null) {
                throw new AuraHandledException('기준 활동 레코드를 찾을 수 없습니다.');
            }
            if (actionItemList == null || actionItemList.isEmpty()) {
                return new Map<String, Object>{
                    'success' => true,
                    'message' => '저장할 액션 아이템이 없습니다.',
                    'savedCount' => 0,
                    'failedCount' => 0,
                    'errors' => new List<String>()
                };
            }

            Schema.SObjectType itemType = Schema.getGlobalDescribe().get('SalesActionItem__c');
            if (itemType == null) {
                throw new AuraHandledException('SalesActionItem__c 오브젝트가 존재하지 않습니다.');
            }

            List<SObject> toInsert = new List<SObject>();
            for (Integer i = 0; i < actionItemList.size() && i < ACTION_ITEM_LIMIT; i++) {
                Map<String, Object> row;
                try {
                    row = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(actionItemList[i]));
                } catch (Exception ex) {
                    continue;
                }
                SObject item = itemType.newSObject();
                String subject = toStringOrNull(row.get('subject'));
                if (String.isBlank(subject)) {
                    subject = '후속 조치 ' + String.valueOf(i + 1);
                }
                setIfFieldExists(item, 'Subject__c', subject);
                setIfFieldExists(item, 'Priority__c', normalizePriority(toStringOrNull(row.get('priority'))));
                setIfFieldExists(item, 'DueDate__c', parseDateSafely(toStringOrNull(row.get('dueDate'))));
                setIfFieldExists(item, 'Status__c', 'Not Started');
                setIfFieldExists(item, 'Activity__c', activityId);
                setIfFieldExists(item, 'OwnerId', UserInfo.getUserId());
                setIfFieldExists(item, 'Description__c', toStringOrNull(row.get('reason')));
                toInsert.add(item);
            }

            if (toInsert.isEmpty()) {
                return new Map<String, Object>{
                    'success' => true,
                    'message' => '유효한 액션 아이템이 없어 저장하지 않았습니다.',
                    'savedCount' => 0,
                    'failedCount' => 0,
                    'errors' => new List<String>()
                };
            }

            Database.SaveResult[] results = Database.insert(toInsert, false);
            List<String> errors = new List<String>();
            Integer successCount = 0;
            Integer failedCount = 0;
            for (Integer idx = 0; idx < results.size(); idx++) {
                if (results[idx].isSuccess()) {
                    successCount++;
                    continue;
                }
                failedCount++;
                for (Database.Error err : results[idx].getErrors()) {
                    errors.add('항목 ' + (idx + 1) + ': ' + err.getMessage());
                }
            }

            String message =
                failedCount > 0
                    ? '부분 저장 성공: ' + successCount + '건 저장, ' + failedCount + '건 실패'
                    : '액션 아이템이 저장되었습니다.';
            return new Map<String, Object>{
                'success' => failedCount == 0,
                'message' => message,
                'savedCount' => successCount,
                'failedCount' => failedCount,
                'errors' => errors
            };
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            System.debug('saveActionItems 오류: ' + e.getMessage());
            throw new AuraHandledException('액션 아이템 저장 중 오류가 발생했습니다.');
        }
    }

    private static List<Map<String, Object>> loadPreviousActivitiesForAdvice(Id accountId, Id opportunityId) {
        Schema.SObjectType activityType = Schema.getGlobalDescribe().get('SalesActivity__c');
        if (activityType == null) {
            return new List<Map<String, Object>>();
        }

        Map<String, Schema.SObjectField> fieldMap = activityType.getDescribe().fields.getMap();
        List<String> selectFields = new List<String>{ 'Id', 'Name', 'CreatedDate' };
        if (fieldMap.containsKey('Subject__c')) selectFields.add('Subject__c');
        if (fieldMap.containsKey('ActivityDate__c')) selectFields.add('ActivityDate__c');
        if (fieldMap.containsKey('ActivityContent__c')) selectFields.add('ActivityContent__c');
        if (fieldMap.containsKey('RelatedAccount__c')) selectFields.add('RelatedAccount__c');
        if (fieldMap.containsKey('RelatedOpportunity__c')) selectFields.add('RelatedOpportunity__c');

        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM SalesActivity__c';
        List<String> whereParts = new List<String>();
        if (accountId != null && fieldMap.containsKey('RelatedAccount__c')) {
            whereParts.add('RelatedAccount__c = :accountId');
        }
        if (opportunityId != null && fieldMap.containsKey('RelatedOpportunity__c')) {
            whereParts.add('RelatedOpportunity__c = :opportunityId');
        }
        if (!whereParts.isEmpty()) {
            soql += ' WHERE ' + String.join(whereParts, ' OR ');
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT :RECENT_ACTIVITY_LIMIT';

        List<SObject> rows = Database.query(soql);
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (SObject row : rows) {
            Map<String, Object> item = new Map<String, Object>{
                'id' => String.valueOf(row.get('Id')),
                'name' => String.valueOf(row.get('Name')),
                'createdDate' => String.valueOf(row.get('CreatedDate'))
            };
            if (fieldMap.containsKey('Subject__c')) item.put('subject', row.get('Subject__c'));
            if (fieldMap.containsKey('ActivityDate__c')) item.put('activityDate', row.get('ActivityDate__c'));
            if (fieldMap.containsKey('ActivityContent__c')) item.put('activityContent', row.get('ActivityContent__c'));
            if (fieldMap.containsKey('RelatedAccount__c')) item.put('relatedAccountId', row.get('RelatedAccount__c'));
            if (fieldMap.containsKey('RelatedOpportunity__c')) item.put('relatedOpportunityId', row.get('RelatedOpportunity__c'));
            out.add(item);
        }
        return out;
    }

    private static List<Map<String, String>> fetchReferenceLinks(Id accountId, Id opportunityId) {
        List<Map<String, String>> links = new List<Map<String, String>>();
        String keyword = resolveSearchKeyword(accountId, opportunityId);
        if (String.isBlank(keyword)) {
            return links;
        }

        String encoded = EncodingUtil.urlEncode(keyword + ' 산업 뉴스 pain point', 'UTF-8');
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:DuckDuckGo_API/?q=' + encoded + '&format=json&no_html=1&skip_disambig=1');
        req.setMethod('GET');
        req.setTimeout(30000);
        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                return links;
            }
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> topics = (List<Object>) body.get('RelatedTopics');
            if (topics == null) {
                return links;
            }
            for (Object t : topics) {
                if (!(t instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> topicMap = (Map<String, Object>) t;
                addLinkIfValid(links, topicMap);
                if (links.size() >= 5) {
                    break;
                }
                if (topicMap.containsKey('Topics') && topicMap.get('Topics') instanceof List<Object>) {
                    for (Object nested : (List<Object>) topicMap.get('Topics')) {
                        if (!(nested instanceof Map<String, Object>)) {
                            continue;
                        }
                        addLinkIfValid(links, (Map<String, Object>) nested);
                        if (links.size() >= 5) {
                            break;
                        }
                    }
                }
                if (links.size() >= 5) {
                    break;
                }
            }
        } catch (Exception e) {
            System.debug('외부 검색 실패: ' + e.getMessage());
        }
        return links;
    }

    private static void addLinkIfValid(List<Map<String, String>> links, Map<String, Object> raw) {
        String title = toStringOrNull(raw.get('Text'));
        String url = toStringOrNull(raw.get('FirstURL'));
        if (String.isBlank(title) || String.isBlank(url)) {
            return;
        }
        if (!(url.startsWith('http://') || url.startsWith('https://'))) {
            return;
        }
        links.add(new Map<String, String>{ 'title' => title, 'url' => url });
    }

    private static String resolveSearchKeyword(Id accountId, Id opportunityId) {
        try {
            if (opportunityId != null) {
                List<Opportunity> opps = [SELECT Name, Account.Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
                if (!opps.isEmpty()) {
                    Opportunity opp = opps[0];
                    if (opp.Account != null && String.isNotBlank(opp.Account.Name)) {
                        return opp.Account.Name;
                    }
                    return opp.Name;
                }
            }
            if (accountId != null) {
                List<Account> accs = [SELECT Name FROM Account WHERE Id = :accountId LIMIT 1];
                if (!accs.isEmpty()) {
                    return accs[0].Name;
                }
            }
        } catch (Exception e) {
            System.debug('검색 키워드 조회 실패: ' + e.getMessage());
        }
        return null;
    }

    private static String buildAdvicePrompt(
        String mode,
        String subjectType,
        String contextObjectApiName,
        List<Map<String, Object>> previousActivities,
        List<Map<String, String>> referenceLinks,
        String emailContent
    ) {
        return '당신은 한국어 B2B 영업 코치입니다. 반드시 JSON 한 개만 반환하세요.\n'
            + '스키마:\n'
            + '{"mode":"briefing|emailDraft","title":"string","content":"string",'
            + '"recommendedActions":["string"],"referenceLinks":[{"title":"string","url":"string"}],'
            + '"warnings":["string"],"usedContext":{"contextObjectApiName":"Account|Opportunity|SalesActivity__c|Other",'
            + '"accountId":"string|null","opportunityId":"string|null"}}\n'
            + '규칙: content는 한국어, recommendedActions 최대 5건, referenceLinks 최대 5건, '
            + 'subjectType이 이메일 커뮤니케이션이면 mode=emailDraft, 그 외 briefing.\n'
            + 'subjectType=' + subjectType + ', mode=' + mode + ', context=' + contextObjectApiName + '\n'
            + '이전활동 JSON=' + JSON.serialize(previousActivities) + '\n'
            + '외부링크 JSON=' + JSON.serialize(referenceLinks) + '\n'
            + '원문 이메일 내용(없으면 null)=' + (String.isBlank(emailContent) ? 'null' : emailContent);
    }

    private static String buildAnalyzePrompt(String transcriptText) {
        return '다음 녹취를 분석해 JSON 한 개만 반환하세요.\n'
            + '스키마:\n'
            + '{"summary":"string","actionItems":[{"subject":"string","priority":"High|Normal|Low","dueDate":"YYYY-MM-DD","reason":"string"}],'
            + '"nextBestActions":["string"],"warnings":["string"],"confidence":0.0}\n'
            + '규칙:\n'
            + '- summary는 상급자 보고용으로 충분히 상세하게 작성 (고객상황/요구사항/리스크/기회/쟁점/합의사항/후속계획 포함)\n'
            + '- actionItems 최대 10건, dueDate 없으면 null 허용\n'
            + '- nextBestActions는 실행 가능한 후보를 최대 10건까지 제시\n'
            + '녹취:\n'
            + transcriptText;
    }

    private static String buildPreMeetingPrompt(
        List<Map<String, Object>> previousActivities,
        List<Map<String, Object>> incompleteTasks
    ) {
        return '당신은 B2B 영업 미팅 코치입니다. 아래 데이터를 기반으로 미팅 전 준비 정보를 JSON 한 개로만 반환하세요.\n'
            + '스키마:\n'
            + '{"previousMeetingSummary":"string","recommendedTopics":["string"],"warnings":["string"]}\n'
            + '규칙:\n'
            + '- previousMeetingSummary: 이전 미팅 흐름/결정사항/미해결 이슈/담당자 관점 핵심을 한국어로 자세히 작성\n'
            + '- recommendedTopics: 이번 미팅에서 다뤄야 할 대화 주제와 질문을 6개 이내로 제시\n'
            + '- warnings: 없으면 빈 배열\n'
            + '이전활동 JSON=' + JSON.serialize(previousActivities) + '\n'
            + '미완료 Task JSON=' + JSON.serialize(incompleteTasks);
    }

    private static Map<String, Object> parseAdviceResponse(
        String raw,
        String mode,
        List<String> warnings,
        String contextObjectApiName,
        Id accountId,
        Id opportunityId
    ) {
        Map<String, Object> fallback = new Map<String, Object>{
            'mode' => mode,
            'title' => 'AI 브리핑',
            'content' => '이전 활동을 바탕으로 기본 브리핑을 생성했습니다.',
            'recommendedActions' => new List<String>(),
            'referenceLinks' => new List<Map<String, String>>(),
            'warnings' => new List<String>(),
            'usedContext' => new Map<String, Object>{
                'contextObjectApiName' => contextObjectApiName,
                'accountId' => accountId == null ? null : String.valueOf(accountId),
                'opportunityId' => opportunityId == null ? null : String.valueOf(opportunityId)
            }
        };
        List<String> warningBucket = (List<String>) fallback.get('warnings');
        warningBucket.addAll(warnings);

        try {
            Object parsedAny = JSON.deserializeUntyped(stripJsonFence(raw));
            if (!(parsedAny instanceof Map<String, Object>)) {
                warningBucket.add('AI 응답 파싱 실패');
                return fallback;
            }
            Map<String, Object> parsed = (Map<String, Object>) parsedAny;
            fallback.put('mode', parsed.containsKey('mode') ? String.valueOf(parsed.get('mode')) : mode);
            fallback.put('title', safeString(parsed.get('title'), 'AI 브리핑'));
            fallback.put('content', safeString(parsed.get('content'), '기본 브리핑을 생성했습니다.'));
            fallback.put('recommendedActions', limitStringList(parsed.get('recommendedActions'), 5));
            fallback.put('referenceLinks', limitLinkList(parsed.get('referenceLinks'), 5));

            List<String> parsedWarnings = limitStringList(parsed.get('warnings'), 10);
            warningBucket.addAll(parsedWarnings);
            fallback.put('warnings', warningBucket);
            return fallback;
        } catch (Exception e) {
            warningBucket.add('AI 응답 파싱 실패');
            return fallback;
        }
    }

    private static Map<String, Object> parseAnalyzeResponse(String raw) {
        Map<String, Object> fallback = new Map<String, Object>{
            'summary' => '',
            'actionItems' => new List<Object>(),
            'nextBestActions' => new List<String>(),
            'warnings' => new List<String>{ 'AI 응답 파싱 실패' },
            'confidence' => 0.0
        };
        try {
            Object parsedAny = JSON.deserializeUntyped(stripJsonFence(raw));
            if (!(parsedAny instanceof Map<String, Object>)) {
                return fallback;
            }
            Map<String, Object> parsed = (Map<String, Object>) parsedAny;
            Map<String, Object> out = new Map<String, Object>{
                'summary' => safeString(parsed.get('summary'), ''),
                'actionItems' => sanitizeActionItems(parsed.get('actionItems')),
                'nextBestActions' => limitStringList(parsed.get('nextBestActions'), 10),
                'warnings' => limitStringList(parsed.get('warnings'), 10),
                'confidence' => normalizeConfidence(parsed.get('confidence'))
            };
            return out;
        } catch (Exception e) {
            return fallback;
        }
    }

    private static Map<String, Object> parsePreMeetingResponse(
        String raw,
        List<Map<String, Object>> previousActivities,
        List<Map<String, Object>> incompleteTasks
    ) {
        Map<String, Object> fallback = new Map<String, Object>{
            'previousMeetingSummary' => buildFallbackPreviousSummary(previousActivities),
            'incompleteTasks' => incompleteTasks,
            'recommendedTopics' => buildFallbackTopics(previousActivities, incompleteTasks),
            'warnings' => new List<String>()
        };

        try {
            Object parsedAny = JSON.deserializeUntyped(stripJsonFence(raw));
            if (!(parsedAny instanceof Map<String, Object>)) {
                return fallback;
            }
            Map<String, Object> parsed = (Map<String, Object>) parsedAny;
            fallback.put(
                'previousMeetingSummary',
                safeString(parsed.get('previousMeetingSummary'), (String) fallback.get('previousMeetingSummary'))
            );
            fallback.put('recommendedTopics', limitStringList(parsed.get('recommendedTopics'), 6));
            fallback.put('warnings', limitStringList(parsed.get('warnings'), 10));
            return fallback;
        } catch (Exception e) {
            return fallback;
        }
    }

    private static String buildFallbackPreviousSummary(List<Map<String, Object>> previousActivities) {
        if (previousActivities == null || previousActivities.isEmpty()) {
            return '이전 미팅 이력이 없어 이번 미팅에서 고객 현황 파악 질문을 우선 진행해 주세요.';
        }
        List<String> lines = new List<String>();
        Integer count = 0;
        for (Map<String, Object> item : previousActivities) {
            if (count >= 3) {
                break;
            }
            String subject = safeString(item.get('subject'), '영업활동');
            String content = safeString(item.get('activityContent'), '상세 내용 없음');
            lines.add('- ' + subject + ': ' + content);
            count++;
        }
        return '최근 미팅 흐름 요약\n' + String.join(lines, '\n');
    }

    private static List<String> buildFallbackTopics(
        List<Map<String, Object>> previousActivities,
        List<Map<String, Object>> incompleteTasks
    ) {
        List<String> topics = new List<String>{
            '지난 미팅에서 합의한 일정의 진행률을 확인해 주세요.',
            '고객이 최근 가장 우선순위로 보는 과제를 질문해 주세요.',
            '도입 시 기술/예산/보안 관점의 의사결정 기준을 확인해 주세요.'
        };
        if (incompleteTasks != null && !incompleteTasks.isEmpty()) {
            topics.add('미완료 Task의 지연 사유와 해결 계획을 확인해 주세요.');
        }
        if (previousActivities == null || previousActivities.isEmpty()) {
            topics.add('현재 운영 환경과 Pain Point를 구조적으로 파악해 주세요.');
        }
        return topics;
    }

    private static List<Map<String, Object>> loadIncompleteTasks(Id accountId, Id opportunityId) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        if (accountId == null && opportunityId == null) {
            return out;
        }

        Schema.SObjectType taskType = Schema.getGlobalDescribe().get('SalesActionItem__c');
        if (taskType == null) {
            return out;
        }
        Map<String, Schema.SObjectField> taskFields = taskType.getDescribe().fields.getMap();
        if (!taskFields.containsKey('Activity__c')) {
            return out;
        }

        List<String> selectFields = new List<String>{ 'Id', 'Activity__c' };
        if (taskFields.containsKey('Subject__c')) selectFields.add('Subject__c');
        if (taskFields.containsKey('Priority__c')) selectFields.add('Priority__c');
        if (taskFields.containsKey('DueDate__c')) selectFields.add('DueDate__c');
        if (taskFields.containsKey('Status__c')) selectFields.add('Status__c');
        selectFields.add('Activity__r.RelatedAccount__c');
        selectFields.add('Activity__r.RelatedOpportunity__c');

        String soql = 'SELECT ' + String.join(selectFields, ',') + ' FROM SalesActionItem__c';
        List<String> whereParts = new List<String>();
        if (taskFields.containsKey('Status__c')) {
            whereParts.add('Status__c != \'Completed\'');
            whereParts.add('Status__c != \'Cancelled\'');
        }
        List<String> relationParts = new List<String>();
        if (accountId != null) {
            relationParts.add('Activity__r.RelatedAccount__c = :accountId');
        }
        if (opportunityId != null) {
            relationParts.add('Activity__r.RelatedOpportunity__c = :opportunityId');
        }
        if (!relationParts.isEmpty()) {
            whereParts.add('(' + String.join(relationParts, ' OR ') + ')');
        }
        if (!whereParts.isEmpty()) {
            soql += ' WHERE ' + String.join(whereParts, ' AND ');
        }
        soql += ' ORDER BY LastModifiedDate DESC LIMIT :INCOMPLETE_TASK_LIMIT';

        try {
            List<SObject> rows = Database.query(soql);
            Integer index = 0;
            for (SObject row : rows) {
                out.add(
                    new Map<String, Object>{
                        'index' => index,
                        'subject' => toStringOrNull(row.get('Subject__c')),
                        'priority' => normalizePriority(toStringOrNull(row.get('Priority__c'))),
                        'dueDate' => row.get('DueDate__c') == null ? null : String.valueOf(row.get('DueDate__c'))
                    }
                );
                index++;
            }
        } catch (Exception e) {
            System.debug('미완료 Task 조회 실패: ' + e.getMessage());
        }
        return out;
    }

    private static List<Map<String, Object>> sanitizeActionItems(Object rawItems) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        if (!(rawItems instanceof List<Object>)) {
            return out;
        }
        for (Object row : (List<Object>) rawItems) {
            if (!(row instanceof Map<String, Object>)) {
                continue;
            }
            if (out.size() >= ACTION_ITEM_LIMIT) {
                break;
            }
            Map<String, Object> item = (Map<String, Object>) row;
            out.add(
                new Map<String, Object>{
                    'subject' => safeString(item.get('subject'), ''),
                    'priority' => normalizePriority(safeString(item.get('priority'), 'Normal')),
                    'dueDate' => toStringOrNull(item.get('dueDate')),
                    'reason' => safeString(item.get('reason'), '')
                }
            );
        }
        return out;
    }

    private static Decimal normalizeConfidence(Object raw) {
        if (raw == null) {
            return 0.0;
        }
        try {
            Decimal d = raw instanceof Decimal ? (Decimal) raw : Decimal.valueOf(String.valueOf(raw));
            if (d < 0) return 0.0;
            if (d > 1) return 1.0;
            return d;
        } catch (Exception e) {
            return 0.0;
        }
    }

    private static String stripJsonFence(String raw) {
        if (String.isBlank(raw)) {
            return '{}';
        }
        String trimmed = raw.trim();
        Integer start = trimmed.indexOf('{');
        Integer endIdx = trimmed.lastIndexOf('}');
        if (start >= 0 && endIdx > start) {
            return trimmed.substring(start, endIdx + 1);
        }
        return trimmed;
    }

    private static List<String> limitStringList(Object raw, Integer maxSize) {
        List<String> out = new List<String>();
        if (!(raw instanceof List<Object>)) {
            return out;
        }
        for (Object item : (List<Object>) raw) {
            if (out.size() >= maxSize) {
                break;
            }
            String text = toStringOrNull(item);
            if (String.isNotBlank(text)) {
                out.add(text);
            }
        }
        return out;
    }

    private static List<Map<String, String>> limitLinkList(Object raw, Integer maxSize) {
        List<Map<String, String>> out = new List<Map<String, String>>();
        if (!(raw instanceof List<Object>)) {
            return out;
        }
        for (Object item : (List<Object>) raw) {
            if (out.size() >= maxSize) {
                break;
            }
            if (!(item instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> row = (Map<String, Object>) item;
            String title = toStringOrNull(row.get('title'));
            String url = toStringOrNull(row.get('url'));
            if (String.isBlank(title) || String.isBlank(url)) {
                continue;
            }
            if (!(url.startsWith('http://') || url.startsWith('https://'))) {
                continue;
            }
            out.add(new Map<String, String>{ 'title' => title, 'url' => url });
        }
        return out;
    }

    private static Boolean setIfFieldExists(SObject row, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> fieldMap = row.getSObjectType().getDescribe().fields.getMap();
        if (!fieldMap.containsKey(fieldApiName)) {
            return false;
        }
        row.put(fieldApiName, value);
        return true;
    }

    private static Date parseDateSafely(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        try {
            return Date.valueOf(raw);
        } catch (Exception e) {
            return null;
        }
    }

    private static String safeString(Object raw, String fallback) {
        String value = toStringOrNull(raw);
        return String.isBlank(value) ? fallback : value;
    }

    private static String toStringOrNull(Object raw) {
        if (raw == null) {
            return null;
        }
        String text = String.valueOf(raw);
        return String.isBlank(text) ? null : text;
    }

    private static String normalizePriority(String raw) {
        if (String.isBlank(raw)) {
            return 'Normal';
        }
        String upper = raw.trim().toLowerCase();
        if (upper == 'high') {
            return 'High';
        }
        if (upper == 'low') {
            return 'Low';
        }
        return 'Normal';
    }

    private static String normalizeContextObject(String contextObjectApiName) {
        if (contextObjectApiName == 'Account') return 'Account';
        if (contextObjectApiName == 'Opportunity') return 'Opportunity';
        if (contextObjectApiName == 'SalesActivity__c') return 'SalesActivity__c';
        return 'Other';
    }

    private static Boolean isSupportedContext(String contextObjectApiName) {
        return contextObjectApiName == 'Account'
            || contextObjectApiName == 'Opportunity'
            || contextObjectApiName == 'SalesActivity__c';
    }

    private static Boolean isSupportedSubject(String subjectType) {
        return subjectType == '고객 미팅 진행'
            || subjectType == '전화 통화'
            || subjectType == '이메일 커뮤니케이션';
    }

    private static Map<String, Id> resolveContextIds(
        Id contextRecordId,
        String contextObjectApiName,
        Id relatedAccountId,
        Id relatedOpportunityId
    ) {
        Id accountId = relatedAccountId;
        Id opportunityId = relatedOpportunityId;

        try {
            if (accountId == null && contextObjectApiName == 'Account') {
                accountId = contextRecordId;
            }
            if (opportunityId == null && contextObjectApiName == 'Opportunity') {
                opportunityId = contextRecordId;
            }

            if (contextObjectApiName == 'SalesActivity__c') {
                Schema.SObjectType activityType = Schema.getGlobalDescribe().get('SalesActivity__c');
                if (activityType != null) {
                    Map<String, Schema.SObjectField> fieldMap = activityType.getDescribe().fields.getMap();
                    List<String> fields = new List<String>{ 'Id' };
                    if (fieldMap.containsKey('RelatedAccount__c')) fields.add('RelatedAccount__c');
                    if (fieldMap.containsKey('RelatedOpportunity__c')) fields.add('RelatedOpportunity__c');
                    String soql = 'SELECT ' + String.join(fields, ',') + ' FROM SalesActivity__c WHERE Id = :contextRecordId LIMIT 1';
                    List<SObject> rows = Database.query(soql);
                    if (!rows.isEmpty()) {
                        SObject row = rows[0];
                        if (accountId == null && fieldMap.containsKey('RelatedAccount__c')) {
                            accountId = (Id) row.get('RelatedAccount__c');
                        }
                        if (opportunityId == null && fieldMap.containsKey('RelatedOpportunity__c')) {
                            opportunityId = (Id) row.get('RelatedOpportunity__c');
                        }
                    }
                }
            }

            if (accountId == null && opportunityId != null) {
                List<Opportunity> opps = [SELECT AccountId FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
                if (!opps.isEmpty()) {
                    accountId = opps[0].AccountId;
                }
            }
        } catch (Exception e) {
            System.debug('컨텍스트 해석 실패: ' + e.getMessage());
        }

        return new Map<String, Id>{
            'accountId' => accountId,
            'opportunityId' => opportunityId
        };
    }

    private static String loadEmailContentIfNeeded(Id contextRecordId, String contextObjectApiName, String mode) {
        if (mode != 'emailDraft' || contextObjectApiName != 'SalesActivity__c') {
            return null;
        }
        try {
            Schema.SObjectType activityType = Schema.getGlobalDescribe().get('SalesActivity__c');
            if (activityType == null) {
                return null;
            }
            Map<String, Schema.SObjectField> fieldMap = activityType.getDescribe().fields.getMap();
            if (!fieldMap.containsKey('EmailContent__c')) {
                return null;
            }
            List<SObject> rows = Database.query(
                'SELECT EmailContent__c FROM SalesActivity__c WHERE Id = :contextRecordId LIMIT 1'
            );
            if (rows.isEmpty()) {
                return null;
            }
            return toStringOrNull(rows[0].get('EmailContent__c'));
        } catch (Exception e) {
            System.debug('EmailContent__c 조회 실패: ' + e.getMessage());
            return null;
        }
    }
}
