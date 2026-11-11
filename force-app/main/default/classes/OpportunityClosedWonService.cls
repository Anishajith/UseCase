public with sharing class OpportunityClosedWonService {

    public static final String CLOSED_WON_STAGE = 'Closed Won';
    public static final Decimal MIN_REVENUE = 1;      // minimum Amount to accept a Closed Won deal
    public static final Integer FOLLOW_UP_DAYS = 7;
    private static final String TASK_PREFIX = 'Follow up on Closed Won: ';

    // Only records that just moved into Closed Won (insert as Closed Won, or stage changed to it)
    public static List<Opportunity> getNewlyClosedWon(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        List<Opportunity> result = new List<Opportunity>();
        for (Opportunity opp : newList) {
            if (opp.StageName != CLOSED_WON_STAGE) continue;

            Boolean wasClosedWon = oldMap != null
                && oldMap.containsKey(opp.Id)
                && oldMap.get(opp.Id).StageName == CLOSED_WON_STAGE;

            if (!wasClosedWon) result.add(opp);
        }
        return result;
    }

    // BEFORE context: block bad Closed Won deals
    public static void validateRevenue(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            if (opp.AccountId == null) {
                opp.addError('A Closed Won Opportunity must be linked to an Account.');
            }
            if (opp.Amount == null || opp.Amount < MIN_REVENUE) {
                opp.Amount.addError('Amount must be at least ' + MIN_REVENUE + ' to mark this Opportunity as Closed Won.');
            }
        }
    }

    // AFTER context: recalculate KPIs from source of truth (idempotent, bulk-safe)
    public static void updateAccountKPIs(List<Opportunity> opps) {
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity opp : opps) {
            if (opp.AccountId != null) accountIds.add(opp.AccountId);
        }
        if (accountIds.isEmpty()) return;

        Map<Id, Account> accountsToUpdate = new Map<Id, Account>();

        for (AggregateResult ar : [
            SELECT AccountId acctId, SUM(Amount) total, COUNT(Id) cnt, MAX(CloseDate) lastDate
            FROM Opportunity
            WHERE AccountId IN :accountIds AND IsWon = true
            GROUP BY AccountId
        ]) {
            Decimal total = (Decimal) ar.get('total');
            Integer cnt = (Integer) ar.get('cnt');
            total = total == null ? 0 : total;

            accountsToUpdate.put((Id) ar.get('acctId'), new Account(
                Id = (Id) ar.get('acctId'),
                Total_Closed_Won_Revenue__c = total,
                Closed_Won_Deal_Count__c = cnt,
                Average_Deal_Size__c = cnt > 0 ? total.divide(cnt, 2) : 0,
                Last_Closed_Won_Date__c = (Date) ar.get('lastDate')
            ));
        }

        if (!accountsToUpdate.isEmpty()) update accountsToUpdate.values();
    }

    // AFTER context: one follow-up Task per newly won Opportunity, skipping duplicates
    public static void createFollowUpTasks(List<Opportunity> opps) {
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : opps) oppIds.add(opp.Id);

        Set<Id> alreadyHasTask = new Set<Id>();
        for (Task t : [
            SELECT WhatId FROM Task
            WHERE WhatId IN :oppIds AND Subject LIKE :(TASK_PREFIX + '%')
        ]) {
            alreadyHasTask.add(t.WhatId);
        }

        List<Task> tasks = new List<Task>();
        for (Opportunity opp : opps) {
            if (alreadyHasTask.contains(opp.Id)) continue;

            String subject = (TASK_PREFIX + opp.Name);
            tasks.add(new Task(
                Subject = subject.left(255),
                WhatId = opp.Id,
                OwnerId = opp.OwnerId,
                ActivityDate = Date.today().addDays(FOLLOW_UP_DAYS),
                Status = 'Not Started',
                Priority = 'High',
                Description = 'Opportunity closed won. Confirm onboarding, send thank-you, and review upsell options.'
            ));
        }

        if (!tasks.isEmpty()) insert tasks;
    }
}