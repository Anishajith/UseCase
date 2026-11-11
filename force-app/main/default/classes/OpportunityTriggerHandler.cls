public with sharing class OpportunityTriggerHandler {

    public static void handleBefore(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        List<Opportunity> closedWon = OpportunityClosedWonService.getNewlyClosedWon(newList, oldMap);
        if (closedWon.isEmpty()) return;

        OpportunityClosedWonService.validateRevenue(closedWon);
    }

    public static void handleAfter(List<Opportunity> newList, Map<Id, Opportunity> oldMap) {
        List<Opportunity> closedWon = OpportunityClosedWonService.getNewlyClosedWon(newList, oldMap);
        if (closedWon.isEmpty()) return;

        OpportunityClosedWonService.updateAccountKPIs(closedWon);
        OpportunityClosedWonService.createFollowUpTasks(closedWon);
    }
}