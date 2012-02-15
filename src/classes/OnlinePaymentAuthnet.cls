/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description Authnet class containing data structures and utilities for online payment processing.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/

global virtual with sharing class OnlinePaymentAuthnet extends OnlinePayment { 

	/*
	TODO: 
	In testing, should check encoding - e.g. accented chars

	FUTURE:
	- More methods from all APIs (e.g. update and cancel calls)
	- Support echeck?
	- Support authnet batches?
	*/

	// xml endpoints
	static final string PRODUCTION_ENDPOINT = 'https://api.authorize.net/xml/v1/request.api';
	static final string SANDBOX_ENDPOINT = 'https://apitest.authorize.net/xml/v1/request.api';
	
	// constructor
	global OnlinePaymentAuthnet( APIAuthorization authnetAuth ) {
		super( authnetAuth );

		// if the auth was null, try to get default settings
		if ( auth == null && !setDefaultProcessor( 'Authnet' ) ) {
			throw new OnlinePaymentException('No default payment processor configuration was found for Authorize.net. To create one, go to the Configure Payments tab (or talk to your system administrator).');
		}
		
		endpoint = (auth.sandbox) ? SANDBOX_ENDPOINT : PRODUCTION_ENDPOINT;
 	}

	protected XMLEncoder getEncoder( string requestType ) {

		XMLEncoder encoder = new XMLEncoder( requestType );

		if (auth != null) {
			encoder.openGroup('merchantAuthentication');
			encoder.addElement('name', auth.loginId);
			encoder.addElement('transactionKey', auth.password);
			encoder.closeGroup();
			//encoder.addElement('refId', );
		}
		return encoder;
	}
	
	public class TestException extends Exception {}

	global virtual PaymentTxnResult CreateTransactionRequest( OnlinePayer payer, CreditCardData card, PaymentData payment, 
		boolean testRequest, boolean emailCustomer, boolean fLog ) {
		
		// declare all variables before we do the try/catch, so we can access things afterwards.
		XMLEncoder encoder;
		OnlineTxnResult baseResult = new OnlineTxnResult(false, null);
		PaymentTxnResult result = new PaymentTxnResult(); 
		ID oppId;
		
		try {
			// build the URL
			encoder = getEncoder('createTransactionRequest');
	
			// top section
			encoder.openGroup('transactionRequest');
			encoder.addElement('transactionType', 
				(payment.action == null || payment.action == PaymentAction.PAY) ? 
					'authCaptureTransaction' : 'authOnlyTransaction');
			encoder.addElement('amount', payment.totalAmount);
	
			// payment section
			encoder.openGroup('payment');
			if (card != null && card.acctNumber != null) {
				encoder.openGroup('creditCard');
				//encoder.addElement('track1',);
				//encoder.addElement('track2',);
				encoder.addElement('cardNumber',  card.acctNumber);
				if (card.expMonth != null && card.expYear != null)
					encoder.addElement('expirationDate', card.expMonth + ((card.expYear.length()==2) ? '20' : '') + card.expYear);
				encoder.addElement('cardCode', card.cvvCode);
				encoder.closeGroup();
			}
			/* if (bank != null && bank.accountNumber != null) {
				encoder.openGroup('bankAccount');
				encoder.addElement('accountNumber', bank.acctNumber);
				encoder.addElement('routingNumber', );
				encoder.addElement('nameOnAccount', );
				encoder.addElement('bankName', );
				encoder.addElement('echeckType', );
				encoder.closeGroup();
			} */
			//encoder.addElement('authCode',);
			//encoder.addElement('refTransId',);
			//encoder.addElement('splitTenderId',);
			encoder.closeGroup();
	
			// order
			string descrip = 
				(payment.memo != null) ? payment.memo : 
				(payment.itemList != null && payment.itemList.size() == 1) ?
				((payment.itemList[0].description != null) ? payment.itemList[0].description : 
				payment.itemList[0].name) : null ;		
			if (payment.invoice != null || descrip != null) {
				encoder.openGroup('order');
				if (payment.invoice != null)
					encoder.addElement('invoiceNumber', payment.invoice);
				if (payment.memo != null)				
					// hack to test exception handling!!
					//if (payment.memo == 'cause exception') {
					//	throw (new TestException('you asked, we delivered: your exception in CreateTransactionRequest!'));
					//}			
					encoder.addElement('description', descrip);
				encoder.closeGroup();
			}
			
			// items
			if (!payment.itemList.isEmpty()) {
				encoder.openGroup('lineItems');
				for (Item item : payment.itemList) {					
					encoder.openGroup('lineItem');
					encoder.addElement('itemId', (item.code != null) ? item.code : '0');
					encoder.addElement('name', (item.name != null && item.name != '') ? item.name : '[unknown item]');
					encoder.addElement('description', item.description);
					encoder.addElement('quantity', (item.quantity != null) ? item.quantity : 1);
					encoder.addElement('unitPrice', (item.amount != null) ? item.amount : 0);
					encoder.closeGroup();
				}
				encoder.closeGroup();
			}
	
			if (payment.tax != null) {
				encoder.openGroup('tax');
				encoder.addElement('amount', payment.tax);
				encoder.addElement('name', 'Tax');
				//encoder.addElement('description', );
				encoder.closeGroup();
			}
			/* if (payment.duty != null) {
				encoder.openGroup('duty');
				encoder.addElement('amount', duty.shipping);
				encoder.addElement('name', 'Duty');
				//encoder.addElement('description', );
				encoder.closeGroup();
			} */
			if (payment.shipping != null) {
				encoder.openGroup('shipping');
				encoder.addElement('amount', payment.shipping);
				encoder.addElement('name', 'Shipping');
				//encoder.addElement('description', );
				encoder.closeGroup();
			}
			//encoder.addElement('taxExempt',);
			//encoder.addElement('poNumber',);
			
			// customer
			encoder.openGroup('customer');
			//encoder.addElement('type', (payment.companyIsPayer) ? 'Business' : 'Individual');
			//encoder.addElement('id',);
			encoder.addElement('email', payer.email);
			encoder.closeGroup();
				
			if (payer.billingAddress != null) {
				encoder.openGroup('billTo');
				encoder.addElement('firstName', payer.firstName);
				encoder.addElement('lastName', payer.lastName);
				encoder.addElement('company', payer.companyName);
				encoder.addElement('address', payer.billingAddress.street);
				encoder.addElement('city', payer.billingAddress.city);
				encoder.addElement('state', payer.billingAddress.state);
				encoder.addElement('zip', payer.billingAddress.zip);
				encoder.addElement('country', payer.billingAddress.country);
				encoder.addElement('phoneNumber', (payer.shippingAddress == null || payer.shippingAddress.phone == null) ? payer.billingAddress.phone : payer.shippingAddress.phone);
				//encoder.addElement('faxNumber', payer.fax);
				encoder.closeGroup();
			}
			
			if (payer.shippingAddress != null && payer.shippingAddress.street != null) {
				encoder.openGroup('shipTo');
				encoder.addElement('firstName', payer.firstName);
				encoder.addElement('lastName', payer.lastName);
				encoder.addElement('company', payer.companyName);
				encoder.addElement('address', payer.shippingAddress.street);
				encoder.addElement('city', payer.shippingAddress.city);
				encoder.addElement('state', payer.shippingAddress.state);
				encoder.addElement('zip', payer.shippingAddress.zip);
				encoder.addElement('country', payer.shippingAddress.country);
				encoder.closeGroup();
			}
	
			if (auth.remoteIpAddress != null)
				encoder.addElement('customerIP', auth.remoteIpAddress);
				
			encoder.openGroup('transactionSettings');
			encoder.openGroup('setting');
			encoder.addElement('settingName', 'testRequest');
			encoder.addElement('settingValue', (testRequest) ? 'true' : 'false');
			encoder.closeGroup();
			encoder.openGroup('setting');
			encoder.addElement('settingName', 'emailCustomer');
			encoder.addElement('settingValue', (emailCustomer) ? 'true' : 'false');
			encoder.closeGroup();
			encoder.closeGroup();
	
			if (payment.custom != null) {
				encoder.openGroup('userFields');
				encoder.openGroup('userField');
				encoder.addElement('name', 'custom');
				encoder.addElement('value', payment.custom);
				encoder.closeGroup();
				encoder.closeGroup();
			}
	
			// make the call
			baseResult = callAuthnet( encoder.xml );
			
			// get all the result data
			string responseCode;
			string authCode;
			string avsResultCode;
			string cavvResultCode;
			string transId;
			string accountNumber;
			string accountType;
			string transHash;
			
			XMLDecoder decoder = new XMLDecoder( baseResult.responseText );
			
			if ( decoder.openGroup('transactionResponse') ) {
				responseCode = decoder.getElement('responseCode');
				authCode = decoder.getElement('authCode');
				avsResultCode = decoder.getElement('avsResultCode');
				cavvResultCode = decoder.getElement('cavvResultCode');
				transId = decoder.getElement('transId');
				accountNumber = decoder.getElement('accountNumber');
				accountType = decoder.getElement('accountType');
				transHash = decoder.getElement('transHash');
			}
				
	 		result = new PaymentTxnResult(
				baseResult.success, baseResult.responseText, transId, responseCode, authCode, transHash, 
				accountNumber, accountType, avsResultCode, cavvResultCode, baseResult.errorMessage, baseResult.messages );
	
			if (decoder.openGroup('userFields')) {
				integer i = 0;
				while (decoder.openGroup('userField', i)) {
					result.userFields.put(decoder.getElement('name'), decoder.getElement('value'));
					decoder.closeGroup();
					i++; 
				}
				decoder.closeGroup();
			}
					
			// put authnet data into payment object
			payment.txnId = transId;	
			
			// set payment status to correct state
			if (result.success) {
				payment.pmtStatus = (payment.action == OnlinePayment.PaymentAction.AUTHORIZE) ? 
					OnlinePayment.PaymentStatus.AUTHORIZED : OnlinePayment.PaymentStatus.COMPLETED;
			} else {
				payment.pmtStatus = OnlinePayment.PaymentStatus.FAILED;
			}		
			
			if (result.success) {
				// process the log to create opportunities.
		        // use the generic payment processing class
		    	ClassFactory f = new ClassFactory();
		    	PaymentToSalesforce opmt = f.makePaymentToSalesforce();
		        opmt.payer = payer;
		        opmt.payment = payment;
				
		        opmt.processSinglePayment();
				oppId = opmt.opportunityId;
		        result.dbSuccess = true;                    
			}
		} catch (exception ex) {
			result.errorMessage = ex.getMessage();
			result.errorStackTrace = ex.getStackTraceString();
			result.errorLineNumber = ex.getLineNumber();	
			// fall thru to log the ipn, and return the result object.		
		}	
			                        
        // log the ipn record
        if (fLog) {
			boolean isTest = auth.sandbox || testRequest; 
			Payment_Notification__c ipn = logNotification(payer, payment, 'Apex Payment Callout', payment.action, 
				encoder == null ? null : strXmlScrub(encoder.xml), 
				baseResult.responseText, isTest, false, result.errorMessage, false);	
			ipn.Transaction_Type__c = 'Authnet CreateTransactionRequest()';
            ipn.isProcessed__c = result.dbSuccess == null ? false : result.dbSuccess;  
            ipn.opportunity__c = oppId;
            ipn.errorLineNumber__c = result.errorLineNumber;
            ipn.errorStackTrace__c = result.errorStackTrace;
        	insert ipn;
        }

		return result;
	}

	global virtual OnlineTxnResult VoidTransaction( string txnId, boolean fLog) {
		OnlineTxnResult result = new OnlineTxnResult(false, null);
		try {

			// build the URL
			XMLEncoder encoder = getEncoder('createTransactionRequest');
	
			// top section
			encoder.openGroup('transactionRequest');
			encoder.addElement('transactionType', 'voidTransaction');
			encoder.addElement('refTransId', txnId);
	
			// make the call
			 result = callAuthnet( encoder.xml );
		} catch (exception ex) {
			result.success = false;
			result.errorMessage = ex.getMessage();
			result.errorStackTrace = ex.getStackTraceString();
			result.errorLineNumber = ex.getLineNumber();	
			// fall thru to log the ipn, and return the result object.		
		}	
		
		// log the failure.
		if (fLog) {
			PaymentData payment = new PaymentData(0);
			payment.pmtProcessor = Processor.AUTHNET;
			payment.action = PaymentAction.VOIDTXN;
			payment.pmtStatus = result.success ? PaymentStatus.COMPLETED : null;
			payment.txnId = txnId;
			
			Payment_Notification__c ipn = logNotification(null, payment, 'Apex Payment Callout', payment.action, null, 
				result.responseText, false, false, result.errorMessage, false);	
			ipn.Transaction_Type__c = 'Authnet VoidTransaction()';
			insert ipn;
		}
		return result;
	}

	global virtual PaymentProfileResult ARBCreateSubscriptionRequest( OnlinePayer payer, CreditCardData card, 
		PaymentData payment, boolean preAuthorize ) {
			
		// declare all variables before we do the try/catch, so we can access things afterwards.
		XMLEncoder encoder;
		OnlineTxnResult baseResult = new OnlineTxnResult(false, null);
		PaymentProfileResult result = new PaymentProfileResult(); 
		ID oppId;
		boolean isTest = auth.sandbox; 

		try {		
			// if the flag is set, first authorize the credit card and void
			if (preAuthorize) {
				Savepoint sp = Database.setSavepoint();
				PaymentAction saveAction = payment.action;
				payment.action = PaymentAction.AUTHORIZE;
				PaymentTxnResult authRequest = CreateTransactionRequest( payer, card, payment, false, false, false );
				payment.action = saveAction;
					
				if (!authRequest.success) {
					// log the failure.
					Payment_Notification__c ipn = logNotification(payer, payment, 'Apex Payment Callout', payment.action, null, 
						authRequest.responseText, isTest, false, authRequest.errorMessage, false);	
		            ipn.errorLineNumber__c = authRequest.errorLineNumber;
		            ipn.errorStackTrace__c = authRequest.errorStackTrace;
					ipn.Transaction_Type__c = 'Authnet ARBCreateSubscriptionRequest()';
					insert ipn;
					
			 		result = new PaymentProfileResult(authRequest.success, authRequest.responseText, null, 
			 			authRequest.errorMessage, authRequest.messages);
					result.errorLineNumber = authRequest.errorLineNumber;
					result.errorStackTrace = authRequest.errorStackTrace;
					return result;
				} else {
					//this rollback is to enable the callout to happen.  You can't make a callout when there are uncommitted
					//database changes, which we get when attempting to preauthorize an ARB
					Database.Rollback( sp );
					// void
					OnlineTxnResult voidRequest = VoidTransaction( authRequest.txnId, false );
				}
				
			}
	
			// build the URL
			encoder = getEncoder('ARBCreateSubscriptionRequest');
	
			// top section
			encoder.openGroup('subscription');
			encoder.openGroup('paymentSchedule');
			
			encoder.openGroup('interval');		
			if (payment.pmtPeriod == RecurringPeriod.YEAR) {
				encoder.addElement('length', 12 * ((payment.frequency != null) ? payment.frequency : 1));
				encoder.addElement('unit', 'months');
			} else if (payment.pmtPeriod == RecurringPeriod.WEEK) {
				encoder.addElement('length', 7 * ((payment.frequency != null) ? payment.frequency : 1));
				encoder.addElement('unit', 'days');
			} else if (payment.pmtPeriod == RecurringPeriod.DAY) {
				encoder.addElement('length', (payment.frequency != null) ? payment.frequency : 1);
				encoder.addElement('unit', 'days');
			} else {
				encoder.addElement('length', (payment.frequency != null) ? payment.frequency : 1);				
				encoder.addElement('unit', 'months');
			}
			encoder.closeGroup();
			
			encoder.addElement('startDate', (payment.startDate != null && payment.startDate >= system.today()) ?
				payment.startDate : system.today() );
			encoder.addElement('totalOccurrences', (payment.occurrences != null && payment.occurrences != 0) ? 
				payment.occurrences : 9999);
			//encoder.addElement('trialOccurrences', );
			encoder.closeGroup();
			
			// payment section
			encoder.addElement('amount', payment.totalAmount);
			//encoder.addElement('trialAmount', );
			encoder.openGroup('payment');
			if (card != null && card.acctNumber != null) {
				encoder.openGroup('creditCard');
				//encoder.addElement('track1',);
				//encoder.addElement('track2',);
				encoder.addElement('cardNumber',  card.acctNumber);
				if (card.expMonth != null && card.expYear != null)
					encoder.addElement('expirationDate', card.expMonth + ((card.expYear.length()==2) ? '20' : '') + card.expYear);
				encoder.addElement('cardCode', card.cvvCode);
				encoder.closeGroup();
			}
			/* if (bank != null && bank.accountNumber != null) {
				encoder.openGroup('bankAccount');
				encoder.addElement('accountNumber', bank.acctNumber);
				encoder.addElement('routingNumber', );
				encoder.addElement('nameOnAccount', );
				encoder.addElement('bankName', );
				encoder.addElement('echeckType', );
				encoder.closeGroup();
			} */
			encoder.closeGroup();
	
			// order
			if (payment.invoice != null || payment.memo != null) {
				encoder.openGroup('order');
				if (payment.invoice != null)
					encoder.addElement('invoiceNumber', payment.invoice);
				if (payment.memo != null)
					// hack to test exception handling!!
					//if (payment.memo == 'cause exception') {
					//	throw (new TestException('you asked, we delivered: your exception in ARBCreateSubscriptionRequest!'));
					//}							
					encoder.addElement('description', payment.memo);
				encoder.closeGroup();
			}
			
			// customer
			encoder.openGroup('customer');
			//encoder.addElement('type', (payment.companyIsPayer) ? 'Business' : 'Individual');
			//encoder.addElement('id',);
			encoder.addElement('email', payer.email);
			encoder.addElement('phoneNumber', (payer.shippingAddress == null || payer.shippingAddress.phone == null) ? payer.billingAddress.phone : payer.shippingAddress.phone);
			//encoder.addElement('faxNumber', payer.fax);
			encoder.closeGroup();
			
			encoder.openGroup('billTo');
			encoder.addElement('firstName', payer.firstName);
			encoder.addElement('lastName', payer.lastName);
			encoder.addElement('company', payer.companyName);
			encoder.addElement('address', payer.billingAddress.street);
			encoder.addElement('city', payer.billingAddress.city);
			encoder.addElement('state', payer.billingAddress.state);
			encoder.addElement('zip', payer.billingAddress.zip);
			encoder.addElement('country', payer.billingAddress.country);
			encoder.closeGroup();
			
			if (payer.shippingAddress != null && payer.shippingAddress.street != null) {
				encoder.openGroup('shipTo');
				encoder.addElement('firstName', payer.firstName);
				encoder.addElement('lastName', payer.lastName);
				encoder.addElement('company', payer.companyName);
				encoder.addElement('address', payer.shippingAddress.street);
				encoder.addElement('city', payer.shippingAddress.city);
				encoder.addElement('state', payer.shippingAddress.state);
				encoder.addElement('zip', payer.shippingAddress.zip);
				encoder.addElement('country', payer.shippingAddress.country);
				encoder.closeGroup();
			}
	
			// make the call
			baseResult = callAuthnet( encoder.xml );
	
			// get the result		
			XMLDecoder decoder = new XMLDecoder( baseResult.responseText );
			string subscriptionId = decoder.getElement('subscriptionId');
			string transId = decoder.getElement('transId');
			
	 		result = new PaymentProfileResult(
				baseResult.success, baseResult.responseText, subscriptionId, baseResult.errorMessage, baseResult.messages);			
							
			// put authnet data into payment object
			payment.txnId = transId;	
			payment.recurringTxnId = subscriptionId;
	
			// set payment status to correct thing
			if (result.success) {
				payment.pmtStatus = (payment.action == OnlinePayment.PaymentAction.AUTHORIZE) ? 
					 OnlinePayment.PaymentStatus.AUTHORIZED : OnlinePayment.PaymentStatus.COMPLETED;
			} else {
				payment.pmtStatus = OnlinePayment.PaymentStatus.FAILED;
			}	
			
			if (result.success) {
		        // use the generic payment processing class
		    	ClassFactory f = new ClassFactory();
		    	PaymentToSalesforce opmt = f.makePaymentToSalesforce();
			    	                                              
		        opmt.payer = payer;
		        opmt.payment = payment;
	
		        opmt.startRecurringPayments();
	            oppId = opmt.opportunityId;   
	            result.dbSuccess = true;                 
			}
		} catch (exception ex) {
			result.errorMessage = ex.getMessage();
			result.errorStackTrace = ex.getStackTraceString();
			result.errorLineNumber = ex.getLineNumber();	
			// fall thru to log the ipn, and return the result object.		
		}	
									                        
		// create the log
		Payment_Notification__c ipn = logNotification(payer, payment, 'Apex Payment Callout', payment.action, 
			encoder == null ? null : strXmlScrub(encoder.xml), 
			baseResult.responseText, isTest, false, result.errorMessage, false);	

		// set other ipn fields common api doesn't handle
		ipn.Transaction_Type__c = 'Authnet ARBCreateSubscriptionRequest()';
        ipn.isProcessed__c = result.dbSuccess == null ? false : result.dbSuccess;  
        ipn.opportunity__c = oppId;
        ipn.errorLineNumber__c = result.errorLineNumber;
        ipn.errorStackTrace__c = result.errorStackTrace;
    	insert ipn;

		return result;
	}

	global OnlineTxnResult getTransactionDetails( string txnId ) {
		OnlineTxnResult result = new OnlineTxnResult(false, null);
	
		try {
			// build the xml
			XMLEncoder encoder = getEncoder('getTransactionDetailsRequest');
			encoder.addElement('transId', txnId); 
			result = callAuthnet( encoder.xml );		
		} catch (exception ex) {
			result.success = false;
			result.errorMessage = ex.getMessage();
			result.errorStackTrace = ex.getStackTraceString();
			result.errorLineNumber = ex.getLineNumber();	
			// fall thru and return the result object.		
		}	
		
		return result;
	}

	global virtual class PaymentTxnResult extends OnlinePayment.PaymentTxnResult {		
		global string responseCode { get; set; }
		global string authCode { get; set; }
		global string transHash { get; set; }
		global string accountNumber { get; set; }
		global string accountType { get; set; }
		map<string, string> userFields { get; set; }	
		
		global PaymentTxnResult() {
			super();
			userFields = new map<string, string>();				
		}
		
		global PaymentTxnResult( boolean fSuccess, string sXml, string sTxnId, string sResponseCode, string sAuthCode, string sTransHash, string sAccountNumber, string sAccountType, string sAvsResponse, string sCvvResponse, string sErrMsg, list<OnlineTxnMessage> sMsgs ) {
			super( fSuccess, sXml, sTxnId, sAvsResponse, sCvvResponse, sErrMsg, sMsgs );
			responseCode = sResponseCode;
			authCode = sAuthCode;
			transHash = sTransHash;
			accountNumber = sAccountNumber;
			accountType = sAccountType;
			userFields = new map<string, string>();	
		}
	}

	global virtual class PaymentProfileResult extends OnlinePayment.PaymentProfileResult {		
		global string xml { get; set; }
		
		global PaymentProfileResult() {}
		
		global PaymentProfileResult( boolean fSuccess, string sXml, string sRecurringTxnId, string sErrMsg, list<OnlineTxnMessage> sMsgs ) {
			super( fSuccess, sXml, sRecurringTxnId, sErrMsg, sMsgs );
		}
	}

	protected OnlineTxnResult callAuthnet( string xml ) {

		string responseBody;
		list<OnlineTxnMessage> msgs = new list<OnlineTxnMessage>();

		try {
			Http h = new Http();
			HttpRequest req = new HttpRequest();
			req.setTimeout(60000);
			req.setMethod('POST');
			req.setEndpoint(endpoint);
			req.setHeader('Content-Type', 'text/xml');
			req.setBody(xml);
			//system.debug(logginglevel.warn, xml);
			HttpResponse resp = execute( h, req );
			responseBody = getResponseBody( resp );
			//system.debug(logginglevel.warn, responseBody);
		} catch (Exception ex){
			// we treat http errors as an authnet handled error, so that we will still
			// log the notification record appropriately.
			responseBody = '<?xml version="1.0" encoding="utf-8"?><ErrorResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">' + 
				'<messages><resultCode>Error</resultCode><message>' +  
				'<text>' + 'There was a communication problem with the payment processor, so your credit card was not charged. ' +
				'Error details: ' + ex.getMessage() + '</text></message></messages></ErrorResponse>';
		}
		XMLDecoder decoder = new XMLDecoder( responseBody );

		// success?
		boolean gMsgs = decoder.openGroup('messages');
		string resultCode = decoder.getElement('resultCode');
		if (decoder.openGroup('message')) {
			string mcode = decoder.getElement('code');
			if (mcode != 'I00001')
				msgs.add( new OnlineTxnMessage(
					mcode, null, decoder.getElement('text')	));
			decoder.closeGroup();
		}		
		if (gMsgs) decoder.closeGroup();
		
		// one of these two should be true
		string responseCode;
		if (decoder.openGroup('ErrorResponse') || decoder.openGroup('transactionResponse')) {
			responseCode = decoder.getElement('responseCode');
					
			if (decoder.openGroup('message')) {
				string rcode = decoder.getElement('code');
				if (rcode != null && rcode != '1')
					msgs.add( new OnlineTxnMessage(
						rcode, null, decoder.getElement('description')));
				decoder.closeGroup();
			}
	
			if (decoder.openGroup('messages')) {
				integer i = 0;
				while (decoder.openGroup('message', i)) {
					string rcode = decoder.getElement('code');
					if (rcode != null && rcode != '1')
						msgs.add( new OnlineTxnMessage(
							rcode, null, decoder.getElement('description')));
					decoder.closeGroup();
					i++;		
				}
				decoder.closeGroup();
			}		
	
			if (decoder.openGroup('error')) {
				string rcode = decoder.getElement('errorCode');
				if (rcode != null && rcode != '1')
					msgs.add( new OnlineTxnMessage(
						rcode, null, decoder.getElement('errorText')));
				decoder.closeGroup();
			}
	
			if (decoder.openGroup('errors')) {
				integer i = 0;
				while (decoder.openGroup('error', i)) {
					string rcode = decoder.getElement('errorCode');
					if (rcode != null && rcode != '1')
						msgs.add( new OnlineTxnMessage(
							rcode, null, decoder.getElement('errorText')));
					decoder.closeGroup();
					i++;		
				}
				decoder.closeGroup();			
			}
			decoder.closeGroup();			
		}			
		
		boolean success = (resultCode == 'Ok' && (responseCode == null || responseCode == '1'));

		OnlineTxnResult result = new OnlineTxnResult( success, responseBody );
		result.messages.addAll(msgs);
		
		// for authnet, the second message is more interesting
		result.errorMessage = ((msgs.size() > 1 && msgs[1].longMessage != null) ? msgs[1].longMessage :
			(msgs.size() > 0) ? msgs[0].longMessage : null );
				
		return result;
	}

	// utility to strip out pwd and cc info from the xml.		
	private string strXmlScrub(string str) {
		if (str == null) return null;
		str = str.replaceAll('<transactionKey>[a-zA-z0-9]*</transactionKey>', '<transactionKey>****</transactionKey>');
		str = str.replaceAll('<cardNumber>[a-zA-z0-9]*</cardNumber>', '<cardNumber>****</cardNumber>');
		str = str.replaceAll('<cardCode>[a-zA-z0-9]*</cardCode>', '<cardCode>****</cardCode>');
		return str;
	}
	
	protected virtual HttpResponse execute(Http h, HttpRequest request) {
		return h.send(request);
	}

	protected virtual string getResponseBody(HttpResponse response) {
		return response.getBody();
	}

	global class XMLEncoder {
		
		// property getter for returning the full xml
		global string xml { get {
			w.writeEndDocument();
			return w.getXmlString();
		} }

		// use the stream writer to create the xml for authnet		
		XmlStreamWriter w;
			
		global XMLEncoder( string requestType ) {
			w = new XmlStreamWriter();
			w.writeStartDocument('utf-8', '1.0');
			w.writeStartElement(null, requestType, null);
			w.writeDefaultNamespace('AnetApi/xml/v1/schema/AnetApiSchema.xsd');
			w.writeNamespace('xsi', 'http://www.w3.org/2001/XMLSchema-instance');
			w.writeNamespace('xsd', 'http://www.w3.org/2001/XMLSchema');			
		} 
		
		global void addElement(string sName, string sValue) {
			if (sName != null) { 
				w.writeStartElement(null, sName, null);
				if (sValue != null) w.writeCharacters(sValue);
				w.writeEndElement();
			}
		}

		global void addElement(string sName, decimal dValue) {
			addElement(sName, (dValue == null) ? null : dValue.setScale(2).toPlainString() );
		}

		global void addElement(string sName, integer iValue) {
			addElement(sName, (iValue == null) ? null : string.valueof(iValue) );
		}

		global void addElement(string sName, datetime dtValue) {
			addElement(sName, (dtValue == null) ? null : string.valueOfGmt(dtValue).replace(' ', 'T') + 'Z' );
		}

		global void addElement(string sName, date dateValue) {
			addElement(sName, (dateValue == null) ? null : string.valueOf(dateValue));
		}

		global void addElements(map<string, string> elementMap) {
			for (string sName : elementMap.keyset())
				addElement(sName, elementMap.get(sName)); 
		}

		global void openGroup(string sName) {
			w.writeStartElement(null, sName, null);
		}
		
		global void closeGroup() {
			w.writeEndElement();
		}
	}	

	global class XMLDecoder {
		
		global Dom.Document doc { get; private set; }
		global string ns { get; private set; }
		global string requestType { get; private set; }
		
		Dom.xmlNode currentNode;
		Dom.xmlNode parentNode;
		list<Dom.xmlNode> nodeList;
		
		global XMLDecoder( string xml ) {
			doc = new Dom.Document();
			//system.debug('DJH: ' + xml);
			doc.load(xml);
			currentNode = doc.getRootElement();
			ns = currentNode.getNamespace();
			requestType = currentNode.getName();
		} 
		
		global string getElement(string sName) {
			dom.xmlNode node = currentNode.getChildElement(sName, ns);
			return (node == null || node.getText() == '') ? null : node.getText();
		}

		global boolean openGroup(string sName) {
			dom.xmlNode node = currentNode.getChildElement(sName, ns);
			if (node != null) {
				parentNode = currentNode;
				currentNode = node;
				return true;
			} else {
				return false;
			}
		}

		global boolean openGroup(string sName, integer i) {
			list<dom.xmlNode> nodeList = currentNode.getChildElements();
			if (i != null && i >= 0 && i < nodeList.size()) {
				dom.xmlNode node = nodeList[i];
				if (node != null) {
					parentNode = currentNode;
					currentNode = node;
					return true;
				} else {
					return false;
				}
			} else {
				return false;				
			}
		}

		global boolean closeGroup() {
			if (parentNode != null) {
				currentNode = parentNode;
				parentNode = currentNode.getParent();
				return true;
			} else {
				return false;
			}
		}
	}	
}