// Generated by SaltoExternalIdService
trigger SBQQDiscountScheduleSaltoIdTrigger on SBQQ__DiscountSchedule__c (after insert) {
    new SaltoExternalIdService.Builder().withFieldDeveloperName('ExtId').build().updateSaltoId(Trigger.new);
}