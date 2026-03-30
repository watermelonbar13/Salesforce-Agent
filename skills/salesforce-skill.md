# Salesforce Skill

## 개요
Salesforce MCP 서버를 통해 CRM 데이터를 조회하고 조작하는 공통 기능 정의

## 공통 설정
- MCP 서버: `@salesforce/mcp`
- toolsets: `data`
- usernameOrAlias: `ax`
- directory: 현재 프로젝트 경로 사용

## 사용 가능한 툴
- `run_soql_query`: SOQL 쿼리로 데이터 조회
- `get_username`: 현재 org 사용자 확인

## SOQL 작성 규칙
- 항상 필요한 필드만 SELECT (전체 필드 지양)
- LIMIT 반드시 명시
- 관계 데이터는 서브쿼리 활용
- 결과는 3000자 이내로 제한 (토큰 초과 방지)

## 주요 Object 및 필드

### Account (고객사)
```sql
SELECT Id, Name, Industry, Type, AnnualRevenue, NumberOfEmployees,
       BillingCity, Website, Description, OwnerId
FROM Account
```

### Contact (담당자)
```sql
SELECT Id, Name, Title, Email, Phone, AccountId, Account.Name
FROM Contact
```

### Opportunity (사업기회)
```sql
SELECT Id, Name, Amount, StageName, CloseDate, AccountId, Account.Name,
       OwnerId, Owner.Name, Probability, Description
FROM Opportunity
```

### Activity/Task (활동)
```sql
SELECT Id, Subject, Status, Priority, ActivityDate, WhoId, WhatId,
       OwnerId, Owner.Name, Description
FROM Task
```

## 에러 처리
- org 연결 실패 시: "Salesforce 연결에 실패했습니다. org 인증을 확인해주세요." 출력
- 데이터 없을 시: "조회된 데이터가 없습니다." 출력
- 쿼리 오류 시: 쿼리를 수정하여 재시도

## 로그 형식
- 연결 시도
- 성공
- 실패
- 요청 중
- 응답 받음