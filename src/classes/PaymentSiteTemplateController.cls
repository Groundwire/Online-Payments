global virtual class PaymentSiteTemplateController {
	
	global string strURLtoCSSFile { 
        get { 
        	// only specify the css file if in the web page scenario.
            if (strURLtoCSSFile == null) {
                list<Document> listDocs = [SELECT Name, Id From Document WHERE Name = 'PaymentSiteCSS' LIMIT 1 ];
                if (listDocs.size() > 0) {
                    Document doc = listDocs[0];
                    string imageid = doc.id;
                    imageid = imageid.substring(0,15);
                    strURLToCSSFile = '/servlet/servlet.FileDownload?file=' + imageid;
                }
            }
            return strURLtoCSSFile;
        }  
        
        set;
    }

}