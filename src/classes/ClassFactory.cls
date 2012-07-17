/*******************************************************************************************************
* @author David Habib
* @date 1/9/2012
* @description Class which allows dynamic loading of a class outside of the managed package.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/

public with sharing class ClassFactory {

    public PaymentToSalesforce makePaymentToSalesforce() {
        string strClass;
        string strNamespace;
        
        OnlinePaymentSettings__c opSettings = OnlinePaymentSettings__c.getInstance();
        //system.debug(opSettings);
        if (opSettings != null) {
        	strClass = opSettings.PaymentToSalesforce_Class_Name__c;
        }
		if (strClass == null) strClass = 'gwop.PaymentToSalesforce';
        //system.debug(strClass);
		
		List<String> listStr = strClass.split('\\.');
		if (listStr.size() > 1) {
			strNamespace = listStr[0];
			strClass = listStr[1];
		}

    	Type paramType = Type.forName(strNamespace, strClass); 
		PaymentToSalesforce pts = (PaymentToSalesforce)(paramType.newInstance());
		// pts.initialize();  NO LONGER NEEDED 
		return pts;
    }
    
    public OnlinePaymentPaypal makeOPPaypal( OnlinePayment.APIAuthorization auth, string testName ) {
        if (Test.IsRunningTest()) {
            OnlinePaymentPaypalTest.testName = testName;         
            return new OnlinePaymentPaypalTest( auth );              
        } else {
            return new OnlinePaymentPaypal( auth );                      	
        }   
    }
        
    public OnlinePaymentAuthnet makeOPAuthnet( OnlinePayment.APIAuthorization auth, string testName ) {
        if (Test.IsRunningTest()) {
            OnlinePaymentAuthnetTest.testName = testName;         
            return new OnlinePaymentAuthnetTest( auth );              
        } else {
            return new OnlinePaymentAuthnet( auth );
        }   
    }

    static testMethod void test_makePaymentToSalesforce() {
    	ClassFactory f = new ClassFactory();
    	PaymentToSalesforce p2s = f.makePaymentToSalesforce();
    	System.assertNotEquals(p2s, null);
    } 
    
}