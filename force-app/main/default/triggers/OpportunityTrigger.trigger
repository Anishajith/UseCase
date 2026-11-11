trigger OpportunityTrigger on Opportunity (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        OpportunityTriggerHandler.handleBefore(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter) {
        OpportunityTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap);
    }
}