import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import askSalesCloud from '@salesforce/apex/ChatbotService.askSalesCloud';

export default class SalesChatbot extends NavigationMixin(LightningElement) {
    @track question = '';
    @track isLoading = false;
    @track error;
    @track answer;
    @track records = [];
    @track isAnswerExpanded = true;
    @track isRecordsExpanded = true;

    get hasResults() {
        const hasAnswer = !!(this.answer && String(this.answer).trim());
        const hasRecords = Array.isArray(this.records) && this.records.length > 0;
        return this.isLoading || hasAnswer || hasRecords || !!this.error;
    }

    handleQuestionChange(event) {
        this.question = event.target.value;
    }

    async handleSubmit() {
        const q = (this.question || '').trim();
        if (!q) {
            this.error = '질문을 입력해 주세요.';
            return;
        }
        this.isLoading = true;
        this.error = undefined;
        this.answer = undefined;
        this.records = [];
        this.isAnswerExpanded = true;
        this.isRecordsExpanded = true;

        try {
            const result = await askSalesCloud({ question: q });
            this.answer = result.answer;
            this.records = Array.isArray(result.records) ? result.records : [];
        } catch (e) {
            this.error = e.body && e.body.message ? e.body.message : '오류가 발생했습니다.';
        } finally {
            this.isLoading = false;
        }
    }

    get answerToggleLabel() {
        return this.isAnswerExpanded ? '답변 접기' : '답변 펼치기';
    }

    get answerToggleIcon() {
        return this.isAnswerExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get recordsToggleLabel() {
        return this.isRecordsExpanded ? '관련 레코드 접기' : '관련 레코드 펼치기';
    }

    get recordsToggleIcon() {
        return this.isRecordsExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    toggleAnswerSection() {
        this.isAnswerExpanded = !this.isAnswerExpanded;
    }

    toggleRecordsSection() {
        this.isRecordsExpanded = !this.isRecordsExpanded;
    }

    handleOpenRecord(event) {
        const objectApiName = event.currentTarget.dataset.object;
        const recordId = event.currentTarget.dataset.id;
        if (!objectApiName || !recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId,
                objectApiName,
                actionName: 'view'
            }
        });
    }
}
