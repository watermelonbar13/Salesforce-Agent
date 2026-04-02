# Salesforce 기능

## 개요
Salesforce CRM 데이터를 조회하고 저장하는 기능 모음

## 주요 기능 목록
1. 영업대표별 담당 Account 목록 조회
2. Account 상세 정보 조회 (Contact, Opportunity, Activity 포함)
3. Task/Activity 생성 및 저장
4. Opportunity 생성 및 업데이트

## 영업대표별 Account 목록 조회
```apex
List<Account> accounts = [
    SELECT Id, Name, Industry, Type,
           OwnerId, Owner.Name, LastActivityDate,
           (SELECT Id, Name, StageName, Amount
            FROM Opportunities WHERE IsClosed = false
            ORDER BY CreatedDate DESC LIMIT 3)
    FROM Account
    WHERE OwnerId = :UserInfo.getUserId()
    ORDER BY LastModifiedDate DESC
    LIMIT 50
];
```

## Account 상세 조회
```apex
Account acc = [
    SELECT Id, Name, Industry, Type, AnnualRevenue, NumberOfEmployees,
           BillingCity, Website, Description, Owner.Name, LastActivityDate,
           (SELECT Id, Name, StageName, Amount, CloseDate, Probability, NextStep
            FROM Opportunities WHERE IsClosed = false
            ORDER BY CreatedDate DESC LIMIT 5),
           (SELECT Id, Name, Title, Email, Phone
            FROM Contacts ORDER BY CreatedDate DESC LIMIT 5),
           (SELECT Id, Subject, Description, ActivityDate
            FROM ActivityHistories ORDER BY ActivityDate DESC LIMIT 10)
    FROM Account
    WHERE Id = :accountId
];
```

## Task 생성
```apex
Task t = new Task(
    Subject = subject,           // 제목
    Description = description,   // 내용
    ActivityDate = dueDate,      // 기한
    WhatId = accountId,          // Account 연결
    OwnerId = UserInfo.getUserId(),
    Status = 'Not Started',      // Not Started / In Progress / Completed
    Priority = priority          // High / Normal / Low
);
insert t;
```

## Opportunity 생성
```apex
Opportunity opp = new Opportunity(
    Name = name,
    AccountId = accountId,
    Amount = amount,
    CloseDate = closeDate,
    StageName = 'Prospecting',
    Description = description,
    OwnerId = UserInfo.getUserId()
);
insert opp;
```

## 미팅/통화 로그 구분
- Subject에 접두사로 구분: `[미팅]`, `[통화]`
- Status: `Completed` (완료된 활동)

## 에러 처리
```apex
try {
    // 로직
} catch (Exception e) {
    System.debug('에러: ' + e.getMessage());
    throw new AuraHandledException('데이터 처리 중 오류가 발생했습니다: ' + e.getMessage());
}
```