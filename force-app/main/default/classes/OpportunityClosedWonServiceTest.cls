@isTest
private class OpportunityClosedWonServiceTest {

    @testSetup
    static void setup() {
        insert new Account(Name = 'Test Account');
    }

    @isTest
    static void closedWon_updatesKPIs_andCreatesTask() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'Deal 1', AccountId = acc.Id, Amount = 5000,
            StageName = 'Prospecting', CloseDate = Date.today()
        );
        insert opp;

        Test.startTest();
        opp.StageName = 'Closed Won';
        update opp;
        Test.stopTest();

        Account result = [SELECT Total_Closed_Won_Revenue__c, Closed_Won_Deal_Count__c,
                                 Average_Deal_Size__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(5000, result.Total_Closed_Won_Revenue__c);
        System.assertEquals(1, result.Closed_Won_Deal_Count__c);
        System.assertEquals(5000, result.Average_Deal_Size__c);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :opp.Id]);
    }

    @isTest
    static void closedWon_withoutAmount_isBlocked() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = new Opportunity(
            Name = 'No Amount', AccountId = acc.Id,
            StageName = 'Closed Won', CloseDate = Date.today()
        );

        Test.startTest();
        Database.SaveResult sr = Database.insert(opp, false);
        Test.stopTest();

        System.assertEquals(false, sr.isSuccess());
        System.assert(sr.getErrors()[0].getMessage().contains('Amount must be at least'));
    }

    @isTest
    static void bulkClosedWon_200Records() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(
                Name = 'Bulk ' + i, AccountId = acc.Id, Amount = 100,
                StageName = 'Closed Won', CloseDate = Date.today()
            ));
        }

        Test.startTest();
        insert opps;
        Test.stopTest();

        Account result = [SELECT Total_Closed_Won_Revenue__c, Closed_Won_Deal_Count__c
                          FROM Account WHERE Id = :acc.Id];
        System.assertEquals(20000, result.Total_Closed_Won_Revenue__c);
        System.assertEquals(200, result.Closed_Won_Deal_Count__c);
        System.assertEquals(200, [SELECT COUNT() FROM Task WHERE WhatId IN :opps]);
    }
}