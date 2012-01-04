global class OnlinePaymentAuthnetAsync implements Database.Batchable<SObject>, Database.Stateful, Schedulable { 
// batch apex class to process authnet payment notifications later (via scheduled apex)
// Written by Evan Callahan, copyright (c) 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/

    global String query { get; set; }

    global set<string> voidTxnIds;
    global set<string> priorAuthTxnIds;

    // constructors
    global OnlinePaymentAuthnetAsync() { } 
    global OnlinePaymentAuthnetAsync(string q) {  
        query = q; 
    }

    global database.Querylocator start(Database.BatchableContext bc) { 
        voidTxnIds = new set<string>();
        priorAuthTxnIds = new set<string>(); 
        return Database.getQueryLocator(query);      
    }

    global void execute(SchedulableContext SC) {
        
        // check running batches in case there are already 5 running
        AsyncApexJob[] batchInProgress = [select id from AsyncApexJob where (status = 'Queued' or status = 'Processing') and 
            ApexClass.Name = 'OnlinePaymentAuthnetAsync'];
            
        if (batchInProgress.size() < 5) {
    
            OnlinePaymentAuthnetAsync batch = new OnlinePaymentAuthnetAsync(
                'SELECT id, gwop__Transaction_Type__c, gwop__Transaction_Id__c, gwop__Recurring_Transaction_Id__c, gwop__Item_Name__c, gwop__Payer_Email__c, ' +
                    ' gwop__Payer_ID__c, gwop__Payment_Amount__c, gwop__Payment_Status__c, gwop__Request__c from gwop__Payment_Notification__c ' + 
                    ' WHERE gwop__IsProcessed__c = false AND gwop__IsTest__c = false AND gwop__transaction_type__c != null ' +
	       			' AND gwop__Notification_Type__c = \'IPN / Silent Post\' ' +
                    ' AND gwop__Payment_Status__c != \'Error\' AND gwop__Payment_Status__c != \'Declined\' AND gwop__Payment_Status__c != \'Failed\' ' +
                    ' ORDER BY gwop__transaction_type__c DESC '        
            );
            id batchinstanceid = database.executeBatch (batch, 10);
        }  
    }

    global void execute(Database.BatchableContext bc, Sobject[] result) {

        for (sobject o : result) {
                
            Payment_Notification__c ipn = (Payment_Notification__c)o;

            // unpack all params from the long text field
            map<string,string> params = new map<string,string>();
            if (ipn.Request__c != null) {
                for ( string paramLine : ipn.Request__c.split('\n') ) {
                    list<string> keyAndValue = paramLine.split(' => ');
					if (keyAndValue.size() == 2) params.put(keyAndValue[0], keyAndValue[1]);
                }
            } 

            // now actually try to do something with the data
            string txnId = ipn.transaction_id__c;
            string txnType = ipn.transaction_type__c.toLowerCase();

            if (txnType == 'void')
                voidTxnIds.add(txnId);
                    
            if (txnType == 'prior_auth_capture')
                priorAuthTxnIds.add(txnId);
                
            // if this is already voided, or if it is an auth_only that is also captured,  
            // do nothing but mark the notification record as processed 
            if ((voidTxnIds.contains(txnId) && txnType != 'void') ||
                (priorAuthTxnIds.contains(txnId) && txnType == 'auth_only')) { 
                    
                ipn.isProcessed__c = true;
                    
            } else {
                PaymentListenerAuthnet processor =  new PaymentListenerAuthnet(params);
                processor.sendPaymentToProcessor(ipn);
            }
        } 
        // log the ipn record
        update result;
    }
    
    global void finish(Database.BatchableContext bc) {
    }

    static string nv(string s) { return ((s==null || s.trim()=='') ? null : s.trim()); } 
}