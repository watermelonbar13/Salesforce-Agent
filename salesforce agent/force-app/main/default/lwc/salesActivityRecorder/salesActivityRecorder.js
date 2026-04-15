import { api, LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import analyzeRecording from '@salesforce/apex/SalesCommService.analyzeRecording';
import saveActivityContent from '@salesforce/apex/SalesCommService.saveActivityContent';
import saveActionItems from '@salesforce/apex/SalesCommService.saveActionItems';

export default class SalesActivityRecorder extends LightningElement {
    @api recordId;
    @track activeTabValue = 'recordTab';

    @track isRecording = false;
    @track isAnalyzing = false;
    @track isSaving = false;
    @track transcriptText = '';
    @track activityContent = '';
    @track actionItems = [];
    @track error;
    @track elapsedSeconds = 0;

    recognition;
    timerId;

    get hasTranscript() {
        return !!(this.transcriptText || '').trim();
    }

    get hasAnalysisResult() {
        return !!(this.activityContent || '').trim() || this.actionItems.length > 0;
    }

    get elapsedDisplay() {
        const mm = String(Math.floor(this.elapsedSeconds / 60)).padStart(2, '0');
        const ss = String(this.elapsedSeconds % 60).padStart(2, '0');
        return `${mm}:${ss}`;
    }

    get selectedActionItems() {
        return this.actionItems.filter((item) => item.selected);
    }

    get isSaveDisabled() {
        return this.isSaving || !this.activityContent || !this.activityContent.trim();
    }

    get isStopDisabled() {
        return !this.isRecording;
    }

    get isAnalyzeDisabled() {
        return this.isAnalyzing || !this.hasTranscript;
    }

    connectedCallback() {
        const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
        if (!SpeechRecognition) {
            this.error = '브라우저가 음성 인식을 지원하지 않습니다. 텍스트 입력 후 분석해 주세요.';
            return;
        }

        this.recognition = new SpeechRecognition();
        this.recognition.lang = 'ko-KR';
        this.recognition.continuous = true;
        this.recognition.interimResults = true;

        this.recognition.onresult = (event) => {
            let nextText = '';
            for (let i = event.resultIndex; i < event.results.length; i += 1) {
                nextText += event.results[i][0].transcript;
            }
            this.transcriptText = `${this.transcriptText}${nextText}`.trim();
        };

        this.recognition.onerror = () => {
            this.isRecording = false;
            this.stopTimer();
            this.error = '음성 인식 중 오류가 발생했습니다. 다시 시도해 주세요.';
        };
    }

    disconnectedCallback() {
        this.stopTimer();
        if (this.recognition && this.isRecording) {
            this.recognition.stop();
        }
    }

    handleTranscriptChange(event) {
        this.transcriptText = event.target.value;
    }

    handleActivityContentChange(event) {
        this.activityContent = event.target.value;
    }

    startRecording() {
        this.error = undefined;
        if (!this.recognition) {
            this.error = '음성 인식 기능을 사용할 수 없습니다.';
            return;
        }
        this.isRecording = true;
        this.elapsedSeconds = 0;
        this.recognition.start();
        this.timerId = window.setInterval(() => {
            this.elapsedSeconds += 1;
        }, 1000);
    }

    async stopRecording() {
        this.isRecording = false;
        this.stopTimer();
        if (this.recognition) {
            this.recognition.stop();
        }
        this.activeTabValue = 'analysisTab';
        await this.handleAnalyze();
    }

    stopTimer() {
        if (this.timerId) {
            window.clearInterval(this.timerId);
            this.timerId = undefined;
        }
    }

    async handleAnalyze() {
        const transcript = (this.transcriptText || '').trim();
        if (!transcript) {
            this.error = '분석할 텍스트를 입력해 주세요.';
            return;
        }
        this.isAnalyzing = true;
        this.error = undefined;

        try {
            const result = await analyzeRecording({ transcriptText: transcript });
            this.activityContent = result.summary || '';
            const rawItems = Array.isArray(result.actionItems) ? result.actionItems : [];
            this.actionItems = rawItems.map((item, index) => ({
                index,
                selected: true,
                subject: item.subject || `후속 조치 ${index + 1}`,
                priority: item.priority || 'Normal',
                dueDate: item.dueDate || '',
                reason: item.reason || ''
            }));
        } catch (e) {
            this.error = e.body?.message || 'AI 분석 중 오류가 발생했습니다.';
        } finally {
            this.isAnalyzing = false;
        }
    }

    handleToggleItem(event) {
        const index = Number(event.target.dataset.index);
        this.actionItems = this.actionItems.map((item) =>
            item.index === index ? { ...item, selected: event.target.checked } : item
        );
    }

    async handleSave() {
        if (this.isSaveDisabled) {
            return;
        }
        if (this.selectedActionItems.length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '확인 필요',
                    message: '저장할 Next Action 후보를 1개 이상 선택해 주세요.',
                    variant: 'warning'
                })
            );
            return;
        }
        this.isSaving = true;
        this.error = undefined;
        try {
            await saveActivityContent({
                activityId: this.recordId,
                content: this.activityContent.trim()
            });

            const actionPayload = this.selectedActionItems.map((item) => ({
                subject: item.subject,
                priority: item.priority,
                dueDate: item.dueDate || null,
                reason: item.reason
            }));
            const saveResult = await saveActionItems({
                actionItemList: actionPayload,
                activityId: this.recordId
            });

            const variant = saveResult.failedCount > 0 ? 'warning' : 'success';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: saveResult.failedCount > 0 ? '부분 저장 성공' : '저장 완료',
                    message: saveResult.message,
                    variant
                })
            );
        } catch (e) {
            this.error = e.body?.message || '저장 중 오류가 발생했습니다.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: '오류',
                    message: this.error,
                    variant: 'error'
                })
            );
        } finally {
            this.isSaving = false;
        }
    }
}
