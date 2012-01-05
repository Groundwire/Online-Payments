global virtual class OnlinePaymentPaypalAsync implements Database.Batchable<SObject>, Schedulable { 
// batch apex class to process paypal payment notifications later (via scheduled apex) 
// Written by David Habib, copyright (c) 2011 Groundwire, 1402 3rd Avenue, Suite 1000, Seattle, WA 98101
// This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
 
	global String query { get; set; } 
	
	// constructors
	global OnlinePaymentPaypalAsync() {
		//system.debug(LoggingLevel.INFO, 'creating a new PayPal batch class.');
		query = 'SELECT id, gwop__Transaction_Type__c, gwop__Transaction_Id__c, gwop__Recurring_Transaction_Id__c, ' +
				'gwop__Parent_Transaction_Id__c, gwop__Item_Name__c, gwop__Item_Number__c, gwop__Payer_Email__c, gwop__IsProcessed__c, ' +
         		'gwop__Payer_ID__c, gwop__Payment_Amount__c, gwop__Payment_Status__c, gwop__Request__c from gwop__Payment_Notification__c ' + 
       			'WHERE gwop__IsProcessed__c = false ' +
       			' AND gwop__Notification_Type__c = \'IPN / Silent Post\' ' +
       			' AND gwop__Payment_Status__c != \'Error\' AND gwop__Payment_Status__c != \'Declined\' AND gwop__Payment_Status__c != \'Failed\' ' +
       			' ORDER BY gwop__transaction_type__c DESC';
       			// FOR UPDATE not needed (nor allowed) because locking is implied for each batch.
	} 
	
	global OnlinePaymentPaypalAsync(string q) { 
		query = q; 
	}

	global database.Querylocator start(Database.BatchableContext bc) {
		//system.debug(LoggingLevel.INFO, 'start call on OnlinePaymentPaypalAsync');
		return Database.getQueryLocator(query);		 
	}

	global void execute(SchedulableContext SC) {		
		//system.debug(LoggingLevel.INFO, 'schedule an execute on OnlinePaymentPaypalAsync');
		OnlinePaymentPaypalAsync batch = new OnlinePaymentPaypalAsync();		
		id batchinstanceid = database.executeBatch (batch); // keep our batch size small to avoid too many soql's
	}

	global void execute(Database.BatchableContext bc, Sobject[] result) {
		//system.debug(LoggingLevel.INFO, 'execute call on OnlinePaymentPaypalAsync');
		PaymentListenerPaypal plp = new PaymentListenerPaypal();
		for (SObject sobj : result) {
			//system.assertEquals(false, sobj.get('IsProcessed__c'));
			plp.ProcessIPN((Payment_Notification__c)sobj, false); 
			//system.assertEquals(true, sobj.get('IsProcessed__c')); 
		} 
		
		// update the ipn records
		update result;
	}
	
	global void finish(Database.BatchableContext bc) {
		//system.debug(LoggingLevel.INFO, 'finish call on OnlinePaymentPaypalAsync');		
		// clear out old notifications
		PaymentListenerPaypal plp = new PaymentListenerPaypal();
		plp.deleteOldNotifications();		
	}

// NOTE: No real test code, because this class gets most test coverage
// from tests in PaymentListenerPaypal.cls
    static testmethod void TestAll() {
        OnlinePaymentPaypalAsync batch = new OnlinePaymentPaypalAsync('select id from gwop__Payment_Notification__c');
        id batchinstanceid = database.executeBatch (batch, 10);

	   Datetime sysTime = System.now().addSeconds(2);
	   String chron_exp = '' + sysTime.second() + ' ' + sysTime.minute() + ' ' + sysTime.hour() + ' ' + sysTime.day() + ' ' + sysTime.month() + ' ? ' + sysTime.year();
	   batch = new OnlinePaymentPaypalAsync();
	   System.schedule('PayPal IPN Async Job ' + sysTime.getTime(), chron_exp, batch);
    }
}