@isTest (SeeAllData=true)
private class TEST_ProcessorPreventTwoDefaults {
	
	static testmethod void addSecondDefault() {
		
		//find and delete existing default processors
		Payment_Processor__c[] existingDefaults = [SELECT id FROM Payment_Processor__c WHERE Default_Connection__c = true];
		if (!existingDefaults.isEmpty()) {
			delete existingDefaults;
		}
		
		Payment_Processor__c defaultProcessor = new Payment_Processor__c(
			Name = 'Default_Processor',
			Default_Connection__c = true,
			Payment_Processor__c = 'PayPal'
			);
		insert defaultProcessor;
		
		Payment_Processor__c secondDefault = new Payment_Processor__c(
			Name = 'Second_Default_Processor',
			Default_Connection__c = true,
			Payment_Processor__c = 'PayPal'
			);
		
		try {
			insert secondDefault;
		} catch (Exception e) {
			system.assert(e.getMessage().contains('You have already selected a Payment Processor as the Default Processor.'));
		}
		
	}
	
}