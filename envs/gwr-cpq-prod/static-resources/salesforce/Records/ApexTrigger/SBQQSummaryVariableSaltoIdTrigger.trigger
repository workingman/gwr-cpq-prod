// Generated by SaltoExternalIdService
trigger SBQQSummaryVariableSaltoIdTrigger on SBQQ__SummaryVariable__c (after insert) {
    new SaltoExternalIdService.Builder().withFieldDeveloperName('ExtId').build().updateSaltoId(Trigger.new);
}