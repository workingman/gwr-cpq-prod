// Generated by SaltoExternalIdService
trigger SBQQProductRuleSaltoIdTrigger on SBQQ__ProductRule__c (after insert) {
    new SaltoExternalIdService.Builder().withFieldDeveloperName('ExtId').build().updateSaltoId(Trigger.new);
}