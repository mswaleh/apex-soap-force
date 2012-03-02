public class MetadataController {    
   
    public String optedFor{get;set;}
    public String username{get;set;}
    public String password{get;set;}
    public String orgType{get;set;}
    public String usingWhat{get;set;}
    public String selectedObject{get;set;}
    public String sessionId;
    public String csvName{get;set;}
    public Blob csvContent{get;set;}
    public List<SelectOption> objectsInOrg{get;set;}
    public Boolean showLogin{get;set;}
    
    //retrieve/deploy
    public String rdOption{get;set;}
    ApexMetadataAPI.RetrieveResult rr;
    ApexMetadataAPI.AsyncResult resultRt;
    public Boolean showPoller{get;set;}
    public String docId{get;set;}
    public Boolean showLink{get;set;}
    public String packageFile{get;set;}
    public Blob packageContent{get;set;}
    ApexMetadataAPI.DeployResult dr;
    ApexMetadataAPI.AsyncResult resultDp;
    ApexMetadataAPI.DeployOptions deployOptions;
    
    //PartnerAPI
    ApexPartnerAPI.Soap soap = new ApexPartnerAPI.Soap();
    ApexPartnerAPI.LoginResult loginresult;
    ApexPartnerAPI.DescribeGlobalResult describeResult;
    ApexPartnerAPI.DescribeGlobalSObjectResult[] sobjects;
    
    //MetadataAPI
    ApexMetadataAPI.MSMetadata meta = new ApexMetadataAPI.MSMetadata();
    ApexMetadataAPI.CustomField[] fields;

    
    public MetadataController() {
        showLogin = true;
        showLink = false;
        showPoller = false;
        objectsInOrg = new List<SelectOption>();
        objectsInOrg.add(new SelectOption('','--select an object--'));
    }       
    
    public PageReference login() {
        if(orgType == 'sandbox')soap.endpoint_x = soap.endpoint_x.replace('login','test');
        else if(orgType == 'production' && soap.endpoint_x.indexOf('test') > -1)soap.endpoint_x = soap.endpoint_x.replace('test','login');
        try {
            //loginresult = soap.login(username,password);
            loginresult = soap.login('moswaleh@ovi.com','SweetAgni19MbBr6C42Kq14gRl6Pqvn0DA');
        } catch(Exception e) {
            System.debug('***exception message***' + e.getMessage() + '****' + soap.endpoint_x);
            ApexPages.addMessages(e);
            return null;
        }
        System.debug('***metadataServerUrl**' + loginresult.metadataServerUrl);
        System.debug('***serverUrl**' + loginresult.serverUrl);
        System.debug('***sessionId**' + loginresult.sessionId);
        if(loginresult.sessionId != null) {
            showLogin = false;
            sessionId = loginresult.sessionId;            
            soap.endpoint_x = loginresult.serverUrl;
            //sessionHeader for SOAP
            ApexPartnerAPI.SessionHeader_element soapSessionHeader = new ApexPartnerAPI.SessionHeader_element();
            soapSessionHeader.sessionId = loginresult.sessionId;
            soap.SessionHeader = soapSessionHeader;

            //sessionHeader for Metadata
            ApexMetadataAPI.SessionHeader_element metaSessionHeader = new ApexMetadataAPI.SessionHeader_element();
            metaSessionHeader.sessionId = loginresult.sessionId;
            meta.SessionHeader = metaSessionHeader;
            meta.endpoint_x = loginresult.metadataServerUrl;
                        
        }
                
        if(sessionId != null){
            try {
                describeResult = soap.describeGlobal();
                sobjects = describeResult.sobjects;
            } catch(Exception e) {
                System.debug('***exception message***' + e.getMessage());
                ApexPages.addMessages(e);
            }
            
            for(ApexPartnerAPI.DescribeGlobalSObjectResult obj: sobjects) {
                if(obj.createable || obj.custom || (!(obj.label.indexOf('Tag') > -1) && !(obj.label.indexOf('History:') > -1))) {
                    objectsInOrg.add(new SelectOption(obj.name,obj.label));
                }
            }
        }
        return null;        
    }
        
    
    public PageReference createFields() {        

        String text = csvContent.toString();        
        List<String> textArray = text.split('\n');
        List<String> headers = textArray.remove(0).split(',');      
        Integer numbers = textArray.size();
        
        if(numbers > 10) {
            System.debug('numbers**'+numbers);
            Integer rounds = numbers/10;
            System.debug('rounds**'+rounds);
            for(Integer i=0;i<rounds;i++) {
                List<String> tempArray = new List<String>();
                for(Integer j=0;j<10;j++) {
                    tempArray.add(textArray.remove(0));                            
                }
                System.debug('textArray**'+textArray.size());
                System.debug('tempArray**'+tempArray);
                createFields(tempArray,headers,selectedObject);
            }
            if(textArray.size() > 0) {
                System.debug('textArray1**'+textArray);
                createFields(textArray,headers,selectedObject);
            }
        } else createFields(textArray,headers,selectedObject);
        
        return null;
    }
    
    public void createFields(String[] textArray, String[] headers, String selectedObject) {
        
        fields = new ApexMetadataAPI.CustomField[textArray.size()];        
        System.debug('textArray**'+textArray);
        for(String row: textArray) {
            ApexMetadataAPI.CustomField field = new ApexMetadataAPI.CustomField();
            Integer counter = 0;
            System.debug('row***'+row);
            for(String props: row.split(',')) {
                if(props != null && props != '') {           
                    if     (headers[counter] == 'fullName')field.fullName = selectedObject + '.' + props;
                    else if(headers[counter] == 'label')field.label = props;
                    else if(headers[counter] == 'type')field.type_x = props;
                    else if(headers[counter] == 'length')field.length = Integer.valueOf(props);
                    else if(headers[counter] == 'description')field.description = props;
                    else if(headers[counter] == 'unique')field.unique = Boolean.valueOf(props);
                    else if(headers[counter] == 'formula')field.formula = props;                                
                    counter++;
                }
            }
            fields.add(field);
        }        
        try {
            ApexMetadataAPI.AsyncResult[] result = meta.createMetadata(fields);            
            System.debug('result**************'+result);
        } catch(Exception e) {
            ApexPages.addMessages(e);
            System.debug('**exception message**' + e.getMessage());
        }        
    }
    
    public PageReference rdValAction() {                
        
        if(rdOption == 'Retrieve') {
            ApexMetadataAPI.RetrieveRequest rtReq = retrievePackage();
            resultRt = meta.retrieve(rtReq);      
            showPoller = true;
        } else if(rdOption == 'Validate' || rdOption == 'Deploy') {
            String zipFile = EncodingUtil.base64Encode(packageContent);
            deployOptions = new ApexMetadataAPI.DeployOptions();
            deployOptions.allowMissingFiles = false;
            deployOptions.autoUpdatePackage = true;         
            deployOptions.ignoreWarnings = true;
            deployOptions.performRetrieve = false;
            deployOptions.purgeOnDelete = true;
            deployOptions.rollbackOnError = true;           
            //OPTIONAL TO GIVE TEST CLASSES TO BE RUN - deployOptions.runTests
            deployOptions.singlePackage = true;
            //for production deployment it always runs/to be set for SBs
            deployOptions.runAllTests = true;
            if(rdOption == 'Validate') {
                deployOptions.checkOnly = true;
            } else deployOptions.checkOnly = false;
        }        
        return null;
    }

    public PageReference checkStatus() {
        
        resultRt = meta.checkStatus(new String[]{resultRt.id})[0];
        if(resultRt.done) {
            rr = meta.checkRetrieveStatus(resultRt.id);

            Document doc = new Document();
            doc.Body = EncodingUtil.base64Decode(rr.zipFile);
            doc.ContentType = 'application/zip';
            doc.Description = 'retrieved package at: ' + System.now();
            doc.DeveloperName = 'Retrieve_' + System.now().getTime();
            doc.FolderId = UserInfo.getUserId();
            doc.Name = 'Retrieve_' + System.now().getTime() + '.zip';
            insert doc;

            docId = doc.Id;
            showLink = true;
            showPoller = false;
        }            
        return null;
    }

    private ApexMetadataAPI.RetrieveRequest retrievePackage() {
        
        ApexMetadataAPI.RetrieveRequest rtReq = new ApexMetadataAPI.RetrieveRequest();
        rtReq.apiVersion = 23.0;
        rtReq.singlePackage = true;

        ApexMetadataAPI.Package_x unpackaged = new ApexMetadataAPI.Package_x();

        List<ApexMetadataAPI.PackageTypeMembers> types = new  List<ApexMetadataAPI.PackageTypeMembers>();
        
        //read package.xml
        String xml = packageContent.toString();
        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XMLNode root = doc.getRootElement();
        Dom.XMLNode[] allNodes = root.getChildren();

        for(Dom.XMLNode node: allNodes) {
            if(node.getName() == 'types') {
                ApexMetadataAPI.PackageTypeMembers mem = new ApexMetadataAPI.PackageTypeMembers();
                String nameOnly = '';
                List<String> members = new List<String>();
                for(Dom.XMLNode cNode: node.getChildren()) {                    
                    if(cNode.getName() == 'members') {
                        members.add(cNode.getText());
                    } else if(cNode.getName() == 'name') {
                        nameOnly = cNode.getText();
                    }
                }
                mem.name = nameOnly;
                mem.members = members;
                types.add(mem);
            }
        }

        unpackaged.types = types;
        rtReq.unpackaged = unpackaged;

        return rtReq;
    }
    
    public PageReference backToLogin() {
        showLogin = true;
        soap.logout();
        return null;
    }
    
    public static testMethod void test1() {
        MetadataController mc = new MetadataController();
        mc.login();
        mc.createFields();
        mc.retrievePackage();
    }
}