/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description Base class containing data structures and utilities for online payment processing.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/
  
global virtual class OnlinePayment {

    // store the auth once for all calls
    public APIAuthorization auth;       
    protected string endpoint;  
    
    // need a custom exception class so we can throw an error back
    global class OnlinePaymentException extends Exception {}

    // default constructor
    global OnlinePayment() {}
    
    // constructor that sets the payment processor authorization
    global OnlinePayment( APIAuthorization apiAuth ) {
        auth = apiAuth;
    }
    
    // load payment processor settings and find the default
    global boolean setDefaultProcessor( string pmtProcessorType ) {
        boolean foundDefault = false;
        for (Payment_API_Config__c config : Payment_API_Config__c.getAll().values()) {
            if (config.default_connection__c == true && config.processor__c == pmtProcessorType) {
                auth = new OnlinePayment.APIAuthorization(
                    config.login_id__c, config.password__c, config.signature__c, getRemoteHost(), config.sandbox__c 
                );
                foundDefault = true;
                break;
            }
        }       
        return foundDefault;
    }
    
    // process a single transaction payment
    global virtual PaymentTxnResult DoSinglePayment( OnlinePayer payer, CreditCardData card, PaymentData payment ) {
        PaymentTxnResult paymentResult;
		ClassFactory f = new ClassFactory();
        if (payment.pmtProcessor == Processor.PAYPAL) {
            OnlinePaymentPaypal ppal = f.makeOPPaypal(auth, 'payment'); 
            paymentResult = ppal.DoDirectPayment( payer, card, payment );           
        } else /* if (payment.pmtProcessor == Processor.AUTHNET) */ {                       
            OnlinePaymentAuthnet authnet = f.makeOPAuthnet(auth, 'payment');
            paymentResult = authnet.CreateTransactionRequest( payer, card, payment, false, false, true );                    
        }
        return paymentResult;       
    }
    
    // process a recurring transaction payment
    global virtual PaymentProfileResult CreateRecurringPayment( OnlinePayer payer, CreditCardData card, PaymentData payment ) {
        PaymentProfileResult recurringResult;       
		ClassFactory f = new ClassFactory();
        if (payment.pmtProcessor == Processor.PAYPAL) {
            OnlinePaymentPaypal ppal = f.makeOPPaypal(auth, 'profile'); 
            recurringResult = ppal.CreateRecurringPaymentsProfile( payer, card, payment );
        } else /* if (payment.pmtProcessor == Processor.AUTHNET) */ {                       
            OnlinePaymentAuthnet authnet = f.makeOPAuthnet(auth, 'profile');
            recurringResult = authnet.ARBCreateSubscriptionRequest( payer, card, payment, true );                   
        }
        return recurringResult;
    }
   
    // get results from the transaction
    global virtual OnlineTxnResult getTransactionDetails( PaymentData payment, string txnId ) {
        OnlineTxnResult result;
		ClassFactory f = new ClassFactory();
        if (payment.pmtProcessor == Processor.PAYPAL) {
            OnlinePaymentPaypal ppal = f.makeOPPaypal(auth, 'txnInfo'); 
            result = ppal.getTransactionDetails( txnId );   
        } else /* if (payment.pmtProcessor == Processor.AUTHNET) */ {                       
            OnlinePaymentAuthnet authnet = f.makeOPAuthnet(auth, 'txnInfo');
            result = authnet.getTransactionDetails( txnId );                        
        }
        return result;
    }       
    
    // get results from the transaction
    global virtual OnlineTxnResult voidPayment( PaymentData payment ) {
        OnlineTxnResult result;
		ClassFactory f = new ClassFactory();
        if (payment.pmtProcessor == Processor.PAYPAL) {
            OnlinePaymentPaypal ppal = f.makeOPPaypal(auth, 'void'); 
            result = ppal.doVoid( payment.txnId );   
        } else /* if (payment.pmtProcessor == Processor.AUTHNET) */ {                       
            OnlinePaymentAuthnet authnet = f.makeOPAuthnet(auth, 'void');
            result = authnet.VoidTransaction( payment.txnId, true );                        
        }
        return result;
    }       

    global virtual OnlineTxnResult refundPayment( PaymentData payment, CreditCardData card ) {
        OnlineTxnResult result;
		ClassFactory f = new ClassFactory();
        if (payment.pmtProcessor == Processor.PAYPAL) {
            OnlinePaymentPaypal ppal = f.makeOPPaypal(auth, 'refund'); 
            result = ppal.RefundTransaction( payment );   
        } else /* if (payment.pmtProcessor == Processor.AUTHNET) */ {                       
            OnlinePaymentAuthnet authnet = f.makeOPAuthnet(auth, 'refund');
            result = authnet.RefundTransaction( payment, card, false, false );                        
        }
        return result;
    }

    // subclass to track one or more items for a payment or order
    global virtual class Item {
        global string name { get; set; } 
        global string description { get; set; } 
        global string code { get; set; }
        global integer quantity { get; set; }
        global decimal amount { get; set; }
        global decimal tax { get; set; }
        global string discountcode { get; set; }
        
        // function to add an item
        global Item( string sName, string sDesc, string sCode, integer iQuantity, decimal dAmount, decimal dTax, string sDiscountCode ) {
            name = sName;
            description = sDesc;
            code = sCode;
            quantity = iQuantity;
            amount = dAmount;
            tax = dTax;
            discountcode = sDiscountCode;
        }       
    }

    // properties for authenticating to a payment provider such as paypal
    global virtual class APIAuthorization {
        global string loginId { get; set; }
        global string password { get; set; }
        global string signature { get; set; }
        global string remoteIpAddress { get; set; } 
        global boolean sandbox { get; set; } 

        // constructor
        global APIAuthorization( string sLoginId, string sPassword, string sSignature, string sRemoteIpAddress, boolean bSandbox ) {
            loginId = sLoginId;
            password = sPassword;
            signature = sSignature;
            remoteIpAddress = sRemoteIpAddress;
            sandbox = bSandbox;
        }
    }
        
    // properties for matching or creating the payer
    global class OnlinePayer {
        global string email { get; set; }
        global string firstName { get; set; }
        global string lastName { get; set; }
        global string companyName { get; set; }
        global AddressData billingAddress { get; set; }
        global AddressData shippingAddress { get; set; }
        global string payerId { get; set; }
        
        global OnlinePayer() {
            billingAddress = new AddressData(); 
            shippingAddress = new AddressData();    
        }
        
        global OnlinePayer (string sEmail, string sFirstName, string sLastName, string sCompanyName, AddressData addrBilling, AddressData addrShipping, string sPayerId) {
            email = sEmail;
            firstName = sFirstName;
            lastName = sLastName;
            companyName = sCompanyName;
            billingAddress = addrBilling;
            shippingAddress = addrShipping;
            payerId = sPayerId;
        }
    }

    global class AddressData {
        global string street { get; set; }
        global string city { get; set; }
        global string state { get; set; }
        global string zip { get; set; }
        global string country { get; set; }
        global string phone { get; set; }
        
        global AddressData() {}
        
        global AddressData (string sStreet, string sCity, string sState, string sZip, string sCountry, string sPhone) {
            street = sStreet;
            city = sCity;
            state = sState;
            zip = sZip;
            country = sCountry;
            phone = sPhone;
        }
    }
    
    // these enumerations provide abstract support for different payment gateways
    global enum Processor { 
        PAYPAL,
        AUTHNET,
        OTHER 
    }
    
    // to tell the OnlinePayment classes whether to authorize only, or complete the payment.
    global enum PaymentAction { 
        PAY,
        AUTHORIZE,
        VOIDTXN,
        REFUND 
    }
    
    // the return result from the processor     
    global enum PaymentStatus { 
        COMPLETED,      // you have the money
        AUTHORIZED,     // you need to take action
        PENDING,        // you might need to take action, or just wait
        DECLINED,       // bad credit, zipcode, or cvs code
        FAILED,         // an error occurred
        VOIDED,           // previously pending/authorized, but no longer
        REVERSED        // previously completed, money was refunded
    }
    global enum PaymentType { 
        CREDITCARD,
        ECHECK, 
        EFT,            // electronic funds transfer
        INSTANT         // paypal uses this for anything that isn't echeck
    }
    global enum RecurringPeriod { 
        DAY,
        WEEK, 
        MONTH,
        YEAR    
    }
    global enum MatchResult { 
        TRANSACTION_MATCH,
        CONTACT_MATCH,
        NEW_CONTACT,
        ACCOUNT_MATCH,
        NEW_ACCOUNT
    }

    // properties for logging a payment into Salesforce     
    global virtual class PaymentData {
        
        global Processor pmtProcessor { get; set; }
        global PaymentAction action { get; set; }
        global PaymentType pmtType { get; set; }
        global PaymentStatus pmtStatus { get; set; }
        global string priceBook { get; set; }
        global string txnId { get; set; }
        global string parentTxnId { get; set; }   // for refund or reversal
        global string last4digits { get; set; }
        global date cardExpiration { get; set; }  // last day of valid month
        global string currencyCode { get; set; }
        global decimal exchangeRate { get; set; }
        global decimal totalAmount { get; set; }
        global decimal fee { get; set; }
        global decimal tax { get; set; }
        global decimal shipping { get; set; }
        global decimal insurance { get; set; }
        global decimal shippingDiscount { get; set; }
        global decimal handling { get; set; }
        global List<Item> itemList { get; set; }
        global string invoice { get; set; }
        global string reasonCode { get; set; }
        global string memo { get; set; }

        // use the custom field to pass additional details you need, such as the campaign for the opportunity
        // one creative idea is to pass JSON in this property to set any custom fields in Salesforce
        global string custom { get; set; }

        // properties for recurring payment or subscription
        global string recurringTxnId { get; set; }  
        global RecurringPeriod pmtPeriod { get; set; }
        global integer frequency { get; set; }          // combine with period above, e.g. every 1 Month
        global integer occurrences { get; set; }
        global date startDate { get; set; }

        // you can set these to existing objects, or use the setPayer method to match or create the payer
        global id contactId { get; set; }
        global id accountId { get; set; }
    
        // after a successful call to one of the methods, this will be set to the associated opportunity, and associate that opp with a campaign
        global id opportunityId { get; set; }
        global id campaignId { get; set; }      
    
        // we will either find or create one or both of these before creating opps
        global contact payerContact { get; private set; }
        global account payerAccount { get; private set; }
        global opportunity paymentOpp { get; private set; }
    
        global boolean companyIsPayer { get; set; }     // if both contact and account are set, this determines 
                                                        // whether opp should be org or individual                                                      

        // constructor
        global PaymentData (decimal amt) {
            totalAmount = amt;
            itemList = new list<Item>();
        }
        global PaymentData (decimal amt, date start, RecurringPeriod period, integer freq) {
            this(amt);
            startDate = start;
            pmtPeriod = period;
            frequency = freq;
        } 
        
        // utility method to register card data you collect 
        public virtual void setCardData(string cardNumber, string expMonth, string expYear) {
       		try {
		       	string cnum = cardNumber.trim();
		        last4digits = ((cnum.length() < 5) ? cnum : (cnum.substring(cnum.length() - 4)));  
		        cardExpiration = 
		    		Date.newInstance(integer.valueOf(expYear), integer.valueOf(expMonth), 1).addMonths(1).addDays(-1);
		    } catch (exception e) { }
        }
    } 

    // properties for credit card payment
    global class CreditCardData {
        global string cardType { get; set; }
        global string acctNumber { get; set; }
        global string expMonth { get; set; } 
        global string expYear { get; set; }
        global string cvvCode { get; set; }
    
        global CreditCardData(string sCardType, string sAcctNumber, string sExpMonth, string sExpYear, string sCvvCode) {   
            cardType = sCardType;
            acctNumber = sAcctNumber;
            expMonth = sExpMonth;
            expYear = sExpYear;
            cvvCode = sCvvCode;
        }
    }
    
    global virtual class OnlineTxnResult {
        global boolean success { get; set; } // success with payment processor
        global string errorMessage { get; set; } // this will contain an appropriate error message if success is false
        global integer errorLineNumber { get; set; }
        global string errorStackTrace { get; set; }
        
        global boolean dbSuccess { get; set; } // success saving data (opps) to Salesforce.
        
        // this is the full set of messages or errors
        global list<OnlineTxnMessage> messages { get; set; }
        
        // this will contain an appropriate error message if success is false
        global string responseText { get; set; }

        global OnlineTxnResult( boolean fSuccess, string sResponse ) {
            success = fSuccess;
            responseText = sResponse;
            messages = new list<OnlineTxnMessage>();
        }   
    }

    global virtual class PaymentTxnResult extends OnlineTxnResult {
        global string txnId { get; set; }
        global string avsResponse { get; set; }
        global string cvvResponse { get; set; }
        
        global PaymentTxnResult() {
            super( false, null );
        }
        
        global PaymentTxnResult( boolean fSuccess, string sResponse, string sTxnId, string sAvsResponse, string sCvvResponse, string sErrMsg, list<OnlineTxnMessage> sMsgs ) {
            super( fSuccess, sResponse );
            txnId = sTxnId;
            avsResponse = sAvsResponse;
            cvvResponse = sCvvResponse;
            errorMessage = sErrMsg;
            messages.addAll(sMsgs);
        }   
    }

    global virtual class PaymentProfileResult extends OnlineTxnResult { 
        global string recurringTxnId { get; set; }
        
        global PaymentProfileResult() { 
            super( false, null );
        }

        global PaymentProfileResult( boolean fSuccess, string sResponse, string sRecurringTxnId, string sErrMsg, list<OnlineTxnMessage> sMsgs ) {
            super( fSuccess, sResponse );
            recurringTxnId = sRecurringTxnId;
            errorMessage = sErrMsg;
            messages.addAll(sMsgs);
        }   
    }

    global class OnlineTxnMessage {
        global string code;
        global string shortMessage;
        global string longMessage;          

        global OnlineTxnMessage(string sCode, string sShortMsg, string sLongMsg) {
            code = sCode;
            shortMessage = sShortMsg;
            longMessage = sLongMsg;
        }
    }

    global class PaymentOppResult {
        // enumeration of possible results from SetPayer method
        // contains a code indicating the result of trying to match to a contact or account
        global MatchResult payerMatchResult { get; private set; }

        // all data about the payment
        global PaymentData onlinePayment { get; set; }
    }
    
    /*******************************************************************************************************
    * @description Static method to create a Payment Notification record, and initialize it given the
    * specified parameters.  Optionally inserts the record into the database.
    * @param payer OnlinePayer object
    * @param pament PaymentData object
    * @param notificationType string that describes the type of notification
    * @param action PaymentAction value of PAY or AUTHORIZE
    * @param request string of the initial request (or parameters) that is recording this notification
    * @param response string of the response returned to the caller of this action
    * @param isTest boolean to track whether this is a test notification or real
    * @param processed boolean to track whether this action was processed by creating appropriate Opportunities in Salesforce
    * @param processingResult string of either the match result type if processed, or an error string if not
    * @param fInsert boolean to say whether to insert this notification record into the database 
    * @return ipn Payment Notification object
    ********************************************************************************************************/   
    global static Payment_Notification__c logNotification( OnlinePayer payer, PaymentData payment, string notificationType,  
        PaymentAction action, string request, 
        string response, boolean isTest, boolean processed, string processingResult, boolean fInsert ) {

        // create a payment record for the log
        Payment_Notification__c ipn = new Payment_Notification__c (
            Name = notificationType + ((action == null) ? '' : (' - ' + (action == PaymentAction.PAY ? 'payment' : 'authorize'))) + ((payer == null || payer.email == null) ? '' : (' for ' + payer.email)),
            notification_type__c = notificationType,
            Payment_Status__c = ( 
                (payment.pmtStatus == OnlinePayment.PaymentStatus.COMPLETED) ? 'Completed' :
                (payment.pmtStatus == OnlinePayment.PaymentStatus.AUTHORIZED) ? 'Authorized' :
                (payment.pmtStatus == OnlinePayment.PaymentStatus.PENDING) ? 'Pending' :
                (payment.pmtStatus == OnlinePayment.PaymentStatus.DECLINED) ? 'Declined' :
                (payment.pmtStatus == OnlinePayment.PaymentStatus.REVERSED) ? 'Reversed' : 
                (payment.pmtStatus == OnlinePayment.PaymentStatus.VOIDED) ? 'Void' : 
                (payment.pmtStatus == OnlinePayment.PaymentStatus.FAILED) ? 'Failed' : 'unknown'),
            Transaction_Id__c = payment.txnId,
            Recurring_Transaction_Id__c = payment.recurringTxnId,
            Payer_Email__c = (payer == null ? null : payer.email),
            Payer_ID__c = (payer == null ? null : payer.payerId),
            Payment_Amount__c = payment.totalAmount,
            Request__c = request,
            Response__c = response,
            IsTest__c = isTest,
            IsProcessed__c = processed,
            Processing_Result__c = processingResult,   // either the match result if processed, or an error if not
            opportunity__c = payment.opportunityId
        );

        // get the first item, if any
        if (payment.itemList != null && !payment.itemList.isEmpty()) {
            ipn.item_name__c = payment.itemList[0].name;
            ipn.item_number__c = payment.itemList[0].code;
        }    
        
        if (fInsert) {
            insert ipn;
        } 
        return ipn;
    }
    
    global static string getRemoteHost() { 
        string ret = '127.0.0.1';
        try {
            map<string , string> hdrs = ApexPages.currentPage().getHeaders();
            if ( hdrs.get('x-original-remote-addr') != null)
                ret =  hdrs.get('x-original-remote-addr');
            else if ( hdrs.get('X-Salesforce-SIP') != null)
                ret =  hdrs.get('X-Salesforce-SIP');
            else if ( hdrs.get('x-original-remote-host') != null)
                ret =  hdrs.get('x-original-remote-host');
        } catch (exception e) {}
        return ret;
    }
    
    static testmethod void TestAll() {
        
        // don't assume there are any configurations.
        OnlinePaymentAuthnetTest.createConfig();
        
        OnlinePayment op = new OnlinePayment();
        op = new OnlinePayment(null);
        system.assert(op.auth == null);
        system.assert(op.endpoint == null);
        system.assert(op.setDefaultProcessor(null) == false);
        system.assert(getRemoteHost() != null);
        OnlinePaymentException ope = new OnlinePaymentException();
        Item it = new Item(null, null, null, null, null, null, null);
        APIAuthorization auth = new APIAuthorization(null, null, null, null, null);
        OnlinePayer payer = new OnlinePayer();
        AddressData add = new AddressData(null, null, null, null, null, null);
        PaymentData pd = new PaymentData(10);   
        PaymentData pd2 = new PaymentData(null, null, null, null);  
        CreditCardData cc = new CreditCardData(null, null, null, null, null);
        
        OnlineTxnResult otr = new OnlineTxnResult(null, null);
        PaymentTxnResult ptr = new PaymentTxnResult(null, null, null, null, null, null, new list<OnlineTxnMessage>());
        PaymentProfileResult ppr = new PaymentProfileResult(null, null, null, null, new list<OnlineTxnMessage>());
        OnlineTxnMessage otm = new OnlineTxnMessage(null, null, null);
        PaymentOppResult por = new PaymentOppResult();
        
        // now exercise some test transactions.
        payer = new OnlinePayer('test@test.com', 'testy', 'mctest', 'testco', 
            new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
        payer.shippingAddress = new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null);

        PaymentData payment = new PaymentData(123.45);
        payment.memo = 'whoa';
        payment.tax = 10;
        payment.shipping = 20;
        payment.itemList.add( new OnlinePayment.Item( 'boo', null, null, 1, 20.2, 0, null ));
        payment.custom = 'a=b;c=d;'; // random custom string

        CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');

        OnlinePaymentAuthnetTest.testName = 'payment';
        otr = op.DoSinglePayment(payer, card, payment);
        system.assertEquals( true, otr.success );
        
        OnlinePaymentAuthnetTest.testName = 'profile';
        otr = op.CreateRecurringPayment(payer, card, payment);
        system.assertEquals( true, otr.success );

        otr = op.getTransactionDetails(payment, 'txnid');
        system.assertEquals( true, otr.success );
        
    }
    
}