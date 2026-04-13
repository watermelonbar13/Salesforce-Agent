import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import askSalesCloud from '@salesforce/apex/ChatbotService.askSalesCloud';

export default class SalesChatbot extends NavigationMixin(LightningElement) {
    @track question = '';
    @track isLoading = false;
    @track error;
    @track answer;
    @track records = [];

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
