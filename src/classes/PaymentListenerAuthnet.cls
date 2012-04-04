/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description class provides a "listener" page for Relay Response / Silent Post from Authorize.net.
* 
* When a notification comes in, it logs all the details in a custom object, and then sends them 
*   along for processing in the GW_OnlinePayment class.  If you want to customize how payments 
*   are handled, that class is the place to make changes. 
*
* To make Relay Response work, you must configure your account properly:
*  - Set up a Sites URL
*  - Set permissions for the sites user to be able to see the page and process notifications
*  - Provide custom settings (Develop | Custom Settings | Online Payment Settings | Manage), 
*      including the Merchant Verification String and API Login ID found in the Authorize.net 
*      Merchant Interface
*
* Because the Silent Post data from Authnet is limited, this listener is not intended to
* serve as the primary method for bringing payment data into Salesforce. Instead, you should
* log Authnet payments or create subscriptions (recurring payments) by calling the Apex webservice 
* methods in GW_WEBSVC_OnlinePayments. Later, this listener can update those payments.
*
* The listener processes some notifications immediately, but schedules others to be processed
* a few seconds later using a batch class.  This avoids a "race condition" problem where multiple 
* notifications all at one time (such as a webservice call, an auth_only, and a prior_auth_capture)
* caused unexpected behavior.
*
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
*
* TO DO:
*  provide a mechanism for testing the listener configuration
*  call back to authnet for more information (such as subscription params)
********************************************************************************************************/

global virtual class PaymentListenerAuthnet {  

    // settings object 
    public OnlinePaymentSettings__c opSettings;
    
    // the parameters Authnet is sending us 
    map<string,string> params;
    
    // some payment types are handled async
    set<string> typesToHoldProcessing = new set<string>();
    
    // constructor
    global PaymentListenerAuthnet() {
        
        // get settings - there are defaults for most of them if it isn't set
        opSettings = OnlinePaymentSettings__c.getInstance();
        if (opSettings == null || test.isRunningTest()) opSettings = defaultSettings();
        
        if (opSettings.Auth_Net_TxnType_to_Hold_Processing__c != null) {
            for (string s : opSettings.Auth_Net_TxnType_to_Hold_Processing__c.split(';'))
                typesToHoldProcessing.add(s.trim());
        }
        
        // grab all the stuff Authnet sent us
        params = ApexPages.currentPage().getParameters();

        // make sure this really is a post from Authnet
        if (!params.containsKey('x_trans_id')) {
            system.debug(logginglevel.INFO, 'Page request did not include x_trans_id parameter.');
            apexpages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 
                'This page receives and responds to payment notification posts from Authorize.net. ' +
                'To use it, set your Authnet Relay Response / Silent Post address to the public URL of this page.'));
        }
    }

    // alternate constructor for async
    global PaymentListenerAuthnet(map<string,string> paramMap) {
        params = paramMap;
    }
        
    // method to initialize settings when they don't exist, or in tests
    global static OnlinePaymentSettings__c defaultSettings() {
        OnlinePaymentSettings__c ops = new OnlinePaymentSettings__c();
        ops.Process_Test_Payments__c = true;
        ops.Delete_After_N_Months__c = 12;
        ops.Merchant_Verification_String__c = 'hello';
        ops.Auth_Net_TxnType_to_Hold_Processing__c = 'prior_auth_capture;auth_only;void';
        ops.Auth_Net_Page_Params_Always_Synchronous__c = 'terminal';
        return ops;
    }

    global PageReference processNotification() {
    	string strAPILoginId;
    	
        if (params.containsKey('x_trans_id')) {

            // gather the data we need to compare the hash value
            string txnId = nv(params.get('x_trans_id'));
            decimal paymentAmount = 0.00;
            if (params.containsKey('x_amount')) 
                paymentAmount = decimal.valueOf(params.get('x_amount'));
            string amountString = string.valueOf(paymentAmount.setScale(2));
            string hashReceived = nv(params.get('x_MD5_Hash'));

            // if there is a verification string in settings, check for a match
            boolean mismatch = false;           
            if (opSettings.Merchant_Verification_String__c != null) {
                // generate a hash value with and without the API login Id 
                string hash = EncodingUtil.convertToHex(
                    crypto.generateDigest('MD5', blob.valueOf(
                        opSettings.Merchant_Verification_String__c + txnId + amountString ))); 
				
				// try all Authnet logins.                         
		    	string hashWithApi;
		        for (Payment_API_Config__c config : Payment_API_Config__c.getAll().values()) {
		            if (config.processor__c == 'Authnet') {
		            	strAPILoginId = config.login_id__c;

		                hashWithApi = EncodingUtil.convertToHex(
		                    crypto.generateDigest('MD5', blob.valueOf(
		                        opSettings.Merchant_Verification_String__c +
		                         strAPILoginId + txnId + amountString )));
				
						if (hashWithApi == hashReceived)
							break;	                         
		            }
		        }                               
                
                // check for a match 
                mismatch = (hash != hashReceived && hashWithApi != hashReceived);   
            }
            
            // assign key posted parameters to local variables
            String txnType = nv(params.get('x_type'));
            String subscriptionId = nv(params.get('x_subscription_id'));
            integer respCode = params.containsKey('x_response_code') ? integer.valueOf(params.get('x_response_code')) : null;
            String paymentStatus = (respCode == 1) ? 'Approved' : (respCode == 2) ? 'Declined' : 
                                    (respCode == 3) ? 'Error' : (respCode == 1) ? 'Held for Review' : 'Unknown';
            String payerEmail = nv(params.get('x_email'));
            String payerId = nv(params.get('x_cust_id'));
            boolean spTest = (params.get('x_test_request')=='true');
            String itemName = nv(params.get('x_description'));
            
            // create a payment record for the log
            Payment_Notification__c ipn = new Payment_Notification__c (
                Name = 'Authnet Silent Post - ' + txnType + ((payerEmail == null) ? '' : ' from ' + payerEmail),
				Notification_Type__c = 'IPN / Silent Post',
                Transaction_Type__c = txnType,
                Transaction_Id__c = txnId,
                IsTest__c = spTest,
                Recurring_Transaction_Id__c = subscriptionId,
                Item_Name__c = itemName,
                Payer_Email__c = payerEmail,
                Payer_ID__c = payerId,
                Payment_Amount__c = paymentAmount,
                Payment_Status__c = paymentStatus,
                IsProcessed__c = false
            ); 

            // concatenate all params to the long text field
            string allParams = '';
            for ( string paramName : params.keySet() )
                allParams += paramName + ' => ' + params.get(paramName) + '\n';
            ipn.Request__c = allParams;
			
            // check if this is a notification that we want to save for later processing
            string pageParam = nv(params.get('page'));
            boolean processAsync = (opSettings.Auth_Net_TxnType_to_Hold_Processing__c != null && 
                txnType != null && typesToHoldProcessing.contains(txnType)) &&
                (pageParam == null || opSettings.Auth_Net_Page_Params_Always_Synchronous__c == null ||
                !opSettings.Auth_Net_Page_Params_Always_Synchronous__c.contains(pageParam));

            if (mismatch) {
                ipn.Processing_Result__c = 'MD5 hash value received from Authorize.net did not match the digest generated from the Merchant Verification String setting.'; 
                system.debug(logginglevel.INFO, 
                    'MD5 hash received from Authorize.net did not match the generated digest: \n' +
                    opSettings.Merchant_Verification_String__c + 
                    ((strAPILoginId == null) ? '' : 
                    strAPILoginId) + txnId + amountString);

            } else if (processAsync) {
                //Schedule the batch apex to run in 15 seconds
                Datetime sysTime = System.Now().addSeconds(15);
                String chron_exp = '' + sysTime.second() + ' ' + sysTime.minute() + ' ' + sysTime.hour() + ' ' + sysTime.day() + ' ' + sysTime.month() + ' ? ' + sysTime.year();
                OnlinePaymentAuthnetAsync sch = new OnlinePaymentAuthnetAsync();  
                System.schedule('Authnet sched job ' + sysTime.getTime(), chron_exp, sch);               

            // check that this is not a test from the sandbox
            } else if (!spTest || opSettings.Process_Test_Payments__c ) {
                sendPaymentToProcessor(ipn);
            } 
            
            // log the ipn record
            insert ipn;
        
            // clear out old notifications
            if (opSettings.Delete_After_N_Months__c != null)    
                deleteOldNotifications(); 
        }
        
        return null;         
    }   

    // method that actually tries to do something with the data
    // gets called for synchronous or delayed processing
    global void sendPaymentToProcessor(Payment_Notification__c ipn) {

        string txnId = ipn.transaction_id__c;
        string txnType = ipn.transaction_type__c.toLowerCase();
        string subscriptionId = ipn.Recurring_Transaction_Id__c;
        string payerId = ipn.payer_Id__c;
        string payerEmail = ipn.payer_email__c;
        decimal paymentAmount = ipn.payment_amount__c;
        string itemName = ipn.item_name__c;
        string paymentStatus = ipn.Payment_Status__c;
        
        //system.debug('params to authnet are:');
        //system.debug(params);

        // use try-catch so that we can log the notification even if the processing fails
		Savepoint sp = Database.setSavepoint();
        try {
                    
            // use the generic payment processing class
	    	ClassFactory f = new ClassFactory();
	    	PaymentToSalesforce opmt = f.makePaymentToSalesforce();
	    	                                      
            // set all the properties from the notification
            opmt.payment.pmtProcessor = OnlinePayment.Processor.AUTHNET;
            opmt.payment.txnId = txnId;
            opmt.payment.recurringTxnId = subscriptionId;
            opmt.payer.payerId = payerId;
            opmt.payer.email = payerEmail;
            opmt.payer.firstName = nv(params.get('x_first_name'));
            opmt.payer.lastName = nv(params.get('x_last_name'));
            opmt.payer.companyName = nv(params.get('x_company'));
            opmt.payer.billingAddress.street = nv(params.get('x_address'));
            opmt.payer.billingAddress.city = nv(params.get('x_city'));
            opmt.payer.billingAddress.state = nv(params.get('x_state'));
            opmt.payer.billingAddress.zip = nv(params.get('x_zip'));
            opmt.payer.billingAddress.country = nv(params.get('x_country'));
            opmt.payer.billingAddress.phone = nv(params.get('x_phone'));
            opmt.payment.totalAmount = paymentAmount; 
            if (params.containsKey('x_duty')) 
                opmt.payment.fee = decimal.valueOf(params.get('x_duty'));
            if (params.containsKey('x_tax')) 
                opmt.payment.tax = decimal.valueOf(params.get('x_tax'));
            if (params.containsKey('x_freight')) 
                opmt.payment.shipping = decimal.valueOf(params.get('x_freight'));
            opmt.payment.invoice = nv(params.get('x_invoice_num'));
            if (nv(params.get('x_subscription_paynum')) != null) 
                opmt.payment.memo = 'Subscription payment # ' + params.get('x_subscription_paynum'); 
    
            // there may be one or many items
            // add them to the list of Item objects
            if (itemName != null && itemName != '')
                opmt.payment.itemList.add(new OnlinePayment.Item(itemName, null, null, 1, paymentAmount, null, null));                    
                    
            // translate the payment status to the enum value
            opmt.payment.pmtStatus =
                (paymentStatus == 'Approved') ? ( 
                    (txnType == 'AUTH_ONLY') ? OnlinePayment.PaymentStatus.AUTHORIZED : 
                    (txnType == 'CREDIT') ? OnlinePayment.PaymentStatus.REVERSED : 
                    (txnType == 'VOID') ? OnlinePayment.PaymentStatus.VOIDED :
                    OnlinePayment.PaymentStatus.COMPLETED) :
                (paymentStatus == 'Held for Review') ? OnlinePayment.PaymentStatus.PENDING :
                (paymentStatus == 'Declined' || paymentStatus == 'Error') ? 
                    OnlinePayment.PaymentStatus.FAILED : 
                null;
            string rcode = nv(params.get('x_response_reason_code'));
            opmt.payment.reasonCode = (rcode == null || rcode == '1') ? null : 
                (params.get('x_response_reason_text') + ' [Response code ' + rcode + ']');
                    
            // translate the payment type to the enum value
            opmt.payment.pmtType = 
                (params.get('x_method') == 'ECHECK') ? OnlinePayment.PaymentType.ECHECK :
                (params.get('x_method') == 'CC') ? OnlinePayment.PaymentType.CREDITCARD :
                null;  

            // now process each transaction type    
            if (subscriptionId == null) {
                // process single payment
                opmt.processSinglePayment();
                ipn.opportunity__c = opmt.opportunityId;                    
                ipn.isProcessed__c = true;
            } else {    
                // process recurring payment
                opmt.processRecurringPayment();
                ipn.opportunity__c = opmt.opportunityId;                    
                ipn.isProcessed__c = true;
            }        

			// save the match result
			if (ipn.Processing_Result__c == null && opmt.payerMatchResult != null)
				ipn.Processing_Result__c = 
					(opmt.payerMatchResult == OnlinePayment.MatchResult.TRANSACTION_MATCH) ? 'Matched existing Transaction ID' :
					(opmt.payerMatchResult == OnlinePayment.MatchResult.CONTACT_MATCH) ? 'Matched existing contact' :
					(opmt.payerMatchResult == OnlinePayment.MatchResult.NEW_CONTACT) ? 'Created new contact' :
					(opmt.payerMatchResult == OnlinePayment.MatchResult.ACCOUNT_MATCH) ? 'Matched existing account/organization' :
					(opmt.payerMatchResult == OnlinePayment.MatchResult.NEW_ACCOUNT) ? 'Created new account' :
					null; 

        } catch (exception e) {
            system.debug(loggingLevel.error, e);
			ipn.Processing_Result__c = e.getMessage();
			ipn.errorLineNumber__c = e.getLineNumber();
			ipn.errorStackTrace__c = e.getStackTraceString(); 
			ipn.isProcessed__c = false;
			Database.Rollback( sp );
        }       
    }

    private static string nv(string s) { return ((s==null || s.trim()=='') ? null : s.trim()); } 

    @future
    global static void deleteOldNotifications() {
        OnlinePaymentSettings__c opSettings = OnlinePaymentSettings__c.getInstance();
        if (opSettings == null) opSettings = defaultSettings();
        
        if (opSettings.Delete_After_N_Months__c > 0) {
            list<Payment_Notification__c> oldPN = 
                [select id from Payment_Notification__c where isProcessed__c = true
                    and createddate < : system.today().addmonths(-opSettings.Delete_After_N_Months__c.intValue()) limit 1000];
            if (!oldPN.isEmpty()) delete oldPN;
        }
    }

    /*------------------------------------------------------------------------------------
    * TESTS
    -------------------------------------------------------------------------------------*/ 
    static testMethod void testIPN () {
        
        PageReference pageRef=Page.PaymentListenerAuthnet; 
        Test.setCurrentPage(pageRef); 

        // for code coverage, test opening the page with no params 
        PaymentListenerAuthnet ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ann.processNotification();

        // and with a bogus txn type 
        ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ApexPages.currentPage().getParameters().put('x_trans_id', 'bogus');
        ApexPages.currentPage().getParameters().put('x_type', 'bogus');
        ann.processNotification();

        // add params for a realistic incoming IPN
        ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ApexPages.currentPage().getParameters().put('x_trans_id', '2147490176');
        ApexPages.currentPage().getParameters().put('x_type', 'auth_capture');
        ApexPages.currentPage().getParameters().put('x_response_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_subcode', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_text', 'This transaction has been approved.'); 
        ApexPages.currentPage().getParameters().put('x_description', 'testitem');
        ApexPages.currentPage().getParameters().put('x_auth_code', 'QbJHm4');
        ApexPages.currentPage().getParameters().put('x_first_name', 'Jackie');
        ApexPages.currentPage().getParameters().put('x_last_name', 'Chan');
        ApexPages.currentPage().getParameters().put('x_email', 'donor54321@test.com');
        ApexPages.currentPage().getParameters().put('x_address', '123 4th Ave');
        ApexPages.currentPage().getParameters().put('x_city', 'Seattle');
        ApexPages.currentPage().getParameters().put('x_state', 'WA');
        ApexPages.currentPage().getParameters().put('x_zip', '98101');
        ApexPages.currentPage().getParameters().put('x_country', 'United States');        
        ApexPages.currentPage().getParameters().put('x_amount', '1234.56');
        ApexPages.currentPage().getParameters().put('x_avs_code', 'Y');
        ApexPages.currentPage().getParameters().put('x_cavv_response', '2');
        ApexPages.currentPage().getParameters().put('x_test_request', 'false');
        ApexPages.currentPage().getParameters().put('x_cust_id', '12345678');
        ApexPages.currentPage().getParameters().put('x_company', 'Kung Fu Inc.');
        ApexPages.currentPage().getParameters().put('x_tax', '1');
        ApexPages.currentPage().getParameters().put('x_freight', '1');
        ApexPages.currentPage().getParameters().put('x_po_num', '987654');
        ApexPages.currentPage().getParameters().put('x_MD5_Hash', 'a045bf296af1c3163ccf9f31c3b3012e');
        
        // process it
        ann.processNotification();

        // verify that it was logged         
        payment_notification__c ipn;
        ipn = [select name, payment_amount__c, isProcessed__c from payment_notification__c where 
            payer_email__c = 'donor54321@test.com' limit 1];
        system.assertEquals('Authnet Silent Post - auth_capture from donor54321@test.com', ipn.name);
        system.assertEquals(1234.56, ipn.payment_amount__c);
        system.debug('DJH: ipn is:');
        system.debug(ipn);
        // can't assume PaymentToSalesforce processor is hooked up.
        //system.assertEquals(true, ipn.isprocessed__c);

        // this time it is a subscription
        ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ApexPages.currentPage().getParameters().put('x_trans_id', '9383726293');
        ApexPages.currentPage().getParameters().put('x_type', 'auth_capture');
        ApexPages.currentPage().getParameters().put('x_response_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_subcode', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_text', 'This transaction has been approved.'); 
        ApexPages.currentPage().getParameters().put('x_description', 'testitem');
        ApexPages.currentPage().getParameters().put('x_auth_code', 'QbJHm4');
        ApexPages.currentPage().getParameters().put('x_first_name', 'Jackie');
        ApexPages.currentPage().getParameters().put('x_last_name', 'Chan');
        ApexPages.currentPage().getParameters().put('x_email', 'donor321@test.com');
        ApexPages.currentPage().getParameters().put('x_address', '123 4th Ave');
        ApexPages.currentPage().getParameters().put('x_city', 'Seattle');
        ApexPages.currentPage().getParameters().put('x_state', 'WA');
        ApexPages.currentPage().getParameters().put('x_zip', '98101');
        ApexPages.currentPage().getParameters().put('x_country', 'United States');        
        ApexPages.currentPage().getParameters().put('x_amount', '0.5');
        ApexPages.currentPage().getParameters().put('x_avs_code', 'Y');
        ApexPages.currentPage().getParameters().put('x_cavv_response', '2');
        ApexPages.currentPage().getParameters().put('x_test_request', 'false');
        ApexPages.currentPage().getParameters().put('x_cust_id', '12345678');
        ApexPages.currentPage().getParameters().put('x_tax', '1');
        ApexPages.currentPage().getParameters().put('x_freight', '1');
        ApexPages.currentPage().getParameters().put('x_po_num', '987654');
        ApexPages.currentPage().getParameters().put('x_MD5_Hash', '58d30bfb8a3d3c835813d7c4e21275fd');
        ApexPages.currentPage().getParameters().put('x_subscription_id', '629383746');
        ApexPages.currentPage().getParameters().put('x_subscription_paynum', '1');
        ann.processNotification();

        // verify that it was logged         
        ipn = [select name, payment_amount__c from payment_notification__c where 
            payer_email__c = 'donor321@test.com' limit 1];
        system.assertEquals('Authnet Silent Post - auth_capture from donor321@test.com', ipn.name);
        system.assertEquals(0.5, ipn.payment_amount__c);

        // now a refund
        ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ApexPages.currentPage().getParameters().put('x_trans_id', '9383726293');
        ApexPages.currentPage().getParameters().put('x_type', 'credit');
        ApexPages.currentPage().getParameters().put('x_response_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_subcode', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_code', '33');
        ApexPages.currentPage().getParameters().put('x_response_reason_text', 'Money baby.'); 
        ApexPages.currentPage().getParameters().put('x_description', 'refund please');
        ApexPages.currentPage().getParameters().put('x_auth_code', 'QbJHm4');
        ApexPages.currentPage().getParameters().put('x_first_name', 'Jackie');
        ApexPages.currentPage().getParameters().put('x_last_name', 'Chan');
        ApexPages.currentPage().getParameters().put('x_email', 'donor321@test.com');
        ApexPages.currentPage().getParameters().put('x_address', '123 4th Ave');
        ApexPages.currentPage().getParameters().put('x_city', 'Seattle');
        ApexPages.currentPage().getParameters().put('x_state', 'WA');
        ApexPages.currentPage().getParameters().put('x_zip', '98101');
        ApexPages.currentPage().getParameters().put('x_country', 'United States');        
        ApexPages.currentPage().getParameters().put('x_amount', '0.5');
        ApexPages.currentPage().getParameters().put('x_avs_code', 'Y');
        ApexPages.currentPage().getParameters().put('x_cavv_response', '2');
        ApexPages.currentPage().getParameters().put('x_test_request', 'false');
        ApexPages.currentPage().getParameters().put('x_cust_id', '12345678');
        ApexPages.currentPage().getParameters().put('x_tax', '1');
        ApexPages.currentPage().getParameters().put('x_freight', '1');
        ApexPages.currentPage().getParameters().put('x_MD5_Hash', '58d30bfb8a3d3c835813d7c4e21275fd');
        ApexPages.currentPage().getParameters().put('x_subscription_id', '629383746');
        ApexPages.currentPage().getParameters().put('x_subscription_paynum', '1');
        ann.processNotification();
        
        ipn = [select name, payment_amount__c from payment_notification__c where 
            item_name__c = 'refund please' limit 1];
        system.assertEquals('Authnet Silent Post - credit from donor321@test.com', ipn.name);
        system.assertEquals(0.5, ipn.payment_amount__c);        

        // bad hash
        ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ApexPages.currentPage().getParameters().put('x_trans_id', '242424234242');
        ApexPages.currentPage().getParameters().put('x_type', 'auth_capture');
        ApexPages.currentPage().getParameters().put('x_response_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_subcode', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_text', 'This transaction has been approved.'); 
        ApexPages.currentPage().getParameters().put('x_description', 'testitem');
        ApexPages.currentPage().getParameters().put('x_auth_code', 'QbJHm4');
        ApexPages.currentPage().getParameters().put('x_email', null);
        ApexPages.currentPage().getParameters().put('x_first_name', 'Jackie');
        ApexPages.currentPage().getParameters().put('x_last_name', 'Chan');
        ApexPages.currentPage().getParameters().put('x_amount', '4321.56');
        ApexPages.currentPage().getParameters().put('x_avs_code', 'Y');
        ApexPages.currentPage().getParameters().put('x_cavv_response', '2');
        ApexPages.currentPage().getParameters().put('x_test_request', 'false');
        ApexPages.currentPage().getParameters().put('x_cust_id', '666');
        ApexPages.currentPage().getParameters().put('x_company', 'Kung Fu Inc.');
        ApexPages.currentPage().getParameters().put('x_tax', '1');
        ApexPages.currentPage().getParameters().put('x_freight', '1');
        ApexPages.currentPage().getParameters().put('x_po_num', '987654');
        ApexPages.currentPage().getParameters().put('x_MD5_Hash', 'a045bf296af1c3163ccf9f31c3b3012e');
        ann.processNotification();
        
        ipn = [select name, isprocessed__c from payment_notification__c where 
            transaction_id__c = '242424234242' limit 1];
        system.assertEquals('Authnet Silent Post - auth_capture', ipn.name);
        // can't assume PaymentToSalesforce processor is hooked up.
        //system.assertEquals(false, ipn.isprocessed__c);
    }
    
    static testMethod void testAuthOnlyThenCapture () {
        
        PageReference pageRef=Page.PaymentListenerAuthnet; 
        Test.setCurrentPage(pageRef); 
        
        // for code coverage, test opening the page with no params 
        PaymentListenerAuthnet ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ann.processNotification();

        // and with a bogus txn type 
        ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ApexPages.currentPage().getParameters().put('x_trans_id', 'bogus');
        ApexPages.currentPage().getParameters().put('x_type', 'bogus');
        ann.processNotification();

        // add params for a realistic incoming IPN
        ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ApexPages.currentPage().getParameters().put('x_trans_id', '2147490176');
        ApexPages.currentPage().getParameters().put('x_type', 'auth_only');
        ApexPages.currentPage().getParameters().put('x_response_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_subcode', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_text', 'This transaction has been approved.'); 
        ApexPages.currentPage().getParameters().put('x_description', 'testitem');
        ApexPages.currentPage().getParameters().put('x_auth_code', 'QbJHm4');
        ApexPages.currentPage().getParameters().put('x_first_name', 'Jackie');
        ApexPages.currentPage().getParameters().put('x_last_name', 'Chan');
        ApexPages.currentPage().getParameters().put('x_email', 'donor54321@test.com');
        ApexPages.currentPage().getParameters().put('x_address', '123 4th Ave');
        ApexPages.currentPage().getParameters().put('x_city', 'Seattle');
        ApexPages.currentPage().getParameters().put('x_state', 'WA');
        ApexPages.currentPage().getParameters().put('x_zip', '98101');
        ApexPages.currentPage().getParameters().put('x_country', 'United States');        
        ApexPages.currentPage().getParameters().put('x_amount', '1234.56');
        ApexPages.currentPage().getParameters().put('x_avs_code', 'Y');
        ApexPages.currentPage().getParameters().put('x_cavv_response', '2');
        ApexPages.currentPage().getParameters().put('x_test_request', 'false');
        ApexPages.currentPage().getParameters().put('x_cust_id', '12345678');
        ApexPages.currentPage().getParameters().put('x_company', 'Kung Fu Inc.');
        ApexPages.currentPage().getParameters().put('x_tax', '1');
        ApexPages.currentPage().getParameters().put('x_freight', '1');
        ApexPages.currentPage().getParameters().put('x_po_num', '987654');
        ApexPages.currentPage().getParameters().put('x_MD5_Hash', 'a045bf296af1c3163ccf9f31c3b3012e');
        
        // process it
        ann.processNotification();

        // verify that it was logged but not marked processed        
        payment_notification__c ipn;
        ipn = [select name, payment_amount__c, isProcessed__c from payment_notification__c where 
            payer_email__c = 'donor54321@test.com' limit 1];
        system.assertEquals('Authnet Silent Post - auth_only from donor54321@test.com', ipn.name);
        system.assertEquals(1234.56, ipn.payment_amount__c);
        // can't assume PaymentToSalesforce processor is hooked up.
        //system.assertEquals(false, ipn.IsProcessed__c); 

        // this time it is prior auth capture, with limited contact data
        ann = new PaymentListenerAuthnet();
        ann.opSettings = PaymentListenerAuthnet.defaultSettings();
        ApexPages.currentPage().getParameters().put('x_trans_id', '2147490176');
        ApexPages.currentPage().getParameters().put('x_type', 'prior_auth_capture');
        ApexPages.currentPage().getParameters().put('x_zip', '98101');
        ApexPages.currentPage().getParameters().put('x_response_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_subcode', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_code', '1');
        ApexPages.currentPage().getParameters().put('x_response_reason_text', 'This transaction has been approved.'); 
        ApexPages.currentPage().getParameters().put('x_description', 'testitem');
        ApexPages.currentPage().getParameters().put('x_auth_code', 'QbJHm4');
        ApexPages.currentPage().getParameters().put('x_country', 'United States');        
        ApexPages.currentPage().getParameters().put('x_amount', '1234.56');
        ApexPages.currentPage().getParameters().put('x_avs_code', 'P');
        ApexPages.currentPage().getParameters().put('x_cavv_response', '2');
        ApexPages.currentPage().getParameters().put('x_test_request', 'false');
        ApexPages.currentPage().getParameters().put('x_tax', '1');
        ApexPages.currentPage().getParameters().put('x_freight', '1');
        ApexPages.currentPage().getParameters().put('x_po_num', '987654');
        ApexPages.currentPage().getParameters().put('x_MD5_Hash', 'a045bf296af1c3163ccf9f31c3b3012e');
        ann.processNotification();

        // assume that this code was scheduled and ran as expected
        Test.startTest();
        OnlinePaymentAuthnetAsync batch = new OnlinePaymentAuthnetAsync(
            'SELECT id, gwop__Transaction_Type__c, gwop__Transaction_Id__c, gwop__Recurring_Transaction_Id__c, gwop__Item_Name__c, gwop__Payer_Email__c, ' +
                ' gwop__Payer_ID__c, gwop__Payment_Amount__c, gwop__Payment_Status__c, gwop__Request__c from gwop__Payment_Notification__c ' + 
                ' WHERE gwop__IsProcessed__c = false AND gwop__IsTest__c = false AND gwop__Transaction_Id__c = \'2147490176\'' +
                ' ORDER BY gwop__transaction_type__c DESC LIMIT 10'       
        );
        id batchinstanceid = database.executeBatch (batch, 10);
        test.stopTest();

        // verify that it was logged
        ipn = [select name, IsProcessed__c, Opportunity__c from payment_notification__c where 
            Transaction_Id__c = '2147490176' AND Transaction_Type__c = 'prior_auth_capture' limit 1];
        // can't assume PaymentToSalesforce processor is hooked up.
        //system.assertEquals(true, ipn.IsProcessed__c);
        //system.assert(ipn.Opportunity__c != null);
        
        // verify that installment was marked paid
        //system.assertEquals(0, ipn.opportunity__r.GWBase__total_unpaid__c);
    }
                      
}