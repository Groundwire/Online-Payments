/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description Page controller for the Payment Testing visualforce page.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/

global with sharing virtual class PaymentPageController {

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
    global string amountText2 { get; set; }
    global OnlinePayment.CreditCardData card2 { get; set; } 

	// for use on a custom page, such as a refund page
    global string transactionName { get; private set; }
    global boolean defaultIsPaypal { get; private set; }
    global decimal maxAmount { get; private set; }
    
    // results
    global OnlinePayment.OnlineTxnResult result { get; set; }
    global OnlinePayment.PaymentTxnResult paymentResult { get; set; }
    global OnlinePayment.PaymentProfileResult recurringResult { get; set; }
    global string errText { get; private set; }

	PaymentApiConfig apiConfig;
	
    // constructor
    global PaymentPageController() {
        apiConfig = new PaymentApiConfig();
        defaultIsPaypal = ( apiConfig.defaultProcessor.payment_processor__c == 'Paypal' );
        
        configOptions = new list<selectOption>();
        for (string s : apiConfig.processorMap.keyset()) 
            configOptions.add(new selectOption( s, s ));
        selectedConfig = apiConfig.defaultProcessor.name;
        		
		// set up expiration picklists
        expMonths = new list<selectOption>();
        for (integer i = 1; i <= 12; i++)
            expMonths.add(new selectOption( string.valueOf(i), string.valueOf(i) ));
        expYears = new list<selectOption>();
        for (integer i = 0; i < 8; i++)
            expYears.add(new selectOption( string.valueOf(system.today().year() + i), string.valueOf(system.today().year() + i) ) );

		// initialize objects
        payer = new OnlinePayment.OnlinePayer();
        card = new OnlinePayment.CreditCardData('Visa', null, null, null, null);
        card2 = new OnlinePayment.CreditCardData('Visa', null, null, null, null);
        payment = new OnlinePayment.PaymentData( null, null, null, 1 );

		// look for page parameters passed in querystring
		if (ApexPages.currentPage() != null) {
			map<string,string> params = ApexPages.currentPage().getParameters();
			
			whatToDo = params.get('action');  
			txnId = params.get('txnid');
			transactionName = params.get('title');
			amountText = params.get('amount');
			amountText2 = params.get('amount');
			card.acctNumber = params.get('cc');
			card.expMonth = params.get('month');
			card.expYear = params.get('year');
			card2.acctNumber = params.get('cc');
			card2.expMonth = params.get('month');
			card2.expYear = params.get('year');
	        try {
	            maxAmount = decimal.valueOf(amountText2.replaceAll('$', '').replaceAll(',', ''));
	        } catch(exception ex) { }
		}                        			
		if (whatToDo == null) whatToDo = 'paynow';		
    } 
    
    // boolean property that sets whatToDo to paylater (can be used to drive a checkbox)
    global boolean payLater { get;
        set {
            whatToDo = (value) ? 'paylater' : 'paynow';
        }
    }
    
    // make a test payment
    global virtual pageReference submitToPaymentProcessor() {
        success = false;
        
        // Do some basic validation in case they don't have javascript (and in order to avoid )
        string invalid;
        if (whatToDo == 'paynow' || whatToDo == 'paylater' || whatToDo == 'auth') {
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
	                (card.cvvCode != null && card.cvvCode.length() > 4) ? 'CVV code must be three or four digits.' : 
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
        } else {
        	if (txnId == null) {
        		invalid = 'Please provide a transaction ID.';	
        	}
        	if (amountText2 != null && amountText2.trim() != '') {
		        try {
		            payment.totalAmount = decimal.valueOf(amountText2.replaceAll('$', '').replaceAll(',', ''));
		        } catch(exception ex) {
		            invalid = 'Amount must be numeric.';
		        }
		        if (payment.totalAmount != null && maxAmount != null && payment.totalAmount > maxAmount) {
		        	invalid = 'Please enter an amount no more than ' + string.valueOf(maxAmount) + '.';
		        }
        	}
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
        
        payment.pmtProcessor = (apiConfig.getProcessor( selectedConfig ) == 'Paypal') ? 
            OnlinePayment.Processor.PAYPAL : OnlinePayment.Processor.AUTHNET;
        
        //call the method to build the itemlist
        constructItems(); 
        
        try {
            OnlinePayment.APIAuthorization auth = apiConfig.getAuth( selectedConfig );
            OnlinePayment op = new OnlinePayment(auth);
            list<OnlinePayment.OnlineTxnMessage> msgs;
            string errorMsg;
            if (whatToDo == 'paynow' || whatToDo == 'auth') {
            	payment.action = (whatToDo == 'paynow') ? OnlinePayment.PaymentAction.PAY : OnlinePayment.PaymentAction.AUTHORIZE;
                paymentResult = op.DoSinglePayment( payer, card, payment);                  
                msgs = paymentResult.messages;
                errorMsg = paymentResult.errorMessage;
                success = paymentResult.success;
            } else if (whatToDo == 'paylater') {
                payment.pmtPeriod = 
                    (pmtPeriod == 'days') ? OnlinePayment.RecurringPeriod.DAY :
                    (pmtPeriod == 'weeks') ? OnlinePayment.RecurringPeriod.WEEK :
                    (pmtPeriod == 'years') ? OnlinePayment.RecurringPeriod.YEAR :
                    OnlinePayment.RecurringPeriod.MONTH;
                recurringResult = op.CreateRecurringPayment( payer, card, payment );
                msgs = recurringResult.messages;
                errorMsg = recurringResult.errorMessage;
                success = recurringResult.success;
            } else if (whatToDo == 'getdetails') {
                result = op.getTransactionDetails( payment, txnId );
                msgs = result.messages;
                errorMsg = result.errorMessage;
                success = result.success;
            } else if (whatToDo == 'void') {
            	payment.txnId = txnId;
                result = op.voidPayment( payment );
                msgs = result.messages;
                errorMsg = result.errorMessage;
                success = result.success;
            } else if (whatToDo == 'refund') {
            	payment.txnId = txnId;
            	
            	// for paypal, full refunds should not include the amount
            	if (payment.pmtProcessor == OnlinePayment.Processor.PAYPAL && payment.totalAmount == maxAmount)
            		payment.totalAmount = null;
            		 
                result = op.refundPayment( payment, card2 );
                msgs = result.messages;
                errorMsg = result.errorMessage;
                success = result.success;
            } else {
            	system.assert(false, 'No payment action was specified.');
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
            // don't throw.  handle it so error displayed on page.
            //throw new onlinepayment.OnlinePaymentException( errMsg ); 
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
    global virtual list<ApexPages.Message> getMessages() {
        return ApexPages.getMessages();
    }
    
    static testMethod void testPPC() {

        // setup dummy data
        PaymentPageController ppc = new PaymentPageController();
        ppc.submitToPaymentProcessor();
        system.assert( !ppc.success );
        
        ppc.payer.firstName = 'Testy';
        ppc.payer.lastName = 'Tester';
        OnlinePayment.AddressData address = new OnlinePayment.AddressData('1234 56th', 'Seattle', 'WA', '98101', 'USA', null);
        ppc.payer.billingAddress = address;
        ppc.card = new OnlinePayment.CreditCardData('Visa', '1111222233334444', null, null, null);
        ppc.payment = new OnlinePayment.PaymentData( null, null, null, 1 );
        ppc.pmtPeriod = 'months';        
        ppc.amountText = '10.00';
        ppc.submitToPaymentProcessor();
        system.assert( ppc.paymentResult != null );
        system.assert( ppc.success == true );
    }
    
    static testMethod void testPPC_PayLater() {

        PaymentPageController ppc = new PaymentPageController();
        ppc.payer.firstName = 'Testy';
        ppc.payer.lastName = 'Tester';
        OnlinePayment.AddressData address = new OnlinePayment.AddressData('1234 56th', 'Seattle', 'WA', '98101', 'USA', null);
        ppc.payer.billingAddress = address;
        ppc.card = new OnlinePayment.CreditCardData('Visa', '1111222233334444', null, null, null);
        ppc.payment = new OnlinePayment.PaymentData( null, null, null, 1 );
        ppc.pmtPeriod = 'months';        
        ppc.amountText = '10.00';
        ppc.submitToPaymentProcessor();
        ppc.amountText = '10.00';
        ppc.payLater = true;
        ppc.submitToPaymentProcessor();
        system.assert(ppc.success == true);
        system.assert(ppc.recurringResult != null);
    }

    static testMethod void testPPC_getinfo() {

		// try the get details option
        PaymentPageController ppc = new PaymentPageController();
		ppc.whatToDo = 'getdetails';
		ppc.txnId = 'my txnid';
        ppc.submitToPaymentProcessor();
        system.assert( ppc.result != null );
        system.assert( ppc.success );
    }
 
    static testMethod void testPPC_refund() {

        // setup dummy data
        Test.setCurrentPage(Page.PaymentRefund);
        ApexPages.currentPage().getParameters().put('action','refund');
        ApexPages.currentPage().getParameters().put('txnid','my txnid');
        ApexPages.currentPage().getParameters().put('amount','123.45');
        PaymentPageController ppc = new PaymentPageController();
        system.assertEquals( 'my txnid', ppc.txnId );

		// cause a validation error
 		ppc.amountText2 = '555';
        ppc.submitToPaymentProcessor();
        system.assert( !ppc.success );
		system.assertEquals( 'Please enter an amount no more than 123.45.', apexpages.getMessages()[0].getSummary() );

		// fix the amount and submit for refund
		ppc.amountText2 = '123.45';
        ppc.submitToPaymentProcessor();
        system.assert( ppc.result != null );
        system.assert( ppc.success );

		// void as well, for coverage
		ppc.whatToDo = 'void';
		ppc.submitToPaymentProcessor();
        system.assert( ppc.success );
    }
}