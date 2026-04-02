# 뉴스 검색 기능

## 개요
기업명으로 최신 뉴스를 검색하여 영업 인사이트를 제공하는 기능

## 사용 API
- DuckDuckGo Instant Answer API (무료, API 키 불필요)

## Named Credential 설정
```
Setup → Security → Named Credentials → New
Label: DuckDuckGo_API
Name: DuckDuckGo_API
URL: https://api.duckduckgo.com
Identity Type: Anonymous
```

## Apex 구현
```apex
public static List<Map<String, Object>> searchNews(String companyName) {
    String encodedQuery = EncodingUtil.urlEncode(companyName + ' 뉴스', 'UTF-8');
    
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:DuckDuckGo_API/?q=' + encodedQuery + '&format=json&no_html=1');
    req.setMethod('GET');
    req.setTimeout(30000);

    List<Map<String, Object>> results = new List<Map<String, Object>>();
    try {
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> topics = (List<Object>) body.get('RelatedTopics');
            Integer count = 0;
            for (Object topic : topics) {
                if (count >= 5) break;
                Map<String, Object> topicMap = (Map<String, Object>) topic;
                if (topicMap.get('Text') != null) {
                    Map<String, Object> result = new Map<String, Object>();
                    result.put('title', (String) topicMap.get('Text'));
                    result.put('url', (String) topicMap.get('FirstURL'));
                    results.add(result);
                    count++;
                }
            }
        }
    } catch (Exception e) {
        System.debug('뉴스 검색 오류: ' + e.getMessage());
    }
    return results;
}
```

## LWC 표시
```html
<template for:each={newsResults} for:item="news">
    <div key={news.url} class="slds-box slds-m-bottom_small">
        <p class="slds-text-heading_small">{news.title}</p>
        <a href={news.url} target="_blank">원문 보기 →</a>
    </div>
</template>
```

## 에러 처리
- 검색 실패: "뉴스를 불러오는 중 오류가 발생했습니다." 표시
- 결과 없음: "관련 뉴스를 찾을 수 없습니다." 표시