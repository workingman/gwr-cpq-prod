public with sharing class AccountController {
    public static List<Account> getAllActiveAccounts() {
      return [SELECT Id, SLA__c, Name, Active__c FROM Account WHERE Active__c = 'Yes' WITH SECURITY_ENFORCED];
    }
    // more code added....
    // 20230922-124143
    // 20230922-125158 B1C898EF-1481-46DA-A8BE-E44606DF7B60
    // 20230922-131442

    /*
    even more code changes
    */
}
  