# 공공 데이터 조회 기능

## 개요
나라장터(G2B)와 DART를 통해 발주공고 및 기업 공시 정보를 조회하는 기능

## 사용 API
| API | 용도 | 발급처 |
|-----|------|--------|
| 나라장터 G2B | 공공 입찰공고 | data.go.kr |
| DART | 기업 공시 정보 | dart.fss.or.kr |

## API 키 저장 위치
```
Setup → Custom Settings → AI_Agent_Settings__c
- G2B_API_Key__c
- DART_API_Key__c
```

## Named Credential 설정
```
G2B:  URL = https://apis.data.go.kr  / Name = G2B_API
DART: URL = https://opendart.fss.or.kr / Name = DART_API
```

## 나라장터 발주공고 조회
```apex
public static List<Map<String, Object>> searchBidPublic(String keyword) {
    AI_Agent_Settings__c settings = AI_Agent_Settings__c.getInstance();
    String encodedKeyword = EncodingUtil.urlEncode(keyword, 'UTF-8');
    String apiKey = EncodingUtil.urlEncode(settings.G2B_API_Key__c, 'UTF-8');

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:G2B_API/1230000/BidPublicInfoService04/getBidPblancListInfoServc'
        + '?serviceKey=' + apiKey
        + '&numOfRows=5&pageNo=1&inqryDiv=1&type=json'
        + '&bidNm=' + encodedKeyword);
    req.setMethod('GET');
    req.setTimeout(30000);

    List<Map<String, Object>> results = new List<Map<String, Object>>();
    try {
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Map<String, Object> response = (Map<String, Object>) body.get('response');
            Map<String, Object> bodyData = (Map<String, Object>) response.get('body');
            List<Object> items = (List<Object>) bodyData.get('items');
            if (items != null) {
                for (Object item : items) {
                    Map<String, Object> m = (Map<String, Object>) item;
                    Map<String, Object> result = new Map<String, Object>();
                    result.put('bidNm', m.get('bidNm'));           // 공고명
                    result.put('ntceInsttNm', m.get('ntceInsttNm')); // 공고기관
                    result.put('presmptPrce', m.get('presmptPrce')); // 예산금액
                    result.put('bidClseDt', m.get('bidClseDt'));    // 마감일
                    results.add(result);
                }
            }
        }
    } catch (Exception e) {
        System.debug('G2B 오류: ' + e.getMessage());
    }
    return results;
}
```

## DART 기업 공시 조회
```apex
public static List<Map<String, Object>> getDisclosures(String corpName) {
    AI_Agent_Settings__c settings = AI_Agent_Settings__c.getInstance();
    String apiKey = settings.DART_API_Key__c;
    String encodedName = EncodingUtil.urlEncode(corpName, 'UTF-8');
    String startDate = String.valueOf(Date.today().addMonths(-6)).replace('-', '');

    // 1단계: 기업코드 조회
    HttpRequest req1 = new HttpRequest();
    req1.setEndpoint('callout:DART_API/api/company.json?crtfc_key=' + apiKey + '&corp_name=' + encodedName);
    req1.setMethod('GET');
    req1.setTimeout(30000);

    List<Map<String, Object>> results = new List<Map<String, Object>>();
    try {
        Http http = new Http();
        HttpResponse res1 = http.send(req1);
        if (res1.getStatusCode() == 200) {
            Map<String, Object> body1 = (Map<String, Object>) JSON.deserializeUntyped(res1.getBody());
            List<Object> corps = (List<Object>) body1.get('corp');
            if (corps != null && !corps.isEmpty()) {
                String corpCode = (String) ((Map<String, Object>) corps[0]).get('corp_code');

                // 2단계: 공시 목록 조회
                HttpRequest req2 = new HttpRequest();
                req2.setEndpoint('callout:DART_API/api/list.json?crtfc_key=' + apiKey
                    + '&corp_code=' + corpCode + '&bgn_de=' + startDate
                    + '&sort=date&sort_mth=desc&count=5');
                req2.setMethod('GET');
                req2.setTimeout(30000);
                HttpResponse res2 = http.send(req2);
                if (res2.getStatusCode() == 200) {
                    Map<String, Object> body2 = (Map<String, Object>) JSON.deserializeUntyped(res2.getBody());
                    List<Object> list = (List<Object>) body2.get('list');
                    if (list != null) {
                        for (Object item : list) {
                            Map<String, Object> m = (Map<String, Object>) item;
                            Map<String, Object> result = new Map<String, Object>();
                            result.put('reportNm', m.get('report_nm')); // 보고서명
                            result.put('rceptDt', m.get('rcept_dt'));   // 접수일자
                            result.put('rcpNo', m.get('rcp_no'));       // 접수번호
                            results.add(result);
                        }
                    }
                }
            }
        }
    } catch (Exception e) {
        System.debug('DART 오류: ' + e.getMessage());
    }
    return results;
}
```

## 에러 처리
- API 키 없음: "Custom Settings에 API 키를 설정해주세요." 안내
- 결과 없음: "관련 발주공고를 찾을 수 없습니다." 표시