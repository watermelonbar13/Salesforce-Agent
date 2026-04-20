import { api, LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import analyzeRecording from '@salesforce/apex/SalesCommService.analyzeRecording';
import getPreMeetingPreparation from '@salesforce/apex/SalesCommService.getPreMeetingPreparation';
import saveActivityContent from '@salesforce/apex/SalesCommService.saveActivityContent';
import saveActionItems from '@salesforce/apex/SalesCommService.saveActionItems';

export default class SalesActivityRecorder extends LightningElement {
    @api recordId;
    @track activeTabValue = 'activityTab';
    @track activityInformation = '';
    @track activityMemo = '';

    @track isRecording = false;
    @track isPreparing = false;
    @track isAnalyzing = false;
    @track cancelRequested = false;
    @track isSaving = false;
    @track transcriptText = '';
    @track interimTranscript = '';
    @track activityContent = '';
    @track nextBestActions = [];
    @track actionItems = [];
    @track previousMeetingSummary = '';
    @track incompleteTasks = [];
    @track recommendedTopics = [];
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

    get hasPreMeetingData() {
        return !!(this.previousMeetingSummary || '').trim() || this.incompleteTasks.length > 0 || this.recommendedTopics.length > 0;
    }

    get priorityOptions() {
        return [
            { label: '높음', value: 'High' },
            { label: '보통', value: 'Normal' },
            { label: '낮음', value: 'Low' }
        ];
    }

    get nextBestActionRows() {
        return this.nextBestActions.map((text, index) => ({ index, text }));
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

    get isAnalyzeDisabled() {
        return this.isAnalyzing || this.cancelRequested || !this.hasTranscript;
    }

    get isCancelDisabled() {
        return !this.isAnalyzing;
    }

    get recordIconName() {
        return this.isRecording ? 'utility:stop' : 'utility:record';
    }

    get recordIconVariant() {
        return this.isRecording ? 'destructive' : 'brand';
    }

    connectedCallback() {
        this.loadPreMeetingPreparation();
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
            let finalText = '';
            let interimText = '';
            for (let i = event.resultIndex; i < event.results.length; i += 1) {
                const unit = (event.results[i][0].transcript || '').trim();
                if (!unit) {
                    continue;
                }
                if (event.results[i].isFinal) {
                    finalText += ` ${unit}`;
                } else {
                    interimText += ` ${unit}`;
                }
            }
            this.interimTranscript = interimText.trim();
            if (finalText.trim()) {
                this.transcriptText = this.mergeTranscript(this.transcriptText, finalText.trim());
            }
        };

        this.recognition.onerror = () => {
            this.isRecording = false;
            this.stopTimer();
            this.interimTranscript = '';
            this.error = '음성 인식 중 오류가 발생했습니다. 다시 시도해 주세요.';
        };

        this.recognition.onend = () => {
            if (this.isRecording) {
                try {
                    this.recognition.start();
                } catch (e) {
                    this.isRecording = false;
                    this.stopTimer();
                    this.error = '음성 인식이 중단되었습니다. 다시 시도해 주세요.';
                }
            }
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

    handleActivityInformationChange(event) {
        this.activityInformation = event.target.value;
    }

    handleActivityMemoChange(event) {
        this.activityMemo = event.target.value;
    }

    handleActivityContentChange(event) {
        this.activityContent = event.target.value;
    }

    handleMicClick() {
        if (this.isRecording) {
            this.stopRecording();
            return;
        }
        this.startRecording();
    }

    startRecording() {
        this.error = undefined;
        if (!this.recognition) {
            this.error = '음성 인식 기능을 사용할 수 없습니다.';
            return;
        }
        this.isRecording = true;
        this.elapsedSeconds = 0;
        this.interimTranscript = '';
        this.recognition.start();
        this.timerId = window.setInterval(() => {
            this.elapsedSeconds += 1;
        }, 1000);
    }

    stopRecording() {
        this.isRecording = false;
        this.stopTimer();
        if (this.recognition) {
            this.recognition.stop();
        }
        this.interimTranscript = '';
    }

    stopTimer() {
        if (this.timerId) {
            window.clearInterval(this.timerId);
            this.timerId = undefined;
        }
    }

    async loadPreMeetingPreparation() {
        this.isPreparing = true;
        this.error = undefined;
        try {
            const result = await getPreMeetingPreparation({ activityId: this.recordId });
            this.previousMeetingSummary = result.previousMeetingSummary || '';
            const topics = Array.isArray(result.recommendedTopics) ? result.recommendedTopics : [];
            this.recommendedTopics = topics.map((text, index) => ({ index, text }));
            const tasks = Array.isArray(result.incompleteTasks) ? result.incompleteTasks : [];
            this.incompleteTasks = tasks.map((task, index) => ({
                index,
                subject: task.subject || `미완료 Task ${index + 1}`,
                priority: task.priority || 'Normal',
                dueDate: task.dueDate || '-'
            }));
        } catch (e) {
            this.error = e.body?.message || '미팅 전 준비 정보를 불러오는 중 오류가 발생했습니다.';
        } finally {
            this.isPreparing = false;
        }
    }

    async handleAnalyze() {
        const transcript = (this.transcriptText || '').trim();
        if (!transcript) {
            this.error = '분석할 텍스트를 입력해 주세요.';
            return;
        }
        this.isAnalyzing = true;
        this.cancelRequested = false;
        this.error = undefined;
        this.activeTabValue = 'analysisTab';

        try {
            const composedTranscript = this.composeTranscriptForAnalysis(transcript);
            const result = await analyzeRecording({ transcriptText: composedTranscript });
            if (this.cancelRequested) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: '취소됨',
                        message: 'AI 분석이 취소되었습니다.',
                        variant: 'info'
                    })
                );
                return;
            }
            this.activityContent = result.summary || '';
            this.nextBestActions = Array.isArray(result.nextBestActions) ? result.nextBestActions : [];
            const rawItems = Array.isArray(result.actionItems) ? result.actionItems : [];
            let mappedItems = rawItems.map((item, index) => ({
                index,
                selected: true,
                subject: item.subject || `후속 조치 ${index + 1}`,
                priority: item.priority || 'Normal',
                dueDate: item.dueDate || '',
                reason: item.reason || ''
            }));
            if (this.nextBestActions.length > 0) {
                const additional = this.nextBestActions.map((text, idx) => ({
                    index: mappedItems.length + idx,
                    selected: true,
                    subject: text,
                    priority: 'Normal',
                    dueDate: '',
                    reason: 'AI가 제안한 Next Best Action 후보'
                }));
                mappedItems = [...mappedItems, ...additional];
            }
            this.actionItems = this.dedupeActionItems(mappedItems);
        } catch (e) {
            this.error = e.body?.message || 'AI 분석 중 오류가 발생했습니다.';
        } finally {
            this.isAnalyzing = false;
            this.cancelRequested = false;
        }
    }

    handleCancelAnalysis() {
        this.cancelRequested = true;
        this.isAnalyzing = false;
        this.activeTabValue = 'postMeetingTab';
    }

    handleToggleItem(event) {
        const index = Number(event.target.dataset.index);
        this.actionItems = this.actionItems.map((item) =>
            item.index === index ? { ...item, selected: event.target.checked } : item
        );
    }

    handleActionFieldChange(event) {
        const index = Number(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value;
        this.actionItems = this.actionItems.map((item) =>
            item.index === index ? { ...item, [field]: value } : item
        );
    }

    handleAddActionItem() {
        const nextIndex = this.actionItems.length;
        this.actionItems = [
            ...this.actionItems,
            {
                index: nextIndex,
                selected: true,
                subject: '직접 입력한 Next Action',
                priority: 'Normal',
                dueDate: '',
                reason: '사용자 직접 추가'
            }
        ];
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
                reason: this.buildActionReason(item)
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

    composeTranscriptForAnalysis(transcript) {
        const infoBlock = (this.activityInformation || '').trim();
        const memoBlock = (this.activityMemo || '').trim();
        let output = transcript;
        if (infoBlock) {
            output = `[영업활동 상세 정보]\n${infoBlock}\n\n[회의 대화 녹취]\n${output}`;
        }
        if (memoBlock) {
            output += `\n\n[추가 메모]\n${memoBlock}`;
        }
        return output;
    }

    buildActionReason(item) {
        const base = item.reason || '';
        if (!this.nextBestActions.length) {
            return base;
        }
        return `${base}\n추천 Next Best Action 후보: ${this.nextBestActions.join(', ')}`.trim();
    }

    dedupeActionItems(items) {
        const seen = new Set();
        const deduped = [];
        items.forEach((item) => {
            const normalized = this.normalizeActionSubject(item.subject);
            if (!normalized) {
                deduped.push(item);
                return;
            }
            if (seen.has(normalized)) {
                return;
            }
            seen.add(normalized);
            deduped.push(item);
        });
        return deduped.map((item, index) => ({ ...item, index }));
    }

    normalizeActionSubject(subject) {
        return (subject || '')
            .toLowerCase()
            .replace(/\s+/g, '')
            .replace(/[^a-z0-9가-힣]/g, '');
    }

    mergeTranscript(previous, incoming) {
        const prev = (previous || '').trim();
        const next = (incoming || '').trim();
        if (!prev) {
            return next;
        }
        if (!next) {
            return prev;
        }
        if (prev.endsWith(next)) {
            return prev;
        }
        const maxOverlap = Math.min(prev.length, next.length, 30);
        for (let size = maxOverlap; size > 0; size -= 1) {
            if (prev.slice(-size) === next.slice(0, size)) {
                return `${prev} ${next.slice(size)}`.trim();
            }
        }
        return `${prev} ${next}`.trim();
    }
}
