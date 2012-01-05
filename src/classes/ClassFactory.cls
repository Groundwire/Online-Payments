public with sharing class ClassFactory { 


    public PaymentToSalesforce makePaymentToSalesforce() {
		//system.debug('makePaymentToSalesforce DJH');
        string strClass;
        string strNamespace;
        
        OnlinePaymentSettings__c opSettings = OnlinePaymentSettings__c.getInstance();
        //system.debug(opSettings);
        if (opSettings != null) {
        	strClass = opSettings.PaymentToSalesforce_Class_Name__c;
        	//system.debug(strClass);
        }
		if (strClass == null) strClass = 'gwop.PaymentToSalesforce';
		
		List<String> listStr = strClass.split('.');
		if (listStr.size() > 1) {
			strNamespace = listStr[0];
			strClass = listStr[1];
		}
		
    	JSONParser parser = JSON.createParser('{}');    	
    	Type paramType = Type.forName(strNamespace, strClass); 
		PaymentToSalesforce pts = (PaymentToSalesforce)parser.readValueAs(paramType);
		// constructor and static members will not have been initialized.  force it.
		pts.initialize();
		return pts;
    }
        
    static testMethod void test_makePaymentToSalesforce() {
    	ClassFactory f = new ClassFactory();
    	PaymentToSalesforce p2s = f.makePaymentToSalesforce();
    	System.assertNotEquals(p2s, null);
    } 


}