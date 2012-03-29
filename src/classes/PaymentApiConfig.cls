global with sharing class PaymentApiConfig {

	global Payment_Processor__c defaultProcessor { get; private set; }	
	global map<string,Payment_Processor__c> processorMap { get; private set; }
		
	global PaymentApiConfig() {
        //instantiate map
        processorMap = new map<string,Payment_Processor__c>();
        
        // load payment processor settings and find the default
        list<Payment_Processor__c> processorsList = [SELECT Name, API_Login_Id__c, API_Password__c, API_Signature__c, API_Username__c, 
        						Default_Connection__c, Payment_Processor__c, Sandbox__c, Transaction_Key__c
        						FROM Payment_Processor__c ORDER BY LastModifiedDate];
        if (!processorsList.isEmpty()) {
	        for (Payment_Processor__c processor : processorsList) {
	        	processorMap.put(processor.Name,processor);
	            if (processor.default_connection__c == true) {
	                defaultProcessor = processor;
	            }
	        }
        } 
        	
	}
	
	global string getProcessor(string configName) {
		//returns the type of processor, PayPal or Authorize.Net
		Payment_Processor__c processor = processorMap.containsKey(configName) ? processorMap.get(configName) : defaultProcessor;
		if (processor != null) {
			return processor.Payment_Processor__c;
		} else {
			return null;
		}
	}
	
    global OnlinePayment.APIAuthorization getAuth( string configName ) {

        OnlinePayment.APIAuthorization auth;
       	Payment_Processor__c processor = processorMap.containsKey(configName) ? processorMap.get(configName) : defaultProcessor;
  		if (processor != null) {
	        if (processor.Payment_Processor__c == 'PayPal') {
	            auth = new OnlinePayment.APIAuthorization(
	                processor.API_Username__c, processor.API_Password__c, processor.API_Signature__c, 
	                OnlinePayment.getRemoteHost(), processor.sandbox__c 
	            );
	        } else {
	        	//we're using Authorize.Net
	        	auth = new OnlinePayment.APIAuthorization(
	                processor.API_Login_Id__c, processor.Transaction_Key__c, null, 
	                OnlinePayment.getRemoteHost(), processor.Sandbox__c 
	            );
	        }
  		}
        return auth;

    }    
    
}