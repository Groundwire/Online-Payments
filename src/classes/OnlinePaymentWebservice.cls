global virtual class OnlinePaymentWebservice { 
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101 
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
* Use this class to insert online payments from a website
-----------------------------------------------------------------------------------------------*/	


	// instantiate the Groundwire online payments class
	static PaymentToSalesforce gwop { 
		get {   
			if (gwop == null) {
	            // use the generic payment processing class
		    	ClassFactory f = new ClassFactory();
		    	gwop = f.makePaymentToSalesforce();
			}
	    	return gwop;
		}
		set;
	}                                      
	
	
	// array structure to store each item
	global virtual class Item {
		WebService string name; 
		// code is a product id
		WebService string code;
		WebService string discountcode;
		WebService integer quantity;
		WebService decimal amount;
		
		
		
		public OnlinePayment.Item convertItem {
			get { return (new OnlinePayment.Item( name, code, discountcode, quantity, amount, null, null)); }
		}
	}

	// data structure to pass in and return payment data
	global virtual class PaymentInfo {

		// payer data
		WebService string payerId;
		WebService string email;
		WebService string firstName;
		WebService string lastName;
		WebService string companyName;
		WebService string street;
		WebService string city;
		WebService string state;
		WebService string zip;
		WebService string country;
		WebService string phone;
		WebService boolean companyIsPayer;		// if both contact and account are set, this determines 
												// whether opp should be org or individual
		// payment data
		WebService OnlinePayment.Processor pmtProcessor;
		WebService OnlinePayment.PaymentType pmtType;
	 	WebService OnlinePayment.PaymentStatus pmtStatus;
		WebService string priceBook;
		WebService string txnId;
		WebService string parentTxnId;   // for refund or reversal
		//WebService string cardType;
		WebService string last4digits;
		WebService string currencyCode;
		WebService decimal exchangeRate;
		WebService decimal totalAmount;
		WebService decimal fee;
		WebService decimal tax;
		WebService decimal shipping;
		WebService List<Item> itemList;
		WebService string invoice;
		WebService string reasonCode;
		WebService string memo; 
		
		// use the paymentResponse field to pass along the complete response from the processor
		// this could be XML, JSON, plain text, or a set of name/value pairs
		WebService string paymentResponse;
	
		// use the custom field to pass additional details you need, such as the campaign for the opportunity
		// in our GW processor, you can pass JSON in this property to set any custom fields in Salesforce
		WebService string custom;
	
		// properties for recurring payment, pledge, or subscription
		WebService string recurringTxnId;  
		WebService OnlinePayment.RecurringPeriod pmtPeriod;
		WebService integer frequency;			// combine with period above, e.g. every 1 Month
		WebService integer occurrences;
		WebService date startDate;
	
		// you can set these to existing objects, or use the setPayer method to match or create the payer
		WebService id contactId;
		WebService id accountId;
	
		// after a successful call to one of the methods, this will be set to the associated opportunity
		WebService id opportunityId;
	
		// contains a code indicating the result of trying to match to a contact or account
		WebService OnlinePayment.MatchResult payerMatchResult;
	}

	// array structure to provide the response back
	global virtual class Response {
		WebService boolean success; 
		WebService PaymentInfo payment;
		WebService string errorMessage;
		WebService integer errorLineNumber;
		WebService string errorStackTrace; 
	}

	// METHODS FOR PROCESSING PAYMENTS

	// calling setPayer is always optional, because the other methods will each call it
	// it is exposed so that you can run separately and see the result if you need to
	WebService static Response setPayer( PaymentInfo payment ) {
		Response resp = new Response();
		try {
			setProps( payment );
			resp.success = gwop.setPayer();
			getProps( payment );
		} catch (exception e) {
			resp.success = false;
			resp.errorMessage = e.getMessage();
			resp.errorStackTrace = e.getStackTraceString();
			resp.errorLineNumber = e.getLineNumber();
		}
		logNotification( payment, OnlinePayment.PaymentAction.PAY, resp );
		resp.payment = payment;
		return resp;
	}	

	WebService static Response processSinglePayment( PaymentInfo payment ) {
		Response resp = new Response();
		try {
			setProps( payment );
			resp.success = gwop.processSinglePayment();
			getProps( payment );
		} catch (exception e) {
			resp.success = false;
			resp.errorMessage = e.getMessage();  
			resp.errorStackTrace = e.getStackTraceString();
			resp.errorLineNumber = e.getLineNumber();
		}
		logNotification( payment, OnlinePayment.PaymentAction.PAY, resp );
		resp.payment = payment;
		return resp;
	}

	WebService static Response startRecurringPayments( PaymentInfo payment ) {
		Response resp = new Response();
		try {
			setProps( payment );
			resp.success = gwop.startRecurringPayments();
			getProps( payment );
		} catch (exception e) {
			resp.success = false;
			resp.errorMessage = e.getMessage();
			resp.errorStackTrace = e.getStackTraceString();
			resp.errorLineNumber = e.getLineNumber();
		}
		logNotification( payment, OnlinePayment.PaymentAction.PAY, resp );
		resp.payment = payment;
		return resp;
	}	
	
	WebService static Response processRecurringPayment( PaymentInfo payment ) {
		Response resp = new Response();
		try {
			setProps( payment );
			resp.success = gwop.processRecurringPayment();
			getProps( payment );
		} catch (exception e) {
			resp.success = false;
			resp.errorMessage = e.getMessage();
			resp.errorStackTrace = e.getStackTraceString();
			resp.errorLineNumber = e.getLineNumber();
		}
		logNotification( payment, OnlinePayment.PaymentAction.PAY, resp );
		resp.payment = payment;
		return resp;
	}

	WebService static Response cancelRecurringPayments( PaymentInfo payment ) {
		Response resp = new Response();
		try {
			setProps( payment );
			resp.success = gwop.cancelRecurringPayments();
			getProps( payment );
		} catch (exception e) {
			resp.success = false;
			resp.errorMessage = e.getMessage();
			resp.errorStackTrace = e.getStackTraceString();
			resp.errorLineNumber = e.getLineNumber();
		}
		logNotification( payment, OnlinePayment.PaymentAction.VOIDTXN, resp );
		resp.payment = payment;
		return resp;
	}

	global static void logNotification( PaymentInfo payment, OnlinePayment.PaymentAction action, Response resp ) {

		// map the webservice payment data to OnlinePayment equivalents
		
		OnlinePayment.OnlinePayer opayer = new OnlinePayment.OnlinePayer();
		opayer.email = payment.email;
		opayer.payerId = payment.payerId;
		
		OnlinePayment.PaymentData opayment = new OnlinePayment.PaymentData(payment.totalAmount);
		opayment.pmtStatus = payment.pmtStatus;
		opayment.txnId = payment.txnId;
		opayment.recurringTxnId = payment.recurringTxnId;
		opayment.opportunityId = payment.opportunityId;
		
		Payment_Notification__c ipn = OnlinePayment.logNotification(opayer, opayment, 'Webservice Call', action, null, 
			payment.paymentResponse, false, resp.success, resp.errorMessage, false );	

		// get the first item, if any
		if (payment.itemList != null && !payment.itemList.isEmpty()) {
			ipn.item_name__c = payment.itemList[0].name;
			ipn.item_number__c = payment.itemList[0].code;
		} 	 

		insert ipn; 
	}

	// method that sets the webservice properties on the online payment class
	global static void setProps( PaymentInfo payment ) {
		gwop.payer.payerId = payment.payerId;
		gwop.payer.email = payment.email;
		gwop.payer.firstName = payment.firstName;
		gwop.payer.lastName = payment.lastName;
		gwop.payer.companyName = payment.companyName;
		gwop.payer.billingAddress.street = payment.street;
		gwop.payer.billingAddress.city = payment.city;
		gwop.payer.billingAddress.state = payment.state;
		gwop.payer.billingAddress.zip = payment.zip;
		gwop.payer.billingAddress.country = payment.country;
		gwop.payer.billingAddress.phone = payment.phone;
		if (gwop.payment.companyIsPayer == null) gwop.payment.companyIsPayer = payment.companyIsPayer;
		
		gwop.payment.pmtProcessor = payment.pmtProcessor;
		gwop.payment.pmtType = payment.pmtType;
 		gwop.payment.pmtStatus = payment.pmtStatus; 
		gwop.payment.txnId = payment.txnId;
		gwop.payment.parentTxnId = payment.parentTxnId;  // for refund or reversal
		gwop.payment.last4digits = payment.last4digits;
		gwop.payment.currencyCode = payment.currencyCode;
		gwop.payment.exchangeRate = payment.exchangeRate;
		gwop.payment.totalAmount = payment.totalAmount;
		gwop.payment.fee = payment.fee;
		gwop.payment.tax = payment.tax; 
		gwop.payment.shipping = payment.shipping;
		gwop.payment.invoice = payment.invoice;
		gwop.payment.reasonCode = payment.reasonCode;
		gwop.payment.memo = payment.memo;  
		
		if (gwop.payment.itemList.isEmpty() && payment.itemList != null) {
			for (Item itm : payment.itemList)
				gwop.payment.itemList.add(itm.convertItem);
		}
		gwop.payment.custom = payment.custom;
		gwop.payment.recurringTxnId = payment.recurringTxnId;
		gwop.payment.pmtPeriod = payment.pmtPeriod;
		gwop.payment.frequency = payment.frequency;		// combine with period above, e.g. every 1 Month
		gwop.payment.occurrences = payment.occurrences;
		gwop.payment.startDate = payment.startDate;
		if (gwop.contactId == null) gwop.contactId = payment.contactId;
		if (gwop.accountId == null) gwop.accountId = payment.accountId;		
	}
	
	// methods that get back properties from the class
	global static void getProps( PaymentInfo payment ) {
		payment.payerId = gwop.payer.payerId;
		payment.companyIsPayer = gwop.payment.companyIsPayer;
		payment.payerMatchResult = gwop.payerMatchResult;	
		payment.txnId = gwop.payment.txnId;
		payment.parentTxnId = gwop.payment.parentTxnId;
		payment.recurringTxnId = gwop.payment.recurringTxnId;  
		payment.contactId = gwop.contactId;
		payment.accountId = gwop.accountId;		
		payment.opportunityId = gwop.opportunityId;		
	}
	
	//--------------------------------------------------------------------------------------------
	// TESTS
	
	static testMethod void testSetPayer() {
		OnlinePaymentWebservice.PaymentInfo p = new OnlinePaymentWebservice.paymentInfo();
		p.firstname = 'EvanTest';
		p.lastname = 'CallahanTest';
		p.email = 'evantest@groundwiretest.org';
		OnlinePaymentWebservice.Response resp = OnlinePaymentWebservice.setPayer( p );
		system.assert(resp.success, 'setPayer returned fail');
		// can't assume PaymentToSalesforce hooked up		
		//system.assertEquals(OnlinePayment.MatchResult.NEW_CONTACT, p.payerMatchResult);	
	}

	static testMethod void testSinglePayment() {
		insert new Contact(firstName = 'EvanTest', lastName = 'CallahanTest', 
			email = 'evantest@groundwiretest.org');
		
		test.startTest();
		
        // set default setting for matching
        //gwop.opSettings.Dont_Match_Contacts_by_Email__c = false;
                
		OnlinePaymentWebservice.PaymentInfo p = new OnlinePaymentWebservice.PaymentInfo();
		p.firstname = 'EvanTest';
		p.lastname = 'CallahanTest';
		p.email = 'evantest@groundwiretest.org';
		p.txnId = 'X0X0X';
		p.totalAmount = 1234;
		
		OnlinePaymentWebservice.Item i = new OnlinePaymentWebservice.Item();
		i.name = 'Gift';
		i.amount = 1234;
		p.itemList = new list<OnlinePaymentWebservice.Item>{ i };
		
		OnlinePaymentWebservice.Response resp = OnlinePaymentWebservice.processSinglePayment( p );
		// can't assume PaymentToSalesforce hooked up
		//system.assertEquals(OnlinePayment.MatchResult.CONTACT_MATCH, p.payerMatchResult);	
		system.assert(resp.success, 'processSinglePayment returned fail');
		
		/*
		// look for the opp
		GWBase__oppPayment__c[] op0 = [select id, GWBase__paid__c, GWBase__amount__c, GWBase__isinstallment__c from GWBase__oppPayment__c 
			where GWBase__opportunity__r.Online_Transaction_Id__c = 'X0X0X'];
		system.assertEquals(1, op0.size(), 'no opp with the specified txnid');			
		*/
	}

	static testMethod void testRecurring() {
		insert new Contact(firstName = 'EvanTest', lastName = 'CallahanTest', 
			email = 'evantest@groundwiretest.org');
		
		test.startTest();
		
		OnlinePaymentWebservice.PaymentInfo p = new OnlinePaymentWebservice.PaymentInfo();
		p.firstname = 'EvanTest';
		p.lastname = 'CallahanTest';
		p.email = 'evantest@groundwiretest.org';
		p.txnId = 'X0X0X';
		p.totalAmount = 1234;
		p.pmtPeriod = OnlinePayment.RecurringPeriod.MONTH;
		p.frequency = 1;
		p.recurringTxnId = 'Y0Y0Y';
		p.phone = '(123) 555-1212';
		
		OnlinePaymentWebservice.Item i = new OnlinePaymentWebservice.Item();
		i.name = 'Gift';
		i.amount = 1234;
		p.itemList = new list<OnlinePaymentWebservice.Item>{ i };
		
		// set up the payments
		OnlinePaymentWebservice.Response resp = OnlinePaymentWebservice.startRecurringPayments( p );
		system.assert(resp.success, 'startRecurringPayments returned fail');
		
		string rtid = p.recurringTxnId;
		system.assert(rtid != null, 'No recurring txn id.');

		/*
		// look for the payment
		GWBase__oppPayment__c[] op0 = [select id, GWBase__paid__c, GWBase__amount__c, GWBase__isinstallment__c from GWBase__oppPayment__c 
			where GWBase__opportunity__r.GWBase__recurring_payment_profile__r.GWBase__Transaction_Id__c = 'Y0Y0Y' order by GWBase__date__c];
		system.assert(op0.size() > 0, 'no payments found');			
		system.assertEquals(false, op0[0].GWBase__paid__c, 'paid is set when it should not be');			
		*/
		
		// log an authorized payment
		p.pmtStatus = OnlinePayment.PaymentStatus.AUTHORIZED;
		resp = OnlinePaymentWebservice.processRecurringPayment( p );
		system.assert(resp.success, 'processRecurringPayment returned fail on create/authorize');
		
		/*
		// look for the payment
		GWBase__oppPayment__c[] op2 = [select id, GWBase__paid__c, GWBase__amount__c, GWBase__isinstallment__c from GWBase__oppPayment__c 
			where GWBase__opportunity__r.GWBase__recurring_payment_profile__r.GWBase__Transaction_Id__c = 'Y0Y0Y' order by GWBase__date__c];
		system.assertEquals(false, op2[0].GWBase__paid__c, 'paid is set when it should not be');			
		*/
		
		// log actual payment success
		p.pmtStatus = OnlinePayment.PaymentStatus.COMPLETED;
		resp = OnlinePaymentWebservice.processRecurringPayment( p );
		system.assert(resp.success, 'processRecurringPayment returned fail on fulfilled payment');
		
		/*
		// look for the payment
		GWBase__oppPayment__c[] op3 = [select id, GWBase__paid__c, GWBase__amount__c, GWBase__isinstallment__c from GWBase__oppPayment__c 
			where GWBase__opportunity__r.GWBase__recurring_payment_profile__r.GWBase__Transaction_Id__c = 'Y0Y0Y' order by GWBase__date__c];
		system.assertEquals(true, op3[0].GWBase__paid__c, 'paid is not set properly');			
		*/
		
		// cancel the rest
		resp = OnlinePaymentWebservice.cancelRecurringPayments( p );
		system.assert(resp.success, 'cancelRecurringPayments returned fail');
		/*
		// look for the payment
		Opportunity[] op4 = [select id from Opportunity 
			where GWBase__recurring_payment_profile__r.GWBase__Transaction_Id__c = 'Y0Y0Y' and isClosed = false];
		system.assertEquals(0, op4.size(), 'unpaid payments exist on canceled subscr');
		*/		
	}

}