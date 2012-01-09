/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description Paypal class containing data structures and utilities for online payment processing.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/

global virtual with sharing class OnlinePaymentPaypal extends OnlinePayment {   

	/*
	TODO: 
	In testing, should check encoding - e.g. accented chars
 
	FUTURE: 
	  - Support paying with a Paypal account (via Express Checkout)
	  - Support Fraud Management Filters 
	  - More methods from API (e.g. update and cancel calls)
	*/

	static final string PRODUCTION_ENDPOINT = 'https://api-3t.paypal.com/nvp';		
	static final string SANDBOX_ENDPOINT = 'https://api-3t.sandbox.paypal.com/nvp'; 
	static final string PAYPAL_API_VERSION = '52.0';
	static final string DEFAULT_RECURRING_PAYMENT_DESCRIPTION = 'Recurring Payment';
	
	// constructor
	global OnlinePaymentPaypal( APIAuthorization paypalAuth ) {
		super( paypalAuth );

		// if the auth was null, try to use default processor settings
		if ( auth == null && !setDefaultProcessor( 'Paypal' ) ) {
			throw new OnlinePaymentException('No default payment processor configuration was found for Paypal. To create one, go to the Configure Payments tab (or talk to your system administrator).');
		}		

		endpoint = (auth.sandbox) ? SANDBOX_ENDPOINT : PRODUCTION_ENDPOINT;
 	} 

	public class TestException extends Exception {}

	global virtual class OnlineTxnResult extends OnlinePayment.OnlineTxnResult {
		global map<string, string> params { get; set; }
		
		global OnlineTxnResult() {
			super (false, null);
		}
		
		global OnlineTxnResult( boolean fSuccess, string sResponseText, map<string, string> paramsMap ) {
			super(fSuccess, sResponseText);
			params = paramsMap;
		}	
	}

	global virtual class PaymentTxnResult extends OnlinePayment.PaymentTxnResult {		
		global decimal amount { get; set; }
		global string avsResponse { get; set; }
		global string cvvResponse { get; set; }
		//global list<string> fmfFilterList { get; private set; }
		global map<string, string> params { get; set; }
		
		global PaymentTxnResult() {
			super();
		}
		
		global PaymentTxnResult( boolean fSuccess, string sResponseText, map<string, string> paramsMap, string sTxnId, decimal dAmount, string sAvsResponse, string sCvvResponse, string sErrMsg, list<OnlineTxnMessage> sMsgs ) {
			super( fSuccess, sResponseText, sTxnId, sAvsResponse, sCvvResponse, sErrMsg, sMsgs );
			
			amount = dAmount;
			//fmfFilterList = new list<string>(); 
			params = paramsMap;
		}
	}

	global virtual class PaymentProfileResult extends OnlinePayment.PaymentProfileResult {		
		global string status { get; set; }
		global map<string, string> params { get; set; }
		
		global PaymentProfileResult() {
			super();
		}
		
		global PaymentProfileResult( boolean fSuccess, string sResponseText, map<string, string> paramsMap, string sRecurringTxnId, string sStatus, string sErrMsg, list<OnlineTxnMessage> sMsgs ) {
			super( fSuccess, sResponseText, sRecurringTxnId, sErrMsg, sMsgs );
			status = sStatus;
			params = paramsMap;
		}
	}

	protected NVPEncoder getEncoder(string endpoint, string requestType) { 
		NVPEncoder encoder = new NVPEncoder( endpoint );

		if (auth != null) {
			encoder.addParam('USER', auth.loginId);
			encoder.addParam('PWD', auth.password);
			encoder.addParam('SIGNATURE', auth.signature);
			if (auth.remoteIpAddress != null)
				encoder.addParam('IPADDRESS', auth.remoteIpAddress);
			encoder.addParam('METHOD', requestType);
			encoder.addParam('VERSION', PAYPAL_API_VERSION);
		}

		return encoder;
	}

	global virtual PaymentTxnResult DoDirectPayment( OnlinePayer payer, CreditCardData card, PaymentData payment ) {
		
		// declare all variables before we do the try/catch, so we can access things afterwards.		
		NVPEncoder encoder;
		OnlineTxnResult baseResult = new OnlineTxnResult();
		PaymentTxnResult result = new PaymentTxnResult(); 
		ID oppId;
		
		try {
	
			// build the URL
			encoder = getEncoder( endpoint, 'DoDirectPayment' );
	
			// payer
			encoder.addParam('EMAIL', payer.email);
			encoder.addParam('FIRSTNAME', payer.firstName);
			encoder.addParam('LASTNAME', payer.lastName);
	
			// billing address
			if (payer.billingAddress != null) { 
				if (payer.billingAddress.street != null) { 
					list<string> splitStreet = payer.billingAddress.street.split('\n', 2);
					encoder.addParam('STREET', splitStreet[0]);
					if (splitStreet.size() > 1)
						encoder.addParam('STREET2', splitStreet[1]);
				}
				encoder.addParam('CITY', payer.billingAddress.city);
				encoder.addParam('STATE', payer.billingAddress.state);
				encoder.addParam('ZIP', payer.billingAddress.zip);
				encoder.addParam('COUNTRYCODE', payer.billingAddress.country);  // ONLY 3 CHARS
			}
			
			// shipping address
			if (payer.shippingAddress != null) {
				if (payer.shippingAddress.street != null) { 
					list<string> splitStreet = payer.shippingAddress.street.split('\n', 2);
					encoder.addParam('SHIPTOSTREET', splitStreet[0]);
					if (splitStreet.size() > 1)
						encoder.addParam('SHIPTOSTREET2', splitStreet[1]);
				}
				encoder.addParam('SHIPTOCITY', payer.shippingAddress.city);
				encoder.addParam('SHIPTOSTATE', payer.shippingAddress.state);
				encoder.addParam('SHIPTOZIP', payer.shippingAddress.zip);
				encoder.addParam('SHIPTOCOUNTRYCODE', payer.shippingAddress.country);
			}
			encoder.addParam('SHIPTOPHONENUM', (payer.shippingAddress == null || payer.shippingAddress.phone == null) ? payer.billingAddress.phone : payer.shippingAddress.phone);
	
			// card
			encoder.addParam('CREDITCARDTYPE', card.cardType);		
			encoder.addParam('ACCT', card.acctNumber);		
			if (card.expMonth != null && card.expYear != null) 
				encoder.addParam('EXPDATE', card.expMonth + ((card.expYear.length()==2) ? '20' : '') + card.expYear);		
			encoder.addParam('CVV2', card.cvvCode);		
			
			// payment
			encoder.addParam('PAYMENTACTION', (payment.action == null || payment.action == PaymentAction.PAY) ? 'Sale' : 'Authorization');
			if (payment.itemList != null && !payment.itemList.isEmpty()) {
				decimal itemAmt = 0;
				for (integer i = 0; i < payment.itemList.size(); i++) {
					encoder.addParam('L_NAME' + string.valueOf(i), payment.itemList[i].name);
					encoder.addParam('L_DESC' + string.valueOf(i), payment.itemList[i].description);
					encoder.addParam('L_AMT' + string.valueOf(i), payment.itemList[i].amount);
					encoder.addParam('L_NUMBER' + string.valueOf(i), payment.itemList[i].code);
					encoder.addParam('L_QTY' + string.valueOf(i), payment.itemList[i].quantity);
					encoder.addParam('L_TAXAMT' + string.valueOf(i), payment.itemList[i].tax);
					if (payment.itemList[i].amount != null)
						itemAmt += payment.itemList[i].amount; 
				}
				encoder.addParam('ITEMAMT', itemAmt);
			}
	
			encoder.addParam('AMT', payment.totalAmount);
			if (payment.currencyCode != null)
				encoder.addParam('CURRENCYCODE', payment.currencyCode);
			if (payment.shipping != null)
				encoder.addParam('SHIPPINGAMT', payment.shipping);
			if (payment.insurance != null)
				encoder.addParam('INSURANCEAMT', payment.insurance);
			if (payment.shippingDiscount != null)
				encoder.addParam('SHIPDISCAMT', payment.shippingDiscount);
			if (payment.handling != null)
				encoder.addParam('HANDLINGAMT', payment.handling);
			if (payment.tax != null)
				encoder.addParam('TAXAMT', payment.tax);
			string descrip = 
				(payment.memo != null) ? payment.memo : 
				(payment.itemList != null && payment.itemList.size() == 1) ?
				((payment.itemList[0].description != null) ? payment.itemList[0].description : 
				payment.itemList[0].name) : null ;
			// hack to test exception handling!!
			//if (payment.memo == 'cause exception') {
			//	throw (new TestException('you asked, we delivered: your exception in DoDirectPayment!'));
			//}									
			if (descrip != null)
				encoder.addParam('DESC', descrip);
			if (payment.custom != null)
				encoder.addParam('CUSTOM', payment.custom);
			if (payment.invoice != null)
				encoder.addParam('INVNUM', payment.invoice);
			//encoder.addParam('BUTTONSOURCE', );
			//encoder.addParam('NOTIFYURL', );
			//encoder.addParam('RECURRING', );
	
			baseResult = callPaypal( encoder.url );
			string sAmt = baseResult.params.get('AMT');
			decimal dAmt = (sAmt == null) ? null : 
				decimal.valueOf(sAmt.replace(',','')).setScale(2);
			result = new PaymentTxnResult(
				baseResult.success, baseResult.responseText, baseResult.params, 
				baseResult.params.get('TRANSACTIONID'), dAmt,
				baseResult.params.get('AVSCODE'), baseResult.params.get('CVV2MATCH'), 
				baseResult.errorMessage, baseResult.messages );
				
			// put Paypal data into payment object
			payment.txnId = result.txnId;	
			
			// set payment status to correct thing
			if (result.success) {
				payment.pmtStatus = (payment.action == OnlinePayment.PaymentAction.AUTHORIZE) ? 
					OnlinePayment.PaymentStatus.AUTHORIZED: OnlinePayment.PaymentStatus.COMPLETED;
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
				
		        if (opmt.processSinglePayment()) {
		            oppId = opmt.opportunityId;
		            result.dbSuccess = true;                    
		        }
			}
		} catch (exception ex) {
			result.errorMessage = ex.getMessage();
			result.errorStackTrace = ex.getStackTraceString();
			result.errorLineNumber = ex.getLineNumber();	
			// fall thru to log the ipn, and return the result object.		
		}	
				                        
        // log the ipn record
		boolean isTest = auth.sandbox; 
		Payment_Notification__c ipn = logNotification(payer, payment, 'Apex Payment Callout', payment.action, 
			encoder == null ? null : strUrlScrub(encoder.url), 
			baseResult.responseText, isTest, false, result.errorMessage, false);	
		ipn.Transaction_Type__c = 'Paypal DoDirectPayment()';
        ipn.isProcessed__c = result.dbSuccess == null ? false : result.dbSuccess;  
        ipn.opportunity__c = oppId;
        ipn.errorLineNumber__c = result.errorLineNumber;
        ipn.errorStackTrace__c = result.errorStackTrace;		
        insert ipn;

		return result;			
	}
	
	global virtual PaymentProfileResult CreateRecurringPaymentsProfile( OnlinePayer payer, CreditCardData card, PaymentData payment ) {
		
		// declare all variables before we do the try/catch, so we can access things afterwards.		
		NVPEncoder encoder;
		OnlineTxnResult baseResult = new OnlineTxnResult();
		PaymentProfileResult result = new PaymentProfileResult(); 
		ID oppId;
		
		try {
	
			// build the URL
			encoder = getEncoder( endpoint, 'CreateRecurringPaymentsProfile' );
	
			// payer
			encoder.addParam('EMAIL', payer.email);
			encoder.addParam('FIRSTNAME', payer.firstName);
			encoder.addParam('LASTNAME', payer.lastName);
			encoder.addParam('BUSINESS', payer.companyName);
			//encoder.addParam('SUBSCRIBERNAME', payer.firstName + ' ' + payer.lastName);
			//encoder.addParam('SALUTATION', payer.firstName + ' ' + payer.lastName);
			//encoder.addParam('MIDDLENAME', payer.firstName + ' ' + payer.lastName);
			//encoder.addParam('SUFFIX', payer.firstName + ' ' + payer.lastName);
	
			// billing address
			if (payer.billingAddress != null) { 
				if (payer.billingAddress.street != null) { 
					list<string> splitStreet = payer.billingAddress.street.split('\n', 2);
					encoder.addParam('STREET', splitStreet[0]);
					if (splitStreet.size() > 1)
						encoder.addParam('STREET2', splitStreet[1]);
				}
				encoder.addParam('CITY', payer.billingAddress.city);
				encoder.addParam('STATE', payer.billingAddress.state);
				encoder.addParam('ZIP', payer.billingAddress.zip);
				encoder.addParam('COUNTRYCODE', payer.billingAddress.country);  // ONLY 3 CHARS
				
				// shipping address
				if (payer.shippingAddress != null) {
					if (payer.shippingAddress.street != null) { 
						list<string> splitStreet = payer.shippingAddress.street.split('\n', 2);
						encoder.addParam('SHIPTOSTREET', splitStreet[0]);
						if (splitStreet.size() > 1)
							encoder.addParam('SHIPTOSTREET2', splitStreet[1]);
					}
					encoder.addParam('SHIPTOCITY', payer.shippingAddress.city);
					encoder.addParam('SHIPTOSTATE', payer.shippingAddress.state);
					encoder.addParam('SHIPTOZIP', payer.shippingAddress.zip);
					encoder.addParam('SHIPTOCOUNTRYCODE', payer.shippingAddress.country);
				}
				encoder.addParam('SHIPTOPHONENUM', (payer.shippingAddress == null || payer.shippingAddress.phone == null) ? payer.billingAddress.phone : payer.shippingAddress.phone);
			}
			
			// card
			encoder.addParam('CREDITCARDTYPE', card.cardType);		
			encoder.addParam('ACCT', card.acctNumber);		
			if (card.expMonth != null && card.expYear != null) 
				encoder.addParam('EXPDATE', card.expMonth + ((card.expYear.length()==2) ? '20' : '') + card.expYear);		
			encoder.addParam('CVV2', card.cvvCode);		
	
			// payment
			encoder.addParam('AMT', payment.totalAmount);
	        encoder.addParam('PROFILESTARTDATE', (payment.startDate != null && payment.startDate > system.today()) ? 
				dateTime.newInstance(payment.startDate, system.now().time()) : system.now().addminutes(1) );
			encoder.addParam('BILLINGPERIOD', 
				(payment.pmtPeriod == RecurringPeriod.DAY) ? 'Day' : 
				(payment.pmtPeriod == RecurringPeriod.WEEK) ? 'Week' : 
				(payment.pmtPeriod == RecurringPeriod.YEAR) ? 'Year' : 
				'Month' );
	        encoder.addParam('BILLINGFREQUENCY', (payment.frequency != null) ? payment.frequency : 1);
			string descrip = 
				(payment.memo != null && payment.memo != '') ? payment.memo : DEFAULT_RECURRING_PAYMENT_DESCRIPTION;
			// hack to test exception handling!!
			//if (payment.memo == 'cause exception') {
			//	throw (new TestException('you asked, we delivered: your exception in CreateRecurringPaymentsProfile!'));
			//}			
	        if (descrip != null) 
				encoder.addParam('DESC', descrip);
			if (payment.occurrences != null)
				encoder.addParam('TOTALBILLINGCYCLES', payment.occurrences);
			if (payment.currencyCode != null)
				encoder.addParam('CURRENCYCODE', payment.currencyCode);
			if (payment.shipping != null)
				encoder.addParam('SHIPPINGAMT', payment.shipping);
			if (payment.tax != null)
				encoder.addParam('TAXAMT', payment.tax);
			if (payment.custom != null)
				encoder.addParam('CUSTOM', payment.custom);
	
			// add order items
			if (!payment.itemList.isEmpty()) {
				integer i = 1;
				for (Item item : payment.itemList) {
					string s = string.valueOf(i);
					encoder.addParam('L_PAYMENTREQUEST_n_NAME' + s, item.name );
					encoder.addParam('L_PAYMENTREQUEST_n_NUMBER' + s, item.code );
					encoder.addParam('L_PAYMENTREQUEST_n_DESCRIPTION' + s, item.description );
					encoder.addParam('L_PAYMENTREQUEST_n_AMOUNT' + s, item.amount );
					encoder.addParam('L_PAYMENTREQUEST_n_QTY' + s, item.quantity );
					encoder.addParam('L_PAYMENTREQUEST_n_TAXAMT' + s, item.tax );
				}
			}	
			
			//encoder.addParam('L_PAYMENTREQUEST_n_DESCm', );
			//encoder.addParam('L_PAYMENTREQUEST_n_AMTm', );
			//encoder.addParam('L_PAYMENTREQUEST_n_NUMBERm', );
			//encoder.addParam('L_PAYMENTREQUEST_n_QTYm', );
			//encoder.addParam('L_PAYMENTREQUEST_n_TAXAMTm', );
			
			// other params we could support...
			//encoder.addParam('BUTTONSOURCE', );
			//encoder.addParam('NOTIFYURL', );
			//encoder.addParam('MAXFAILEDPAYMENTS', );
			//encoder.addParam('AUTOBILLOUTAMT', );
			//encoder.addParam('PROFILEREFERENCE', );
			//encoder.addParam('TRIALBILLINGPERIOD', );
			//encoder.addParam('TRIALBILLINGFREQUENCY', );
			//encoder.addParam('TRIALTOTALBILLINGCYCLES', );
			//encoder.addParam('TRIALAMT', );
			//encoder.addParam('INITAMT', );
			//encoder.addParam('FAILEDINITAMTACTION', );
	
			baseResult = callPaypal( encoder.url );
			result = new PaymentProfileResult(
				baseResult.success, baseResult.responseText, baseResult.params, 
				baseResult.params.get('PROFILEID'), baseResult.params.get('PROFILESTATUS'), 
				baseResult.errorMessage, baseResult.messages );
	
			// put Paypal data into payment object
			payment.recurringTxnId = result.recurringTxnId;
			
			// set payment status to correct thing
			if (result.success) {
				payment.pmtStatus = (payment.action == OnlinePayment.PaymentAction.AUTHORIZE) ? 
					OnlinePayment.PaymentStatus.AUTHORIZED: OnlinePayment.PaymentStatus.COMPLETED;
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
				
		        if (opmt.startRecurringPayments()) {
		            oppId = opmt.opportunityId;                    
					result.dbSuccess = true;
		        }
			}
		} catch (exception ex) {
			result.errorMessage = ex.getMessage();
			result.errorStackTrace = ex.getStackTraceString();
			result.errorLineNumber = ex.getLineNumber();	
			// fall thru to log the ipn, and return the result object.		
		}	
		                        
        // log the ipn record
		boolean isTest = auth.sandbox; 
		Payment_Notification__c ipn = logNotification(payer, payment, 'Apex Payment Callout', payment.action, 
			encoder == null ? null : strUrlScrub(encoder.url), 
			baseResult.responseText, isTest, false, result.errorMessage, false);	
		ipn.Transaction_Type__c = 'Paypal CreateRecurringPaymentsProfile()';
        ipn.isProcessed__c = result.dbSuccess == null ? false : result.dbSuccess;  
        ipn.opportunity__c = oppId;
        ipn.errorLineNumber__c = result.errorLineNumber;
        ipn.errorStackTrace__c = result.errorStackTrace;		
        insert ipn;

		return result;			
	}
	
	global OnlineTxnResult getTransactionDetails( string sTxnId ) {
		OnlineTxnResult result	= new OnlineTxnResult();
		
		try { 	
			// build the URL
			NVPEncoder encoder = getEncoder( endpoint, 'GetTransactionDetails' );		
			encoder.addParam('TRANSACTIONID', sTxnId);
			result = callPaypal( encoder.url );
		} catch (exception ex) {
			result.success = false;
			result.errorMessage = ex.getMessage();
			result.errorStackTrace = ex.getStackTraceString();
			result.errorLineNumber = ex.getLineNumber();	
			// fall thru and return the result object.		
		}			
		return result;
	}
	
	global OnlineTxnResult getRecurringPaymentsProfileDetails( string recurringProfileId ) {
		OnlineTxnResult result	= new OnlineTxnResult();
		
		try { 	
			// build the URL
			NVPEncoder encoder = getEncoder( endpoint, 'GetRecurringPaymentsProfileDetails');
			encoder.addParam('PROFILEID', recurringProfileId);
			result = callPaypal( encoder.url );
		} catch (exception ex) {
			result.success = false;
			result.errorMessage = ex.getMessage();
			result.errorStackTrace = ex.getStackTraceString();
			result.errorLineNumber = ex.getLineNumber();	
			// fall thru and return the result object.		
		}	
		return result;
	}
	
	protected OnlineTxnResult callPaypal( string url ) {
		string body;
	
		try {				
			// prepare the request
			Http h = new Http();
			HttpRequest req = new HttpRequest();
			req.setTimeout(60000);
			req.setMethod('GET');
			req.setEndpoint(url);
			//system.debug( LOGGINGLEVEL.warn, url );
			
			// execute the request
			HttpResponse resp = execute( h, req );
			
			// interpret the response
			body = getResponseBody( resp );		
			//system.debug( LOGGINGLEVEL.warn, body );
		} catch (Exception ex) {
			// we treat http errors as an Paypal handled error, so that we will still
			// log the notification record appropriately.			
			body = '&ACK=Failure' + 
				'&L_ERRORCODE0=10002' + 
				'&L_SHORTMESSAGE0=Communication%20Error' + 
				'&L_LONGMESSAGE0=' + 'There%20was%20a%20communication%20problem%20with%20the%20payment%20processor,%20so%20your%20credit%20card%20was%20not%20charged.%20' +
					'Error%20details:%20' + ex.getMessage().replace(' ', '%20') +  
				'&L_SEVERITYCODE0=Error';
		}
		NVPDecoder decoder = new NVPDecoder( body );
		string ack = decoder.params.get('ACK');
		boolean success = (ack != null && ack.toLowerCase().startsWith('success'));
		
		OnlineTxnResult result = 
			new OnlineTxnResult( success, body, decoder.params );
		
		// include the errors
		integer i = 0;
		string num = string.valueOf(i);
		while (decoder.params.containsKey('L_ERRORCODE' + num)) {
			result.messages.add( new OnlineTxnMessage(
				decoder.params.get('L_ERRORCODE' + num),
				decoder.params.get('L_SHORTMESSAGE' + num),
				decoder.params.get('L_LONGMESSAGE' + num)
			));
			i++;
			num = string.valueOf(i);
		}			

		// for paypal, the first long message is the error message to display
		if (!result.success && !result.messages.isEmpty())
			result.errorMessage = result.messages[0].longMessage;

		return result;
	}
	
	// utility to strip out pwd and cc info from the url.		
	private string strUrlScrub(string strUrl) {
		// strip out pwd and cc info from the url.		
		strUrl = strUrl.replaceAll('&PWD=[a-zA-z0-9]*&', '&PWD=*****&');
		strUrl = strUrl.replaceAll('&ACCT=[a-zA-z0-9]*&', '&ACCT=*****&');
		strUrl = strUrl.replaceAll('&CVV2=[a-zA-z0-9]*&', '&CVV2=*****&');
		return strUrl;
	}

	public virtual HttpResponse execute(Http h, HttpRequest request) {
		return h.send(request);
	}
	
	public virtual string getResponseBody(HttpResponse response) {
		return response.getBody();
	}	
	
	global class NVPEncoder {
		global string url { get; private set; }
		global integer paramCount { get; private set; }
			
		global NVPEncoder(string endpoint) {
			paramCount = 0;
			url = (endpoint==null) ? '#' : endpoint;
		} 
		
		global void addParam(string sName, string sValue) {
			if (sName != null) { 
				url += (paramCount == 0) ? '?' : '&';
				url += sName + '=' + ((sValue == null) ? '' : EncodingUtil.URLEncode(sValue, 'UTF-8')); 
				paramCount++;
			}
		}

		global void addParam(string sName, decimal dValue) {
			addParam(sName, (dValue == null) ? null : dValue.setScale(2).toPlainString() );
		}

		global void addParam(string sName, integer iValue) {
			addParam(sName, (iValue == null) ? null : string.valueof(iValue) );
		}

		global void addParam(string sName, datetime dtValue) {
			addParam(sName, (dtValue == null) ? null : string.valueOfGmt(dtValue).replace(' ', 'T') + 'Z' );
		}

		global void addParams(map<string, string> nvpMap) {
			for (string sName : nvpMap.keyset())
				addParam(sName, nvpMap.get(sName)); 
		}
	}	
	
	global class NVPDecoder {
		global string data { get; private set; } 
		global map<string, string> params { get; private set; }
			
		global NVPDecoder(string sData) {
			data = sData;
			params = new map<string, string>();
			for (string nvp : sData.split('&', -1)) {
				list<string> nvpSplit = nvp.split('=', 2);
				if (!nvpSplit.isEmpty() && nvpSplit[0] != '') {
					string val = (nvpSplit.size() == 1 || nvpSplit[1] == '') ? null :  
						EncodingUtil.URLDecode(nvpSplit[1], 'UTF-8');
					params.put(nvpSplit[0], val );  
				}
			}
		}
	}	
	
}