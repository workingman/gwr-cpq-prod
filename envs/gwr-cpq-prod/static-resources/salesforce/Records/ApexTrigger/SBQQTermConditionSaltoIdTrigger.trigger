// Generated by SaltoExternalIdService
trigger SBQQTermConditionSaltoIdTrigger on SBQQ__TermCondition__c (after insert) {
    new SaltoExternalIdService.Builder().withFieldDeveloperName('ExtId').build().updateSaltoId(Trigger.new);
}