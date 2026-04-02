# 통화/미팅 로그 정리

미팅 중 음성을 녹음하고, 종료 후 자동으로 미팅 내용을 정리하여
Action Item을 SF Task에 등록하고 미팅 기록을 SF Activity에 저장한다.
다음 미팅 시 이전 이력을 요약하고 영업전략을 조언한다.

## 수행할 일

### 1. 미팅 녹음 및 텍스트 변환
- LWC에서 Web Speech API (SpeechRecognition)로 실시간 음성 → 텍스트 변환
- "녹음 시작" 버튼 클릭 시 마이크 활성화 + 실시간 텍스트 화면에 표시
- "녹음 완료" 버튼 클릭 시 녹음 중지 + AI 분석 자동 시작
- lang: 'ko-KR' 설정 (한국어 인식)
- Lightning Web Security (LWS) 활성화 필요

### 2. AI 분석 (녹음 완료 후 자동 실행)
- 변환된 텍스트를 Claude API로 전달
- 미팅 핵심 내용 5줄 요약 생성
- Action Item 자동 추출 (subject, 담당자, 우선순위, 기한 포함)

### 3. SF 저장
- 미팅 요약 → SF Activity에 [미팅] 접두사로 저장
- Action Item → 체크박스로 선택 후 SF Task 일괄 등록
- Task 우선순위는 AI가 자동 설정 (High/Normal/Low)

### 4. 다음 미팅 시 이전 이력 요약
- 같은 Account / Contact / Opportunity 선택 시 자동 실행
- SF에서 이전 미팅 Activity 이력 조회
- AI가 이전 미팅들을 종합 요약
- 영업전략 조언 (단기/중기/장기) 자동 생성

## 생성할 파일
```
force-app/main/default/
├── lwc/salesCommAssistant/
│   ├── salesCommAssistant.html
│   ├── salesCommAssistant.js
│   ├── salesCommAssistant.css
│   └── salesCommAssistant.js-meta.xml
└── classes/
    ├── SalesCommService.cls
    └── SalesCommService.cls-meta.xml
```

## 출력 화면 (LWC 탭 구성)
- **탭1. 미팅 녹음**
  - 녹음 시작/완료 버튼
  - 실시간 텍스트 변환 내용 표시 영역
  - 녹음 경과 시간 타이머

- **탭2. AI 분석 결과**
  - 미팅 요약 (5줄, 수정 가능 textarea)
  - Action Item 목록 (체크박스 + subject + 우선순위 + 기한)
  - SF 저장 버튼

- **탭3. 이전 미팅 이력**
  - Account/Contact/Opportunity 선택 시 자동 로드
  - 이전 미팅 이력 타임라인 표시
  - AI 종합 요약 + 영업전략 조언

## Web Speech API LWC 구현 핵심
```javascript
// LWS 활성화 필요: Setup → Session Settings → Lightning Web Security 체크
connectedCallback() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    this.recognition = new SpeechRecognition();
    this.recognition.lang = 'ko-KR';        // 한국어
    this.recognition.continuous = true;      // 연속 인식
    this.recognition.interimResults = true;  // 중간 결과 표시

    this.recognition.onresult = (event) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
            transcript += event.results[i][0].transcript;
        }
        this.transcriptText += transcript;  // 실시간 텍스트 누적
    };
}

startRecording() {
    this.isRecording = true;
    this.recognition.start();
}

stopRecording() {
    this.isRecording = false;
    this.recognition.stop();
    this.analyzeTranscript(); // AI 분석 자동 시작
}
```

## 참고 기능
- Salesforce 조회/저장: @.cursor/skills/salesforce/SKILL.md
- AI 분석: @.cursor/skills/llm-analysis/SKILL.md