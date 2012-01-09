/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description This Class is an attempt to support multiple payment processors in a generic way, so
* that we can share payment processing tools for different websites or merchant account providers.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/

global virtual class PaymentToSalesforce  { 

	// method called when class is dynamically created by ClassFactory, when
	// constructor and static initialization won't be done.
	// DERIVED CLASS MUST PROVIDE THIS OR IT WON'T SUPPORT DYNAMIC CREATION!
	global virtual void initialize() {
		
	}

	// data items that used to be in op as individual properties
	global OnlinePayment.OnlinePayer payer { 
		get {
			if (payer == null) {
				payer = new OnlinePayment.OnlinePayer(); 
			}
			return payer;
		}		
		set; 
	}
	 
	global OnlinePayment.PaymentData payment { 
		get { 
			if (payment == null) {
				payment = new OnlinePayment.PaymentData(0);
			}
			return payment;
		}
		set; 
	}
	
	// you can set these to existing objects, or use the setPayer method to match or create the payer
	global id contactId { get; set; }
	global id accountId { get; set; } 

	// after a successful call to one of the methods, this will be set to the associated opportunity
	global id opportunityId { get; set; }

	// we will either find or create one or both of these before creating opps
	global contact payerContact { get; private set; }
	global account payerAccount { get; private set; }
	global opportunity paymentOpp { get; private set; }

	global boolean companyIsPayer { get; set; }		// if both contact and account are set, this determines 
													// whether opp should be org or individual
													
	// contains a code indicating the result of trying to match to a contact or account
	global OnlinePayment.MatchResult payerMatchResult { get; private set; }	
	
	/*------------------------------------------------------------------------------------
	* setPayer method
	* tries to match payer data to an existing account or contact
	* if it does not find a match, it creates a new contact (and/or account) for the opp
	* returns void throws an exception if not successful
	*   also sets the payerMatchResult property to indicate what happened
	*
	* you can call this explicitly, but each of the other methods may want to call it
	* as a first step if the opp or payer is not already set, e.g.
	*    if (paymentOpp != null) {
	*		  // update the payment
	*	 } else if (payerContact != null || payerAccount != null || setPayer()) {
	*         // create a new payment
	*    }
	-------------------------------------------------------------------------------------*/
	global virtual void setPayer() {  }
		// for an idea of how to implement this, here is a possible outline:
		
		// look for an existing opp or installment with the specified transaction Id and set the acct/con ids based on that
		// check if the contact or account id were prefilled, use them rather than looking for a match
		// query for the payer by email, secondary email, or payerId - an external ID from paypal or authnet (be sure to query for all contact and account fields you need later)
		// if there is an email match, check last name and optionally first name as well to verify match
		// look for a matching account if we do not already have a contact match
		// if we don't have a match, create a payer account or contact; if we do, update the existing account and/or contact with new information provided 
		// if we have a payer, return true

	/*------------------------------------------------------------------------------------
	* processSinglePayment method
	* creates (or updates) an opportunity for an online payment
	* returns void throws an exception if not successful
	-------------------------------------------------------------------------------------*/
	global virtual void processSinglePayment() {  }
		// make sure we have an opp or payer, or call setPayer
		// if there is already an opp, update it
		// otherwise, create a new opp
		// if successful, set the opp id property and return true

	/*------------------------------------------------------------------------------------
	* startRecurringPayments method
	* creates (or updates) an opportunity for an online recurring payment or subscription
	* returns void throws an exception if not successful
	-------------------------------------------------------------------------------------*/	
	global virtual void startRecurringPayments() {  }
	
	/*------------------------------------------------------------------------------------
	* processRecurringPayment method
	* creates (or updates) an opportunity for an online payment associated with recurring opp
	* returns void throws an exception if not successful
	-------------------------------------------------------------------------------------*/	
	global virtual void processRecurringPayment() {  }
	
	/*------------------------------------------------------------------------------------
	* cancelRecurringPayments method
	* finds and marks the specified recurring payment opp(s) as closed or written off
	* returns void throws an exception if not successful
	-------------------------------------------------------------------------------------*/	
	global virtual void cancelRecurringPayments() {  }
	
	static testmethod void TestAll() {
		PaymentToSalesforce pay = new PaymentToSalesforce();
		pay.initialize();
		system.assert(pay.payer != null);
		system.assert(pay.payment != null);
		system.assert(pay.contactId == null);
		system.assert(pay.accountId == null);
		system.assert(pay.opportunityId == null);
		system.assert(pay.payerContact == null);
		system.assert(pay.payerAccount == null);
		system.assert(pay.paymentOpp == null);
		system.assert(pay.companyIsPayer == null);
		system.assert(pay.payerMatchResult == null);
		pay.setPayer();
		pay.processSinglePayment();
		pay.startRecurringPayments();
		pay.processRecurringPayment();
		pay.cancelRecurringPayments();
	}
}