/*******************************************************************************************************
* @author Evan Callahan, David Habib
* @date 1/9/2012
* @description Page controller for the Payment Configuration visualforce page.
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/

public with sharing class PaymentConfigController { 

	public pageReference redir() {
		return new pageReference('/a01');
	}

/* DEPRECATED

	public Payment_API_Config__c config { get; set; }
	public list<SelectOption> configOptions { get; private set; }	
	public string selection { get; set; }

	public list<Payment_API_Config__c> configList { 
		get {
			if (configList == null)
				configList = new list<Payment_API_Config__c>();
			return configList;
		} 
		private set; 
	}	
	
	protected map<string, Payment_API_Config__c> configSettingsMap;
	protected string defaultConfig;

	public PaymentConfigController() {
		configSettingsMap = Payment_API_Config__c.getAll();
		configList = configSettingsMap.values();
		config = new Payment_API_Config__c();
		config.processor__c = 'Paypal';
	}
	
	public pageReference loadConfig() {
		configSettingsMap = Payment_API_Config__c.getAll();
		configList = configSettingsMap.values();
		if (selection != null)
			config = configSettingsMap.get(selection);
		if (config == null) {
			config = new Payment_API_Config__c();
			config.processor__c = 'Paypal';
		}
		return null;
	}	
	
	public pageReference deleteConfig() {
		if (selection != null) {
			Payment_API_Config__c c = Payment_API_Config__c.getValues(selection);
			if (c != null) delete c;
		}
		configSettingsMap = Payment_API_Config__c.getAll();
		configList = configSettingsMap.values();
		config = new Payment_API_Config__c();
		config.processor__c = 'Paypal';
		return null;
	}	

	public pageReference save() {
		try {
			if (config.id == null) {
				insert config;
				configList.add(config);
				clear();
			} else { 
				update config;
				clear();
			}
		} catch (exception e) {
			apexPages.addmessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));	
		}		
		return null;
	}

	public pageReference clear() {
		selection = null;
		config = new Payment_API_Config__c();
		config.processor__c = 'Paypal';
		return null;
	}	
	
    static testMethod void testConfigPage () {
    	PaymentConfigController pcc = new PaymentConfigController();
    	
    	system.assert(pcc.configList != null);
    	integer cConfigs = pcc.configList.size();
		system.assert(pcc.config != null);
		    	
    	// set values for a new config   
    	pcc.config.Name = 'my test config';
    	pcc.config.Processor__c = 'Paypal';
    	pcc.config.Login_Id__c = 'my login';
    	pcc.config.Password__c = 'my pwd';	
    	
    	// save it
    	pcc.save();
    	
    	// make sure it is there
    	system.assertEquals(cConfigs + 1, pcc.configList.size());
    	
    	// clear the form
    	pcc.clear();
    	pcc.selection = 'my test config';
    	pcc.loadConfig();
    	
    	// make sure the data was loaded back in
    	system.assertEquals('my test config', pcc.config.Name);
    	
    	// update the config.
    	pcc.config.Name = 'my renamed test config';
    	pcc.save();
    	
    	// make sure it was just added, not a new saved.
    	pcc.loadConfig();
    	system.assertEquals(cConfigs + 1, pcc.configList.size());    	
    	
    	// now delete
    	pcc.selection = 'my renamed test config';
    	pcc.deleteConfig();
    	
    	// make sure it is gone
    	system.assertEquals(cConfigs, pcc.configList.size());
    }
*/
}