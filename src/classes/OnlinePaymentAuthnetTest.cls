/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description test class for authnet payments.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/

@istest
global with sharing class OnlinePaymentAuthnetTest extends OnlinePaymentAuthnet {      

    public static string testName;  

    // constructor
    global OnlinePaymentAuthnetTest( OnlinePayment.APIAuthorization authnetAuth ) { 
        super( authnetAuth );
    }  
  
    public class AuthnetHTTPException extends Exception {}
    
    // override methods for calling authnet 
    public virtual override HttpResponse execute(Http h, HttpRequest request) {
        system.debug(logginglevel.WARN, request); 
        if (testName == 'httpError') {
            throw(new AuthnetHTTPException('we hit a problem trying to contact authnet!'));
        }
        return new HttpResponse();
    } 
    public virtual override string getResponseBody(HttpResponse response) { 
        system.debug('testName is: ' + testName);
        return 
            (testName == 'payment') ? '<?xml version="1.0" encoding="utf-8"?><createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"><messages><resultCode>Ok</resultCode><message><code>I00001</code><text>Successful.</text></message></messages><transactionResponse><responseCode>1</responseCode><authCode>UFRNCF</authCode><avsResultCode>Y</avsResultCode><cvvResultCode>P</cvvResultCode><cavvResultCode>2</cavvResultCode><transId>2167035413</transId><refTransID /><transHash>B2D8232A87C233783EDCA9205423DC40</transHash><testRequest>0</testRequest><accountNumber>XXXX1491</accountNumber><accountType>Visa</accountType><messages><message><code>1</code><description>This transaction has been approved.</description></message></messages><userFields><userField><name>custom</name><value /></userField></userFields></transactionResponse></createTransactionResponse>' : 
            (testName == 'paymentError') ? '<?xml version="1.0" encoding="utf-8"?><ErrorResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"><messages><resultCode>Error</resultCode><message><code>E00003</code><text>The \'AnetApi/xml/v1/schema/AnetApiSchema.xsd:cardNumber\' element is invalid - The value \'4481582492971491sdfsdf\' is invalid according to its datatype \'String\' - The actual length is greater than the MaxLength value.</text></message></messages></ErrorResponse>' : 
            (testName == 'paymentCardError') ? '<?xml version="1.0" encoding="utf-8"?><createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"><messages><resultCode>Ok</resultCode><message><code>I00001</code><text>Successful.</text></message></messages><transactionResponse><responseCode>2</responseCode><authCode>000000</authCode><avsResultCode>P</avsResultCode><cvvResultCode /><cavvResultCode /><transId>0</transId><refTransID /><transHash>656EB54834A0E1D823551B8551D0E0F0</transHash><testRequest>1</testRequest><accountNumber /><accountType /><errors><error><errorCode>2</errorCode><errorText>This transaction has been declined.</errorText></error></errors></transactionResponse></createTransactionResponse>' :
            (testName == 'profile') ? '<?xml version="1.0" encoding="utf-8"?><ARBCreateSubscriptionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"><messages><resultCode>Ok</resultCode><message><code>I00001</code><text>Successful.</text></message></messages><subscriptionId>1231571</subscriptionId></ARBCreateSubscriptionResponse>' : 
            (testName == 'profileError') ? '<?xml version="1.0" encoding="utf-8"?><ErrorResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"><messages><resultCode>Error</resultCode><message><code>E00003</code><text>The \'AnetApi/xml/v1/schema/AnetApiSchema.xsd:length\' element is invalid - The value \'-4\' is invalid according to its datatype \'Short\' - The MinInclusive constraint failed.</text></message></messages></ErrorResponse>' :
            (testName == 'void') ? '<?xml version="1.0" encoding="utf-8"?><createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"><messages><resultCode>Ok</resultCode><message><code>I00001</code><text>Successful.</text></message></messages><transactionResponse><responseCode>1</responseCode><authCode>Z7Y3QU</authCode><avsResultCode>P</avsResultCode><cvvResultCode /><cavvResultCode /><transId>2169633434</transId><refTransID>2169633434</refTransID><transHash>4AF3058C6A1FA601A40D84EDF2114552</transHash><testRequest>0</testRequest><accountNumber>XXXX1111</accountNumber><accountType>Visa</accountType><messages><message><code>1</code><description>This transaction has been approved.</description></message></messages></transactionResponse></createTransactionResponse>' : 
            (testName == 'refund') ? '<?xml version="1.0" encoding="utf-8"?><createTransactionResponse xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd"><messages><resultCode>Ok</resultCode><message><code>I00001</code><text>Successful.</text></message></messages><transactionResponse><responseCode>1</responseCode><authCode>Z7Y3QU</authCode><avsResultCode>P</avsResultCode><cvvResultCode /><cavvResultCode /><transId>2169633434</transId><refTransID>2169633434</refTransID><transHash>4AF3058C6A1FA601A40D84EDF2114552</transHash><testRequest>0</testRequest><accountNumber>XXXX1111</accountNumber><accountType>Visa</accountType><messages><message><code>1</code><description>This transaction has been approved.</description></message></messages></transactionResponse></createTransactionResponse>' : 
            (testName == 'txnInfo') ? '' :
            'bogusResponse';
    }   
    
    static testmethod void testPayment() {
        OnlinePaymentAuthnetTest.testName = 'payment';
        OnlinePaymentAuthnetTest.createConfig();
        OnlinePaymentAuthnetTest opt = new OnlinePaymentAuthnetTest( null );
        
        OnlinePayer payer = new OnlinePayer('test@test.com', 'testy', 'mctest', 'testco', 
            new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
        payer.shippingAddress = new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null);

        PaymentData payment = new PaymentData(123.45);
        payment.memo = 'whoa';
        payment.tax = 10;
        payment.shipping = 20;
        payment.itemList.add( new OnlinePayment.Item( 'boo', null, null, 1, 20.2, 0, null ));
        payment.custom = 'a=b;c=d;'; // random custom string

        CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');

        PaymentTxnResult result = opt.CreateTransactionRequest(payer, card, payment, true, false, true);
        system.assertEquals( true, result.success );
        system.assertEquals( '2167035413', result.txnId );
        
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

    static testmethod void testPaymentError() {
        OnlinePaymentAuthnetTest.testName = 'paymentError';
        OnlinePaymentAuthnetTest.createConfig();
        OnlinePaymentAuthnetTest opt = new OnlinePaymentAuthnetTest( null );
        
        OnlinePayer payer = new OnlinePayer('paymentError@test.com', 'testy', 'mctest', 'testco', 
            new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
        PaymentData payment = new PaymentData(123.45);
        CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2000', '123');

        PaymentTxnResult result = opt.CreateTransactionRequest(payer, card, payment, true, false, true);
        system.assertEquals( false, result.success );
        system.assertEquals( null, result.txnId );
        system.assert( result.errorMessage.contains('element is invalid') );
        
        list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c
            from Payment_Notification__c where Payer_Email__c ='paymentError@test.com'];
        system.assertEquals(1, listPn.size());
        system.assertEquals('Failed', listPn[0].Payment_Status__c);
        system.assertEquals(false, listPn[0].IsProcessed__c);  
        system.assertEquals(true, listPn[0].IsTest__c);
        
    }

    static testmethod void testPaymentCardError() {
        OnlinePaymentAuthnetTest.testName = 'paymentCardError';
        OnlinePaymentAuthnetTest.createConfig();
        OnlinePaymentAuthnetTest opt = new OnlinePaymentAuthnetTest( null );
        
        OnlinePayer payer = new OnlinePayer('paymentCardError@test.com', 'testy', 'mctest', 'testco', 
            new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
        PaymentData payment = new PaymentData(123.45);
        CreditCardData card = new CreditCardData('Visa', 'DECLINE ME', '01', '2020', '123');

        PaymentTxnResult result = opt.CreateTransactionRequest(payer, card, payment, true, false, true); 
        system.assertEquals( false, result.success );
        system.assertEquals( '0', result.txnId );
        system.assert( result.errorMessage.contains('declined'), result.errorMessage );
        
        list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c
            from Payment_Notification__c where Payer_Email__c =: 'paymentCardError@test.com'];
        system.assertEquals(1, listPn.size());
        system.assertEquals('Failed', listPn[0].Payment_Status__c);
        system.assertEquals(false, listPn[0].IsProcessed__c);  
        system.assertEquals(true, listPn[0].IsTest__c);
        
    }

    static testmethod void testRecurringProfile() {
        OnlinePaymentAuthnetTest.testName = 'profile';
        OnlinePaymentAuthnetTest.createConfig();
        OnlinePaymentAuthnetTest opt = new OnlinePaymentAuthnetTest( null );
        
        OnlinePayer payer = new OnlinePayer('test@test.com', 'testy', 'mctest', null, 
            new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
        PaymentData payment = new PaymentData(1964.02, system.today().adddays(1), OnlinePayment.RecurringPeriod.MONTH, 2);
        payment.memo = 'my memo string';
        payment.invoice = 'invoice number';
        payer.shippingAddress = new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null);      
        CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2014', '123');
                    
        PaymentProfileResult result = opt.ARBCreateSubscriptionRequest(payer, card, payment, true);
        system.assertEquals( true, result.success );
        system.assertEquals( '1231571', result.recurringTxnId );

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
        system.debug(listOpp);  
        // we expect 2 opps; 1 pending for the authorization, 1 recurring for the first recurring payment.      
        system.assertEquals(2, listOpp.size());
        system.assertEquals(false, listOpp[0].StageName.contains('close'));
        system.assertEquals(false, listOpp[1].StageName.contains('close'));     
        */
    }

    static testmethod void testProfileError() {
        OnlinePaymentAuthnetTest.testName = 'profileError';
        OnlinePaymentAuthnetTest.createConfig();
        OnlinePaymentAuthnetTest opt = new OnlinePaymentAuthnetTest( null );
        
        OnlinePayer payer = new OnlinePayer('profileError@test.com', 'testy', 'mctest', 'testco', 
            new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
        PaymentData payment = new PaymentData(123.45, system.today().adddays(1), OnlinePayment.RecurringPeriod.MONTH, 0);
        CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2000', '123');

        PaymentProfileResult result = opt.ARBCreateSubscriptionRequest(payer, card, payment, true);
        system.assertEquals( false, result.success );
        system.assertEquals( null, result.recurringTxnId );
        system.assert( result.errorMessage.contains('element is invalid') );

        list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c 
            from Payment_Notification__c where Payer_Email__c =: 'profileError@test.com'];
        system.debug(listPn);
        system.assertEquals(1, listPn.size());
        system.assertEquals('Failed', listPn[0].Payment_Status__c);
        system.assertEquals(false, listPn[0].IsProcessed__c); 
        system.assertEquals(true, listPn[0].IsTest__c); 
    } 

    static testmethod void testVoidTransaction() {
        OnlinePaymentAuthnetTest.testName = 'void';
        OnlinePaymentAuthnetTest.createConfig();
        OnlinePaymentAuthnetTest opt = new OnlinePaymentAuthnetTest( null );
        
        OnlinePayment.OnlineTxnResult result = opt.VoidTransaction('my txnid', true);
        system.assertEquals( true, result.success );

        list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c 
            from Payment_Notification__c where Transaction_Id__c =: 'my txnid'];
        system.debug(listPn);
        system.assertEquals(1, listPn.size());
        system.assertEquals(true, listPn[0].IsProcessed__c); 
    }
    
    static testmethod void testRefundTransaction() {
        OnlinePaymentAuthnetTest.testName = 'refund';
        OnlinePaymentAuthnetTest.createConfig();
        OnlinePaymentAuthnetTest opt = new OnlinePaymentAuthnetTest( null );
        PaymentData payment = new PaymentData(null);
        payment.txnId = 'my txnId';
        payment.last4digits = '4321';
        
        OnlineTxnResult result = opt.RefundTransaction(payment, true, false);
        system.assertEquals( true, result.success );

        list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c 
            from Payment_Notification__c where Transaction_Id__c =: 'my txnid'];
        system.debug(listPn);
        system.assertEquals(1, listPn.size());
        system.assertEquals(true, listPn[0].IsProcessed__c); 
    }
    
    static testmethod void testHTTPError() {
        OnlinePaymentAuthnetTest.testName = 'httpError';
        OnlinePaymentAuthnetTest.createConfig();
        OnlinePaymentAuthnetTest opt = new OnlinePaymentAuthnetTest( null );
        
        OnlinePayer payer = new OnlinePayer('httpError@test.com', 'testy', 'mctest', 'testco', 
            new AddressData('123 4th', 'Seattle', 'WA', '98101', 'USA', null), null, null);
        PaymentData payment = new PaymentData(123.45, system.today().adddays(1), OnlinePayment.RecurringPeriod.MONTH, 0);
        CreditCardData card = new CreditCardData('Visa', '1234567890', '01', '2000', '123');

        PaymentProfileResult result = opt.ARBCreateSubscriptionRequest(payer, card, payment, true);
        system.assertEquals( false, result.success );
        system.assertEquals( null, result.recurringTxnId );
        system.assert( result.errorMessage.contains('we hit a problem trying to contact authnet!') );

        list<Payment_Notification__c> listPn = [select Id, Payer_Email__c, Transaction_Id__c, Recurring_Transaction_Id__c, IsProcessed__c, IsTest__c, Payment_Status__c 
            from Payment_Notification__c where Payer_Email__c =: 'httpError@test.com'];
        system.debug(listPn);
        system.assertEquals(1, listPn.size());
        system.assertEquals('Failed', listPn[0].Payment_Status__c);
        system.assertEquals(false, listPn[0].IsProcessed__c); 
        system.assertEquals(true, listPn[0].IsTest__c); 
    } 

    public static void createConfig() {
        // create a default authnet config for test
        Payment_API_Config__c config = new Payment_API_Config__c();
        config.name = 'bogus';
        config.login_id__c = 'bogus';
        config.password__c = 'bogus';
        config.signature__c = 'bogus';
        config.sandbox__c = true;
        config.processor__c = 'Authnet';
        config.Default_Connection__c = true;
        insert config;
    }   
}