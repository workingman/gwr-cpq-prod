// Generated by SaltoExternalIdService
trigger Product2SaltoIdTrigger on Product2 (after insert) {
    new SaltoExternalIdService.Builder().withFieldDeveloperName('ExtId').build().updateSaltoId(Trigger.new);
}