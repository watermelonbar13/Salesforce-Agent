import { api, LightningElement, track } from 'lwc';
import getPreviousActivities from '@salesforce/apex/SalesCommService.getPreviousActivities';
import getAISalesStrategy from '@salesforce/apex/SalesCommService.getAISalesStrategy';

export default class SalesHistoryAssistant extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track activities = [];
    @track isLoading = false;
    @track isAnalyzing = false;
    @track strategyText = '';
    @track error;

    connectedCallback() {
        this.loadActivities();
    }

    get hasActivities() {
        return Array.isArray(this.activities) && this.activities.length > 0;
    }

    get hasStrategy() {
        return !!(this.strategyText || '').trim();
    }

    async loadActivities() {
        this.isLoading = true;
        this.error = undefined;
        try {
            const params = {
                accountId: this.objectApiName === 'Account' ? this.recordId : null,
                opportunityId: this.objectApiName === 'Opportunity' ? this.recordId : null
            };
            const result = await getPreviousActivities(params);
            this.activities = Array.isArray(result) ? result : [];
        } catch (e) {
            this.error = e.body?.message || '이전 영업활동 조회 중 오류가 발생했습니다.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleAnalyzeStrategy() {
        this.isAnalyzing = true;
        this.error = undefined;
        try {
            this.strategyText = await getAISalesStrategy({ activities: this.activities });
        } catch (e) {
            this.error = e.body?.message || 'AI 전략 분석 중 오류가 발생했습니다.';
        } finally {
            this.isAnalyzing = false;
        }
    }
}
