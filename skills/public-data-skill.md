# Public Data Skill

## 개요
무료 공공 API를 활용해 발주공고, 기업 공시, 입찰 정보 등을 수집하는 공통 기능 정의

## 사용 API 목록

---

### 1. 나라장터 (G2B) - 공공 입찰공고
- **API 키**: 공공데이터포털 (data.go.kr) 에서 무료 발급
- **용도**: 공공기관 입찰공고, 제안요청서(RFP) 조회

```python
import requests

def search_g2b(keyword: str, max_results: int = 5):
    url = "https://apis.data.go.kr/1230000/BidPublicInfoService04/getBidPblancListInfoServc"
    params = {
        "serviceKey": "발급받은_API_키",
        "numOfRows": max_results,
        "pageNo": 1,
        "inqryDiv": 1,
        "type": "json",
        "bidNm": keyword  # 입찰공고명 검색어
    }
    response = requests.get(url, params=params)
    return response.json()
```

---

### 2. 공공데이터포털 - 다양한 공공 발주
- **API 키**: data.go.kr 에서 무료 발급
- **용도**: 각 부처별 발주 정보

---

### 3. DART (금융감독원 전자공시) - 기업 공시 정보
- **API 키**: dart.fss.or.kr 에서 무료 발급
- **용도**: 상장기업 공시, 재무정보, 주요 계약 등

```python
def search_dart(corp_name: str):
    # 1단계: 기업 코드 조회
    url = "https://opendart.fss.or.kr/api/company.json"
    params = {
        "crtfc_key": "발급받은_API_키",
        "corp_name": corp_name
    }
    response = requests.get(url, params=params)
    return response.json()

def get_dart_disclosures(corp_code: str):
    # 2단계: 공시 목록 조회
    url = "https://opendart.fss.or.kr/api/list.json"
    params = {
        "crtfc_key": "발급받은_API_키",
        "corp_code": corp_code,
        "bgn_de": "20250101",  # 조회 시작일
        "sort": "date",
        "sort_mth": "desc"
    }
    response = requests.get(url, params=params)
    return response.json()
```

---

## API 키 발급 방법

| API | 발급처 | 소요시간 |
|-----|--------|---------|
| 나라장터 | data.go.kr 회원가입 후 신청 | 즉시~1일 |
| DART | dart.fss.or.kr 회원가입 후 신청 | 즉시 |

## 공통 규칙
- API 키는 환경변수로 관리 (코드에 직접 입력 금지)
- 결과는 5개 이내로 제한
- 날짜는 최근 3개월 이내 우선
- 에러 시 사용자에게 친절하게 안내

## 출력 형식
```
📋 발주공고 정보
1. **[공고명]** (공고일)
   - 기관: [발주기관]
   - 금액: [예산금액]
   - 마감: [입찰마감일]
   - 링크: URL
```