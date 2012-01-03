public with sharing class PaymentConfigController {
/*-----------------------------------------------------------------------------------------------
* Written by Evan Callahan, copyright (c) 2010 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
-----------------------------------------------------------------------------------------------*/

	public Payment_API_Config__c config { get; set; }
	public list<SelectOption> configOptions { get; private set; }	
	public list<Payment_API_Config__c> configList { get; private set; }	
	public string selection { get; set; }
	
	protected map<string, Payment_API_Config__c> configSettingsMap;
	protected string defaultConfig;

	public PaymentConfigController() {
		configSettingsMap = Payment_API_Config__c.getAll();
		configList = configSettingsMap.values();
		if (configList.isEmpty()) configList = null;
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
			} else { 
				update config;
			}
		} catch (exception e) {
			apexPages.addmessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));				
		}		
		return null;
	}

	public pageReference clear() {
		config = new Payment_API_Config__c();
		config.processor__c = 'Paypal';
		return null;
	}	
	
    static testMethod void testConfigPage () {
    	PaymentConfigController pcc = new PaymentConfigController();
    	pcc.config.Processor__c = 'Paypal';
    	
    	// set values for a new config
    	
    	// save it
    	pcc.save();
    	
    	// make sure it is there
    	
    	// clear the form
    	pcc.clear();
    	pcc.selection = '';
    	pcc.loadConfig();
    	
    	// make sure the data was loaded back in
    	
    	// now delete
    	pcc.deleteConfig();
    	
    	// make sure it is gone
    }
}