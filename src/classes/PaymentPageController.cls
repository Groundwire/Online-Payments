global with sharing virtual class PaymentPageController {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
-----------------------------------------------------------------------------------------------*/

	// properties
	global list<SelectOption> configOptions { get; private set; }
	global list<SelectOption> expMonths { get; private set; }
	global list<SelectOption> expYears { get; private set; }
	
	global string selectedConfig { get; set; }
	global string whatToDo { get; set; }
	global boolean success { get; set; }
	global OnlinePayment.OnlinePayer payer { get; set; }
	global OnlinePayment.CreditCardData card { get; set; }
	global OnlinePayment.PaymentData payment { get; set; }
	global string itemName { get; set; }
	global string pmtPeriod { get; set; }
	global string amountText { get; set; }
	global string txnId { get; set; }
	
	// results
	global OnlinePayment.OnlineTxnResult result { get; set; }
	global OnlinePayment.PaymentTxnResult paymentResult { get; set; }
	global OnlinePayment.PaymentProfileResult recurringResult { get; set; }
	global string errText { get; private set; }

	protected map<string, Payment_API_Config__c> configSettingsMap;

	// constructor
	global PaymentPageController() {
		
		// load payment processor settings and find the default
		configSettingsMap = Payment_API_Config__c.getAll();
		if (configSettingsMap == null) configSettingsMap = new map<string, Payment_API_Config__c>();
		configOptions = new list<selectOption>();
		for (Payment_API_Config__c pac : configSettingsMap.values()) {
			configOptions.add(new selectOption( pac.name, pac.name ));
			if (pac.default_connection__c == true)
				selectedConfig = pac.name;
		}
		
		whatToDo = 'paynow';
		expMonths = new list<selectOption>();
		for (integer i = 1; i <= 12; i++)
			expMonths.add(new selectOption( string.valueOf(i), string.valueOf(i) ));
		expYears = new list<selectOption>();
		for (integer i = 0; i < 8; i++)
			expYears.add(new selectOption( string.valueOf(system.today().year() + i), string.valueOf(system.today().year() + i) ) );

		payer = new OnlinePayment.OnlinePayer();
		payer.firstName = 'Testy';
		payer.lastName = 'Tester';
		OnlinePayment.AddressData address = new OnlinePayment.AddressData('1234 56th', 'Seattle', 'WA', '98101', 'USA', null);
		payer.billingAddress = address;
		card = new OnlinePayment.CreditCardData('Visa', '1111222233334444', null, null, null);
		payment = new OnlinePayment.PaymentData( null, null, null, 1 );
		pmtPeriod = 'months';
		
	} 
	
	// boolean property that sets whatToDo to paylater (can be used to drive a checkbox)
	global boolean payLater { get;
		set {
		    if (value) { whatToDo = 'paylater'; }
		}
	}
	
	
	protected OnlinePayment.APIAuthorization getAuth( string configName ) {
		OnlinePayment.APIAuthorization auth;
		if (configSettingsMap.containsKey(configName)) {
			Payment_API_Config__c config = configSettingsMap.get( configName );
			auth = new OnlinePayment.APIAuthorization(
				config.login_id__c, config.password__c, config.signature__c, 
				OnlinePayment.getRemoteHost(), config.sandbox__c 
			);
		}
		return auth;
	}
	
	// make a test payment
	global virtual pageReference submitToPaymentProcessor() {
		
		// Do some basic validation in case they don't have javascript (and in order to avoid )
		string invalid;
		try {
			payment.totalAmount = decimal.valueOf(amountText.replaceAll('$', '').replaceAll(',', ''));
		} catch(exception ex) {
			invalid = 'Amount must be numeric.';
		}
		if (invalid == null) {
			if (card.acctNumber != null) card.acctNumber = card.acctNumber.replaceAll(' ', '').replaceAll('-', '');
			invalid = 
				(payment.totalAmount == null) ? 'Please provide an amount.' : 
				(payment.totalAmount < 0) ? 'Amount cannot be negative.' : 
				(card.cvvCode != null && card.cvvCode.length() != 3) ? 'CVV code must be three digits.' : 
				(card.acctNumber == null) ? 'Please provide a credit card number.' : 
				(card.acctNumber.length() < 12 || card.acctNumber.length() > 19) ? 'Card must be between 12 and 19 digits.' :
				(payer.firstname == null) ? 'Please provide a first name.' : 
				(payer.lastname == null) ? 'Please provide a last name.' : 
				(payer.billingaddress.street == null || 
					payer.billingaddress.city == null || 
					payer.billingaddress.state == null || 
					payer.billingaddress.zip == null) ? 'Please provide a complete address.' : 
				null;
		}
		if (selectedConfig == null) {
			invalid = 'Please select a payment processor configuration.';
		}
		if (invalid != null) {
			apexPages.addmessage(new ApexPages.Message(ApexPages.Severity.ERROR, invalid));
			return null;
		}
		
		paymentResult = null;
		recurringResult = null;
		string processor = configSettingsMap.get(selectedConfig).processor__c;
		payment.pmtProcessor = (processor == 'Paypal') ? 
			OnlinePayment.Processor.PAYPAL : OnlinePayment.Processor.AUTHNET;
		
		//call the method to build the itemlist
		constructItems(); 
		
		try {
			OnlinePayment.APIAuthorization auth = getAuth( selectedConfig );
			OnlinePayment op = new OnlinePayment(auth);
			list<OnlinePayment.OnlineTxnMessage> msgs;
			string errorMsg;
			if (whatToDo == 'paynow') {
				paymentResult = op.SinglePayment( payer, card, payment, false, false, true );					
				msgs = paymentResult.messages;
				errorMsg = paymentResult.errorMessage;
				success = paymentResult.success;
			} else if (whatToDo == 'paylater') {
				payment.pmtPeriod = 
					(pmtPeriod == 'days') ? OnlinePayment.RecurringPeriod.DAY :
					(pmtPeriod == 'weeks') ? OnlinePayment.RecurringPeriod.WEEK :
					(pmtPeriod == 'years') ? OnlinePayment.RecurringPeriod.YEAR :
					OnlinePayment.RecurringPeriod.MONTH;
				recurringResult = op.RecurringPayment( payer, card, payment, true );
				msgs = recurringResult.messages;
				errorMsg = recurringResult.errorMessage;
				success = recurringResult.success;
			} else {
				result = op.getTransactionDetails(payment, txnId );
				msgs = result.messages;
				errorMsg = result.errorMessage;
				success = result.success;
			}
			
			// display result
			if (errorMsg == null)
				apexPages.addmessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Transaction successful.'));				
			else
				apexPages.addmessage(new ApexPages.Message(ApexPages.Severity.ERROR, errorMsg));

			string errString = '';
			for (OnlinePayment.OnlineTxnMessage e : msgs) {
				string sMsg = ((e.shortMessage != null) ? (e.shortMessage + '. ') : '') + 
					((e.longMessage != null) ? (e.longMessage + ' ') : '');
				errString += 'Error #' + e.code + ((sMsg == '') ? '' : ': ' + sMsg);
			}
			errText =  (errString == null) ? null : errString;
			
		} catch (exception e) {
			string errMsg = e.getMessage() +
				((e.getLineNumber() == null) ? '' : ' (' + e.getLineNumber() + ')') + 
				((e.getCause() == null) ? '' : '\n' + e.getCause());
			
			apexPages.addmessage(new ApexPages.Message(ApexPages.Severity.ERROR, errMsg));		
			throw new onlinepayment.OnlinePaymentException( errMsg );	
		}
		
		return null;
	}
	
	global virtual void constructItems() {
		if (itemName != null && itemName != '') {
			payment.itemList = new list<OnlinePayment.Item> {
				new OnlinePayment.Item(itemName, null, '0', 1, payment.totalAmount, null, null) };
		}
	}
	
	// make messages available to page
	public list<ApexPages.Message> getMessages() {
    	return ApexPages.getMessages();
    }
	
	static testMethod void testPPC() {
		// ensure we have a config to test against.
		Payment_API_Config__c config = new Payment_API_Config__c();
		config.processor__c = 'Paypal';
		config.Default_Connection__c = true;
		config.Login_Id__c = 'my login id';
		config.name = 'config for testing';
		insert config;
		
		PaymentPageController ppc = new PaymentPageController();
		ppc.amountText = '10.00';
		ppc.submitToPaymentProcessor();
		string txnId = ppc.paymentResult.txnId;
		system.assert( ppc.paymentResult != null );
		system.assert( ppc.success == true );
	}
	
	static testMethod void testPPC_PayLater() {
		// ensure we have a config to test against.
		Payment_API_Config__c config = new Payment_API_Config__c();
		config.processor__c = 'Authnet';
		config.Default_Connection__c = true;
		config.Login_Id__c = 'my login id';
		config.name = 'config for testing';
		insert config;

		PaymentPageController ppc = new PaymentPageController();
		ppc.amountText = '10.00';
		ppc.payLater = true;
		ppc.submitToPaymentProcessor();
		system.assert(ppc.success == true);
		system.assert(ppc.recurringResult != null);
	}
	
}