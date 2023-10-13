public with sharing class AccountController {
    public static List<Account> getAllActiveAccounts() {
      return [SELECT Id, SLA__c, Name, Active__c FROM Account WHERE Active__c = 'Yes' WITH SECURITY_ENFORCED];
    }
    // code changes... 20230928-134903
    // 20230928-155646
    // 20231004-092325
    // 20231004-092403
    // 20231011-133120
    // 20231013-082847
}
  
