/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description test class for Paypal payments.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/

@istest
global with sharing class OnlinePaymentPaypalTest extends OnlinePaymentPaypal { 

	public static string testName;

	// constructor
	global OnlinePaymentPaypalTest( APIAuthorization paypalAuth ) {
		super( paypalAuth );
	}

    public class PaypalHTTPException extends Exception {}
 
	// override methods for calling paypal 
	public virtual override HttpResponse execute(Http h, HttpRequest request) {
		system.debug(logginglevel.WARN, request);
        if (testName == 'httpError') {
            throw(new PaypalHTTPException('we hit a problem trying to contact paypal!')); 
        }
		return new HttpResponse();
	}
	
	public virtual override string getResponseBody(HttpResponse response) {
		return
			(testName == 'payment') ? 'TIMESTAMP=2011%2d12%2d01T06%3a35%3a40Z&CORRELATIONID=ca81b861b0ea7&ACK=Success&VERSION=52%2e0&BUILD=2278658&AMT=4%2e00&CURRENCYCODE=USD&AVSCODE=X&CVV2MATCH=M&TRANSACTIONID=0CN71292R76361617' : 
			(testName == 'paymentSuccessWithMsgs') ? 'TIMESTAMP=2011%2d12%2d01T06%3a43%3a06Z&CORRELATIONID=8ec74676e347e&ACK=SuccessWithWarning&VERSION=52%2e0&BUILD=2278658&L_ERRORCODE0=10571&L_SHORTMESSAGE0=Transaction%20approved%20but%20with%20invalid%20CSC%20format%2e&L_LONGMESSAGE0=This%20transaction%20was%20approved%2e%20However%2c%20the%20Card%20Security%20Code%20provided%20had%20too%20few%2c%20too%20many%2c%20or%20invalid%20character%20types%20but%2c%20as%20per%20your%20account%20option%20settings%2c%20was%20not%20required%20in%20the%20approval%20process%2e&L_SEVERITYCODE0=Warning&L_ERRORPARAMID0=ProcessorResponse&L_ERRORPARAMVALUE0=0000&AMT=4%2e00&CURRENCYCODE=USD&AVSCODE=X&CVV2MATCH=M&TRANSACTIONID=0SE796323M271542R' :
			(testName == 'paymentError') ? 'TIMESTAMP=2011%2d12%2d01T06%3a44%3a57Z&CORRELATIONID=191ff5fcc7a40&ACK=Failure&VERSION=52%2e0&BUILD=2278658&L_ERRORCODE0=10527&L_SHORTMESSAGE0=Invalid%20Data&L_LONGMESSAGE0=This%20transaction%20cannot%20be%20processed%2e%20Please%20enter%20a%20valid%20credit%20card%20number%20and%20type%2e&L_SEVERITYCODE0=Error&AMT=44444444%2e00&CURRENCYCODE=USD' : 
			(testName == 'profile') ? 'PROFILEID=I%2d090EDNL6MBX7&TIMESTAMP=2011%2d12%2d01T06%3a57%3a42Z&CORRELATIONID=bc6bd1e768230&ACK=Success&VERSION=52%2e0&BUILD=2230381' : 
			(testName == 'profileError') ? 'TIMESTAMP=2011%2d12%2d01T06%3a59%3a26Z&CORRELATIONID=1607c6526576b&ACK=Failure&VERSION=52%2e0&BUILD=2230381&L_ERRORCODE0=10527&L_ERRORCODE1=10508&L_SHORTMESSAGE0=Invalid%20Data&L_SHORTMESSAGE1=Invalid%20Data&L_LONGMESSAGE0=This%20transaction%20cannot%20be%20processed%2e%20Please%20enter%20a%20valid%20credit%20card%20number%20and%20type%2e&L_LONGMESSAGE1=This%20transaction%20cannot%20be%20processed%2e%20Please%20enter%20a%20valid%20credit%20card%20expiration%20date%2e&L_SEVERITYCODE0=Error&L_SEVERITYCODE1=Error' :
			(testName == 'txnInfo') ? 'RECEIVERBUSINESS=evan_1321380845_biz%40groundwire%2eorg&RECEIVEREMAIL=evan_1321380845_biz%40groundwire%2eorg&RECEIVERID=YR3Q3TY96D39S&EMAIL=evan%40whidbey%2enet&PAYERID=9GXNDH46DNXGJ&PAYERSTATUS=unverified&COUNTRYCODE=US&ADDRESSOWNER=PayPal&ADDRESSSTATUS=None&SALESTAX=0%2e00&TIMESTAMP=2011%2d12%2d07T02%3a15%3a59Z&CORRELATIONID=a87e39587c21a&ACK=Success&VERSION=52%2e0&BUILD=2230381&FIRSTNAME=Evan&LASTNAME=Callahan&TRANSACTIONID=7SP70939JG4709620&RECEIPTID=4308%2d6629%2d8129%2d9983&TRANSACTIONTYPE=webaccept&PAYMENTTYPE=instant&ORDERTIME=2011%2d12%2d07T02%3a15%3a45Z&AMT=3%2e00&FEEAMT=0%2e39&TAXAMT=0%2e00&CURRENCYCODE=USD&PAYMENTSTATUS=Completed&PENDINGREASON=None&REASONCODE=None&L_QTY0=1&L_TAXAMT0=0%2e00&L_CURRENCYCODE0=USD' :
			(testName == 'void') ? 'AUTHORIZATIONID=0CN71292R76361617&TIMESTAMP=2012%2d03%2d12T19%3a57%3a26Z&CORRELATIONID=7f4a56b82a21c&ACK=Success&VERSION=52%2e0&BUILD=2649250' : 
			(testName == 'refund') ? 'REFUNDTRANSACTIONID=0CN71292R76361617&FEEREFUNDAMT=0%2e09&GROSSREFUNDAMT=3%2e00&NETREFUNDAMT=2%2e91&CURRENCYCODE=USD&TIMESTAMP=2012%2d03%2d12T20%3a02%3a46Z&CORRELATIONID=ca81b861b0ea7&ACK=Success&VERSION=52%2e0&BUILD=2649250' : 
			'bogusResponse';
	}	
	
	static testmethod void testPayment() {
		OnlinePaymentPaypalTest.testName = 'payment';
		OnlinePaymentPaypalTest.createConfig();
		OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );
		
		OnlinePayer payer = new OnlinePayer('test@test.com', 'testy', 'mctest', 'testco', 
			new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
		payer.shippingAddress = new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null);

		PaymentData payment = new PaymentData(123.45);
		payment.memo = 'whoa';
		payment.tax = 10;
		payment.shipping = 20;
		payment.itemList.add( new OnlinePayment.Item( 'boo', null, null, 1, 20.2, 0, null ));

		CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');
					
		PaymentTxnResult result = opt.DoDirectPayment(payer, card, payment);
		system.assertEquals( true, result.success );
		system.assertEquals( '0CN71292R76361617', result.txnId );
		
		list<Payment_Notification__c> listPn = [select Id, Transaction_Id__c, IsProcessed__c, IsTest__c 
			from Payment_Notification__c where Transaction_Id__c =: result.txnId];
		system.assertEquals(1, listPn.size());
		system.assertEquals(true, listPn[0].IsProcessed__c);
		system.assertEquals(true, listPn[0].IsTest__c);
		
		/*
		list<Opportunity> listOpp = [select Id, Name, Online_Transaction_Id__c from Opportunity
			where Online_Transaction_Id__c = :result.txnId];
		system.assertEquals(1, listOpp.size());
		*/
		
	}

	static testmethod void testPaymentMsg() {
		OnlinePaymentPaypalTest.testName = 'paymentSuccessWithMsgs';
		OnlinePaymentPaypalTest.createConfig();
		OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );
		
		OnlinePayer payer = new OnlinePayer('test@test.com', 'testy', 'mctest', 'testco', 
			new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
		PaymentData payment = new PaymentData(123.45);
		CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');
					
		PaymentTxnResult result = opt.DoDirectPayment(payer, card, payment);
		system.assertEquals( true, result.success );
		system.assert( !result.messages.isEmpty() );
	}

	static testmethod void testPaymentError() {
		OnlinePaymentPaypalTest.testName = 'paymentError';
		OnlinePaymentPaypalTest.createConfig();
		OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );
		
		OnlinePayer payer = new OnlinePayer('paymentError@test.com', 'testy', 'mctest', 'testco', 
			new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
		payer.shippingAddress = new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null);

		PaymentData payment = new PaymentData(123.45);
		payment.memo = 'whoa';
		payment.tax = 10;
		payment.shipping = 20;
		payment.itemList.add( new OnlinePayment.Item( 'boo', null, null, 1, 20.2, 0, null ));

		CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');
					
		PaymentTxnResult result = opt.DoDirectPayment(payer, card, payment);
		system.assertEquals( false, result.success );
		system.assert( !result.messages.isEmpty() );
		system.assert( result.errorMessage.contains('cannot be processed') );
		
		list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c
			from Payment_Notification__c where Payer_Email__c ='paymentError@test.com'];
		system.assertEquals(1, listPn.size());
		system.assertEquals('Failed', listPn[0].Payment_Status__c);
		system.assertEquals(false, listPn[0].IsProcessed__c);  
		system.assertEquals(true, listPn[0].IsTest__c);		
	}

	static testmethod void testRecurringProfile() {
		OnlinePaymentPaypalTest.testName = 'profile';
		OnlinePaymentPaypalTest.createConfig();
		OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );
		
		OnlinePayer payer = new OnlinePayer('test@test.com', 'testy', 'mctest', 'testco', 
			new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
		payer.shippingAddress = new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null);
		PaymentData payment = new PaymentData(1964.02, system.today().adddays(1), OnlinePayment.RecurringPeriod.MONTH, 2);
		CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');
					
		PaymentProfileResult result = opt.CreateRecurringPaymentsProfile(payer, card, payment);
		system.assertEquals( true, result.success );
		system.assertEquals( 'I-090EDNL6MBX7', result.recurringTxnId );
		
		list<Payment_Notification__c> listPn = [select Id, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c 
			from Payment_Notification__c where Recurring_Transaction_Id__c =: result.recurringTxnId];
		system.assertEquals(1, listPn.size());
		system.assertEquals(true, listPn[0].IsProcessed__c);
		system.assertEquals(true, listPn[0].IsTest__c);  

		/*
		// no way to find the opp, because authnet doesn't give a transId, just a subscriptionId,
		// and GWBase saves the subscriptionId in the recurring payment profile, which we can't query for in a non-gwbase specific way!!
		// for now, just look for our unique amount!
		list<Opportunity> listOpp = [select Id, Name, Amount, StageName, Online_Transaction_Id__c, Online_Pledge_Transaction_Id__c from Opportunity
			where Amount = 1964.02];
		system.assertEquals(1, listOpp.size());
		system.assertEquals(false, listOpp[0].StageName.contains('close'));
		*/
	}

	static testmethod void testRecurringProfileError() {
		OnlinePaymentPaypalTest.testName = 'profileError';
		OnlinePaymentPaypalTest.createConfig();
		OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );
		
		OnlinePayer payer = new OnlinePayer('profileError@test.com', 'testy', 'mctest', 'testco', 
			new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
		PaymentData payment = new PaymentData(123.45, system.today().adddays(1), OnlinePayment.RecurringPeriod.MONTH, 2);
		CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');
					
		PaymentProfileResult result = opt.CreateRecurringPaymentsProfile(payer, card, payment);
		system.assertEquals( false, result.success );
		system.assert( result.errorMessage.contains('cannot be processed') );

		list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c 
			from Payment_Notification__c where Payer_Email__c =: 'profileError@test.com'];
		system.debug(listPn);
		system.assertEquals(1, listPn.size());
		system.assertEquals('Failed', listPn[0].Payment_Status__c);
		system.assertEquals(false, listPn[0].IsProcessed__c); 
		system.assertEquals(true, listPn[0].IsTest__c); 		
	}
	
	static testmethod void testHTTPError() {
		OnlinePaymentPaypalTest.testName = 'httpError';
		OnlinePaymentPaypalTest.createConfig();
		OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );
		
		OnlinePayer payer = new OnlinePayer('httpError@test.com', 'testy', 'mctest', 'testco', 
			new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
		PaymentData payment = new PaymentData(123.45, system.today().adddays(1), OnlinePayment.RecurringPeriod.MONTH, 2);
		CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');
					
		PaymentProfileResult result = opt.CreateRecurringPaymentsProfile(payer, card, payment);
		system.assertEquals( false, result.success );
		system.assert( result.errorMessage.contains('we hit a problem trying to contact paypal!') );

		list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c 
			from Payment_Notification__c where Payer_Email__c =: 'httpError@test.com'];
		system.debug(listPn);
		system.assertEquals(1, listPn.size());
		system.assertEquals('Failed', listPn[0].Payment_Status__c);
		// can't assume PaymentToSalesforce hooked up
		//system.assertEquals(false, listPn[0].IsProcessed__c); 
		system.assertEquals(true, listPn[0].IsTest__c); 		
	}

    static testmethod void testVoidTransaction() {
        OnlinePaymentPaypalTest.testName = 'void';
        OnlinePaymentPaypalTest.createConfig();
        OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );
        
        OnlineTxnResult result = opt.DoVoid('0CN71292R76361617');
        system.assertEquals( true, result.success );

        list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c 
            from Payment_Notification__c where Transaction_Id__c = '0CN71292R76361617'];
        system.debug(listPn);
        system.assertEquals(1, listPn.size());
		system.assertEquals('Void', listPn[0].Payment_Status__c);
        system.assertEquals(true, listPn[0].IsProcessed__c); 
    }
    
    static testmethod void testRefundTransaction() {  
        OnlinePaymentPaypalTest.testName = 'refund';
        OnlinePaymentPaypalTest.createConfig();
        OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );
        PaymentData payment = new PaymentData(null);
        payment.txnId = 'old TxnId';
        
        OnlineTxnResult result = opt.RefundTransaction(payment);
        system.assertEquals( true, result.success );

        list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c 
            from Payment_Notification__c where Transaction_Id__c =: '0CN71292R76361617'];
        system.debug(listPn);
        system.assertEquals(1, listPn.size());
		system.assertEquals('Reversed', listPn[0].Payment_Status__c);
        system.assertEquals(true, listPn[0].IsProcessed__c); 
    }

	static testmethod void testTxnInfo() {
		OnlinePaymentPaypalTest.testName = 'txnInfo';
		OnlinePaymentPaypalTest.createConfig();
		OnlinePaymentPaypalTest opt = new OnlinePaymentPaypalTest( null );		
					
		OnlineTxnResult result = opt.getTransactionDetails('123');
		system.assertEquals( true, result.success );
		system.assertEquals( 32, result.params.size() );
	}

	public static void createConfig() {
		// create a default paypal config for test
		Payment_API_Config__c config = new Payment_API_Config__c();
		config.name = 'bogus';
		config.login_id__c = 'bogus';
		config.password__c = 'bogus';
		config.signature__c = 'bogus';
		config.sandbox__c = true;
		config.processor__c = 'Paypal';
		config.Default_Connection__c = true;
		insert config;
	}	
}