public with sharing class LeftClass {

    public LeftClass() {

        LeftAClass leftA = new LeftAClass();
        LeftBClass leftB = new LeftBClass();
        List<Account> slas = [SELECT SLA__c FROM Account];

    }
}