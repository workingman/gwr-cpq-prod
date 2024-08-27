public class SaltoExternalIdService {
    private static final String CUSTOM_OBJECT_ID_PREFIX = '01I';
    private static final String DEFAULT_SALTO_ID_FIELD_DEVELOPER_NAME = 'SaltoId';
    private static final String DEFAULT_SALTO_ID_FIELD_LABEL = 'Salto ID';
    private static final Double API_VERSION = 60.0;

    private static final String TRIGGER_SUFFIX = 'SaltoIdTrigger';

    private final String saltoIdFieldDeveloperName;  
    private final String saltoIdFieldApiName;
    private final String saltoIdFieldLabel;
    private final IMetadataService metadataService;
    private final IToolingAPI toolingAPI;
    private final IDatabase database;
    private final IHttp http;


    public class Builder {
        private IMetadataService metadataService;
        private IToolingAPI toolingAPI;
        private IDatabase database;
        private IHttp http;
        private String fieldDeveloperName;
        private String saltoIdFieldLabel;

        public Builder() {
            this.metadataService = new MetadataServiceWrapper();
            this.toolingAPI = new ToolingAPIWrapper();
            this.database = new DatabaseWrapper();
            this.fieldDeveloperName = DEFAULT_SALTO_ID_FIELD_DEVELOPER_NAME;
            this.saltoIdFieldLabel = DEFAULT_SALTO_ID_FIELD_LABEL;
            this.http = new HttpWrapper();
        }

        public Builder withMetadataService(IMetadataService metadataService) {
            this.metadataService = metadataService;
            return this;
        }

        public Builder withToolingAPI(IToolingAPI toolingAPI) {
            this.toolingAPI = toolingAPI;
            return this;
        }

        public Builder withDatabase(IDatabase database) {
            this.database = database;
            return this;
        }

        public Builder withFieldDeveloperName(String fieldDeveloperName) {
            this.fieldDeveloperName = fieldDeveloperName;
            return this;
        }

        public Builder withFieldLabel(String fieldLabel) {
            this.saltoIdFieldLabel = fieldLabel;
            return this;
        }

        public Builder withHttp(IHttp http) {
            this.http = http;
            return this;
        }

        public SaltoExternalIdService build() {
            return new SaltoExternalIdService(this);
        }
    }

    private SaltoExternalIdService(Builder builder) {
        this.metadataService = builder.metadataService;
        this.toolingAPI = builder.toolingAPI;
        this.database = builder.database;
        this.http = builder.http;
        this.saltoIdFieldDeveloperName = builder.fieldDeveloperName;
        this.saltoIdFieldApiName = builder.fieldDeveloperName + '__c';
        this.saltoIdFieldLabel = builder.saltoIdFieldLabel;
    }

    public interface IMetadataService {
        List<MetadataService.SaveResult> createMetadata(MetadataService.Metadata[] metadata);
        List<MetadataService.SaveResult> updateMetadata(MetadataService.Metadata[] metadata);
    }

    public interface IToolingAPI {
        ToolingAPIWSDL.QueryResult queryAll(String query);
    }

    public interface IDatabase {
        SObject[] query(String queryString);
    }

    public interface IHttp {
        HttpResponse send(HttpRequest request);
    }

    private class ToolingAPIWrapper implements IToolingAPI {
        private ToolingAPI toolingAPI;

        public ToolingAPIWrapper() {
            this.toolingAPI = new ToolingAPI();
        }

        public ToolingAPIWrapper(ToolingAPI toolingAPI) {
            this.toolingAPI = toolingAPI;
        }

        public ToolingAPIWSDL.QueryResult queryAll(String query) {
            return toolingAPI.queryAll(query);
        }
    }

    private class MetadataServiceWrapper implements IMetadataService {
        private MetadataService.MetadataPort service;
    
        public MetadataServiceWrapper() {
            MetadataService.MetadataPort service = new MetadataService.MetadataPort();
		    service.SessionHeader = new MetadataService.SessionHeader_element();
		    service.SessionHeader.sessionId = UserInfo.getSessionId();
            service.timeout_x = 120000; // Maximum timeout
            this.service = service;
        }
    
        public MetadataServiceWrapper(MetadataService.MetadataPort service) {
            this.service = service;
        }
    
        public List<MetadataService.SaveResult> createMetadata(MetadataService.Metadata[] metadata) {
            return service.createMetadata(metadata);
        }
    
        public List<MetadataService.SaveResult> updateMetadata(MetadataService.Metadata[] metadata) {
            return service.updateMetadata(metadata);
        }
    }

    private with sharing class DatabaseWrapper implements IDatabase {
        public SOBject[] query(String queryString) {
            return Database.query(queryString);
        }
    }

    private with sharing class HttpWrapper implements IHttp {
        public HttpResponse send(HttpRequest request) {
            return new Http().send(request);
        }
    }

    private Set<String> getObjectsWithSaltoIdField () {
        ToolingAPIWSDL.sObject_x[] customFields = this.toolingAPI.queryAll('SELECT TableEnumOrId FROM CustomField WHERE DeveloperName = \''+ this.saltoIdFieldDeveloperName + '\'').records;
        if (customFields == null || customFields.isEmpty()) {
            return new Set<String>();
        }
        Set<String> objectsWithSaltoIdField = new Set<String>();
        Set<String> objectRecordIds = new Set<String>();
        for (ToolingAPIWSDL.sObject_x field : customFields) {
            if (field.TableEnumOrId.startsWith(CUSTOM_OBJECT_ID_PREFIX)) {
                objectRecordIds.add(field.TableEnumOrId);
            } else {
                objectsWithSaltoIdField.add(field.TableEnumOrId);
            }
        }   
        if (!objectRecordIds.isEmpty()) {
            String idList = '\'' + String.join(objectRecordIds, '\',\'') + '\'';
            ToolingAPIWSDL.sObject_x[] entityDefinitions = this.toolingAPI.queryAll('SELECT QualifiedApiName FROM EntityDefinition WHERE DurableId IN (' + idList + ')').records;
            for (ToolingAPIWSDL.sObject_x entityDefinition : entityDefinitions) {
                objectsWithSaltoIdField.add(entityDefinition.QualifiedApiName);
            }
        }
        return objectsWithSaltoIdField;
    }

    private MetadataService.CustomField getField(String objectName) {
        MetadataService.CustomField field = new MetadataService.CustomField();
        field.fullName = objectName + '.' + this.saltoIdFieldApiName;
        field.label = this.saltoIdFieldLabel;
        field.unique = true;
        field.type_x = 'Text';
        field.length = 18;
        return field;
    }

    private MetadataService.Profile getFLSProfile(String profileName, Set<string> objectsToHandle) {
        MetadataService.Profile profile = new MetadataService.Profile();
        profile.fullName = profileName;
        profile.fieldPermissions = new List<MetadataService.ProfileFieldLevelSecurity>();
        profile.objectPermissions = new List<MetadataService.ProfileObjectPermissions>();
        for(String objectName : objectsToHandle) {
            MetadataService.ProfileFieldLevelSecurity fieldPermission = new MetadataService.ProfileFieldLevelSecurity();
            fieldPermission.field = objectName + '.' + this.saltoIdFieldApiName;
            fieldPermission.editable = true;
            fieldPermission.readable = true;
            profile.fieldPermissions.add(fieldPermission);
        }
        return profile;
    }

    private void handleSaveResults(String action, String typeName, List<MetadataService.SaveResult> saveResults) {
        for (MetadataService.SaveResult saveResult : saveResults) {
            if (saveResult.success) {
                System.debug(typeName + ' ' + action + ' successfully: ' + saveResult.fullName);
            } else {
                for (MetadataService.Error error : saveResult.errors) {
                    System.debug('Error on ' + typeName + ' ' + saveResult.fullName + ': ' + error.message);
                }
            }
        }
    }

    public void createSaltoIdField(Set<String> objectNames, Set<String> flsProfiles) {
        System.debug('createSaltoIdField started');
        Set<String> objectsToHandle = new Set<String>(objectNames);
        objectsToHandle.removeAll(getObjectsWithSaltoIdField());
        if (objectsToHandle.isEmpty()) {
            System.debug('No objects to handle');
            return;
        }
        System.debug('Adding Salto ID Field to the following Objects: ' + objectsToHandle);


        MetadataService.Metadata[] fields = new MetadataService.Metadata[]{};
        MetadataService.Metadata[] profiles = new MetadataService.Metadata[]{};
        // Create CustomField changes
        for (String objectName: objectsToHandle) {
            fields.add(getField(objectName));
        }
        // Create FLS Profiles changes
        for (String flsProfile: flsProfiles) {
            profiles.add(getFLSProfile(flsProfile, objectsToHandle));
        }

        // Create Fields
        List<MetadataService.SaveResult> fieldResults = this.metadataService.createMetadata(fields);
        handleSaveResults('created', 'Field', fieldResults);
        // Make fields visible in FLS Profiles
        List<MetadataService.SaveResult> profileResults = this.metadataService.updateMetadata(profiles);
        handleSaveResults('modified', 'Profile', profileResults);
        System.debug('createSaltoIdField finished');
    }

    private Set<String> getObjectsWithExistingTrigger() {
        String query = 'SELECT TableEnumOrId FROM ApexTrigger WHERE Name Like \'%' + TRIGGER_SUFFIX  + '\'';
        List<ApexTrigger> apexTriggers = this.database.query(query);
        Set<String> triggerNames = new Set<String>();
        for(ApexTrigger apexTrigger: apexTriggers) {
            triggerNames.add(apexTrigger.TableEnumOrId);
        }
        return triggerNames;
    }

    private String triggerNameFromObject (String objectName) {
        String triggerNamePrefix = objectName;
        if (triggerNamePrefix.endsWith('__c')) {
            triggerNamePrefix = triggerNamePrefix.replaceAll('__c', '');
        }
        triggerNamePrefix = triggerNamePrefix.replaceAll('_', '');
        return triggerNamePrefix + TRIGGER_SUFFIX;
    }

    private class ApexTriggerMetadata {
        public String fullName;
        public Double apiVersion;
        public String status;
        public String parentObject;
        public String content;
    }

    private ApexTriggerMetadata getTrigger(String objectName) {
        String triggerName = triggerNameFromObject(objectName);
        ApexTriggerMetadata metadataTrigger = new ApexTriggerMetadata();
        metadataTrigger.fullName = triggerName;
        metadataTrigger.parentObject = objectName;
        metadataTrigger.apiVersion = API_VERSION;
        metadataTrigger.status = 'Active';
        metadataTrigger.content = '// Generated by SaltoExternalIdService\n';
        metadataTrigger.content += 'trigger ' + triggerName + ' on ' + objectName + ' (after insert) {\n';
        metadataTrigger.content += '    new SaltoExternalIdService.Builder().withFieldDeveloperName(\'' + this.saltoIdFieldDeveloperName + '\').build().updateSaltoId(Trigger.new);\n';
        metadataTrigger.content += '}';
        return metadataTrigger;
    }

    private void createTrigger(ApexTriggerMetadata apexTrigger) {
        String toolingApiEndpoint = System.Url.getOrgDomainUrl().toExternalForm() + '/services/data/v' + API_VERSION + '/tooling/sobjects/ApexTrigger';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(toolingApiEndpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        // Prepare the JSON body for the request
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('Name', apexTrigger.fullName);
        payload.put('TableEnumOrId', apexTrigger.parentObject);
        payload.put('Body', apexTrigger.content);
        payload.put('Status', apexTrigger.status);
        payload.put('ApiVersion', apexTrigger.apiVersion);
        req.setBody(JSON.serialize(payload));

        try {
            HttpResponse res = this.http.send(req);
            if (res.getStatusCode() == 201) {
                System.debug('Trigger ' + apexTrigger.fullName +  ' created successfully');
            } else {
                System.debug('Failed to deploy trigger ' + apexTrigger.fullName + ': ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Exception occurred when attempting to create trigger' + apexTrigger.fullName + ': ' + e.getMessage());
        }
    }

    public void createSaltoIdFieldTriggers() {
        System.debug('createSaltoIdFieldTriggers started');
        Set<String> objectsWithSaltoIdField = getObjectsWithSaltoIdField();
        Set<String> objectsWithExistingTrigger = getObjectsWithExistingTrigger();
        Set<String> objectsWithMissingTrigger = new Set<String>();
        for (String objectName: objectsWithSaltoIdField) {
            if (!objectsWithExistingTrigger.contains(objectName)) {
                objectsWithMissingTrigger.add(objectName);
            }
        }
        if (objectsWithMissingTrigger.isEmpty()) {
            System.debug('No triggers to add');
            return;
        }
        System.debug('Adding triggers to the following Objects: ' + objectsWithMissingTrigger);
        for (String objectName: objectsWithMissingTrigger) {
            createTrigger(getTrigger(objectName));
        }
        System.debug('createSaltoIdFieldTriggers finished');
    }

    public void updateSaltoId(List<SObject> records) {
        // List to hold the SObjects to be updated
        List<SObject> recordsToUpdate = new List<SObject>();
        
        // Iterate over the new records
        for (SObject record : records) {
            // Get the Id of the record
            Id recordId = (Id)record.get('Id');
            // Get the current value of the specified field
            String currentFieldValue = (String)record.get(this.saltoIdFieldApiName);
            
            // Check if the field is not already set
            if (currentFieldValue == null) {
                // Create a new SObject instance and set the Id and the field
                SObject updatedRecord = record.clone(false, true, false, false);
                updatedRecord.put('Id', recordId);
                updatedRecord.put(this.saltoIdFieldApiName, recordId);
                recordsToUpdate.add(updatedRecord);
            }
        }
        
        // Perform the update outside the loop
        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
            System.debug('Successfully updated ' + recordsToUpdate.size() + ' records of type ' + recordsToUpdate[0].getSObjectType() + ' with Salto External Id Field');
        }
    }

    public void updateExistingRecordsSaltoIdField() {
        System.debug('updateExistingRecordsSaltoIdField started');
        for (String objectName: getObjectsWithSaltoIdField()) {
            List<SObject> records = this.database.query('SELECT Id, ' + this.saltoIdFieldApiName + ' FROM ' + objectName + ' WHERE ' + this.saltoIdFieldApiName + ' = null');
            updateSaltoId(records);
        }
        System.debug('updateExistingRecordsSaltoIdField finished');
    }
}