public with sharing class AccountController {
    public static List<Account> getAllActiveAccounts() {
      return [SELECT Id, SLA__c, Name, Active__c FROM Account WHERE Active__c = 'Yes' WITH SECURITY_ENFORCED];

      // 20240130-070838
      // 20240130-071629

    }
}