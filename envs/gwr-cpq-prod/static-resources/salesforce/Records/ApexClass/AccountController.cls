public with sharing class AccountController {
    public static List<Account> getAllActiveAccounts() {
      return [SELECT Id, SLA__c, Name, Active__c FROM Account WHERE Active__c = 'Yes' WITH SECURITY_ENFORCED];

      // 20240130-070838
      // 20240130-071629

    }
    // 20240405-085105
    // 20240405-085907



    // 2D39DCE5-D1E1-46F4-AE9E-AB13A331DA02
    // 20240703-162344
}