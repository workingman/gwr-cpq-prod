@isTest
public class SaltoExternalIdServiceTest {
    private static final String TEST_STANDARD_OBJECT = 'Product2';
    private static final String TEST_ID = '01I000000000000000';
    private static final String SALTO_EXTERNAL_ID_FIELD_NAME = 'TestField';
    private static final String TEST_OBJECT_NAME = 'TestSaltoExternalId';
    private static final String FLS_PROFILE_NAME = 'Admin';

    private static ToolingAPIWSDL.QueryResult createEmptyQueryResult() {
        ToolingAPIWSDL.QueryResult emptyQueryResult = new ToolingAPIWSDL.QueryResult();
        emptyQueryResult.records = new List<ToolingAPIWSDL.sObject_x>();
        return emptyQueryResult;
    }

    private static HttpResponse createHttpResponse(Integer statusCode) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(statusCode);
        return response;
    }

    private class MockMetadataService implements SaltoExternalIdService.IMetadataService { 
        public MetadataService.Metadata[] createdMetadata;
        public MetadataService.Metadata[] updatedMetadata;

        public MockMetadataService() {
            this.createdMetadata = new MetadataService.Metadata[]{};
            this.updatedMetadata = new MetadataService.Metadata[]{};
        }

        public List<MetadataService.SaveResult> createMetadata(MetadataService.Metadata[] metadata) {
            this.createdMetadata = metadata;
            List<MetadataService.SaveResult> results = new List<MetadataService.SaveResult>();
            for (Integer i = 0; i < metadata.size(); i++) {
                MetadataService.SaveResult result = new MetadataService.SaveResult();
                result.success = true;
                result.fullName = metadata[i].fullName;
                results.add(result);
            }
            return results;
        }
    
        public List<MetadataService.SaveResult> updateMetadata(MetadataService.Metadata[] metadata) {
            this.updatedMetadata = metadata;
            List<MetadataService.SaveResult> results = new List<MetadataService.SaveResult>();
            for (Integer i = 0; i < metadata.size(); i++) {
                MetadataService.SaveResult result = new MetadataService.SaveResult();
                result.success = true;
                result.fullName = metadata[i].fullName;
                results.add(result);
            }
            return results;
        }
    }

    private class MockToolingAPI implements SaltoExternalIdService.IToolingAPI {
        public List<String> inputQueries;
        private List<ToolingAPIWSDL.QueryResult> mockQueryResults; 

        public MockToolingAPI() {
            this(new List<ToolingAPIWSDL.QueryResult>{createEmptyQueryResult()});
        }

        public MockToolingAPI(List<ToolingAPIWSDL.QueryResult> mockQueryResults) {
            this.inputQueries = new List<String>();
            this.mockQueryResults = mockQueryResults;
        }

        public ToolingAPIWSDL.QueryResult queryAll(String query) {
            inputQueries.add(query);
            return this.mockQueryResults[inputQueries.size() - 1];
        }
    }

    private class MockDatabase implements SaltoExternalIdService.IDatabase {
        public List<String> inputQueries;
        private List<List<SObject>> mockQueryResults;

        
        public MockDatabase() {
            this(new List<List<SObject>>{});
        }

        public MockDatabase(List<List<SObject>> mockQueryResults) {
            this.inputQueries = new List<String>();
            this.mockQueryResults = mockQueryResults;
        }

        public List<SObject> query(String queryString) {
            inputQueries.add(queryString);
            return this.mockQueryResults[inputQueries.size() - 1];
        }
    }

    private class MockHttp implements SaltoExternalIdService.IHttp {
        public List<HttpRequest> inputRequests;

        public MockHttp() {
            this.inputRequests = new List<HttpRequest>();
        }

        public HttpResponse send(HttpRequest request) {
            this.inputRequests.add(request);
            return createHttpResponse(201);
        }
    }
        
    @isTest
    static void createSaltoIdField_fieldsDoNotExist() {
        MockMetadataService metadataService = new MockMetadataService();
        MockToolingAPI toolingAPI = new MockToolingAPI();
        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder()
            .withMetadataService(metadataService)
            .withToolingAPI(toolingAPI)
            .withFieldDeveloperName(SALTO_EXTERNAL_ID_FIELD_NAME)
            .build();
        saltoExternalIdService.createSaltoIdField(new Set<String>{TEST_OBJECT_NAME, TEST_STANDARD_OBJECT}, new Set<String>{FLS_PROFILE_NAME});
        System.assert(metadataService.createdMetadata.size() == 2, 'Expected 2 CustomField to be created');
        System.assert(metadataService.updatedMetadata.size() == 1, 'Expected 1 Profile to be updated');
    }

    @isTest
    static void createSaltoIdField_fieldsAlreadyExist() {
        MockMetadataService metadataService = new MockMetadataService();

        ToolingAPIWSDL.QueryResult customFieldQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customFieldOnStandardObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnStandardObject.TableEnumOrId = TEST_STANDARD_OBJECT;
        final ToolingAPIWSDL.sObject_x customFieldOnCustomObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnCustomObject.TableEnumOrId = TEST_ID;
        customFieldQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customFieldOnStandardObject, customFieldOnCustomObject};

        ToolingAPIWSDL.QueryResult entityDefinitionQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customObjectEntity = new ToolingAPIWSDL.sObject_x();
        customObjectEntity.QualifiedApiName = TEST_OBJECT_NAME;
        entityDefinitionQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customObjectEntity};

        MockToolingAPI toolingAPI = new MockToolingAPI(new List<ToolingAPIWSDL.QueryResult>{customFieldQueryResult, entityDefinitionQueryResult});
        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder()
            .withMetadataService(metadataService)
            .withToolingAPI(toolingAPI)
            .withFieldDeveloperName(SALTO_EXTERNAL_ID_FIELD_NAME)
            .build();
        saltoExternalIdService.createSaltoIdField(new Set<String>{TEST_OBJECT_NAME, TEST_STANDARD_OBJECT}, new Set<String>{FLS_PROFILE_NAME});

        System.assert(toolingAPI.inputQueries.size() == 2, 'Expected 2 queries to be made');
        System.assertEquals('SELECT TableEnumOrId FROM CustomField WHERE DeveloperName = \''+ SALTO_EXTERNAL_ID_FIELD_NAME + '\'', toolingAPI.inputQueries[0], 'Malformed query on CustomField');
        System.assertEquals('SELECT QualifiedApiName FROM EntityDefinition WHERE DurableId IN (\'' + TEST_ID + '\')', toolingAPI.inputQueries[1], 'Malformed query on EntityDefinition');
        System.assert(metadataService.createdMetadata.size() == 0, 'Expected No CustomField to be created');
        System.assert(metadataService.updatedMetadata.size() == 0, 'Expected No Profile to be updated');
    }

    @isTest
    static void createSaltoIdField_someFieldsExist() {
        MockMetadataService metadataService = new MockMetadataService();

        ToolingAPIWSDL.QueryResult customFieldQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customFieldOnStandardObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnStandardObject.TableEnumOrId = TEST_STANDARD_OBJECT;
        customFieldQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customFieldOnStandardObject};

        MockToolingAPI toolingAPI = new MockToolingAPI(new List<ToolingAPIWSDL.QueryResult>{customFieldQueryResult});
        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder()
            .withMetadataService(metadataService)
            .withToolingAPI(toolingAPI)
            .withFieldDeveloperName(SALTO_EXTERNAL_ID_FIELD_NAME)
            .build();
        saltoExternalIdService.createSaltoIdField(new Set<String>{TEST_OBJECT_NAME, TEST_STANDARD_OBJECT}, new Set<String>{FLS_PROFILE_NAME});
        System.assert(toolingAPI.inputQueries.size() == 1, 'Expected 1 query to be made');
        System.assertEquals('SELECT TableEnumOrId FROM CustomField WHERE DeveloperName = \''+ SALTO_EXTERNAL_ID_FIELD_NAME + '\'', toolingAPI.inputQueries[0], 'Malformed query on CustomField');
        System.assert(metadataService.createdMetadata.size() == 1, 'Expected 1 CustomField to be created');
        System.assert(metadataService.updatedMetadata.size() == 1, 'Expected 1 Profile to be updated');
    }

    @isTest
    static void createSaltoIdFieldTriggers_noTriggersExist() {
        ToolingAPIWSDL.QueryResult customFieldQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customFieldOnStandardObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnStandardObject.TableEnumOrId = TEST_STANDARD_OBJECT;
        final ToolingAPIWSDL.sObject_x customFieldOnCustomObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnCustomObject.TableEnumOrId = TEST_ID;
        customFieldQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customFieldOnStandardObject, customFieldOnCustomObject};

        ToolingAPIWSDL.QueryResult entityDefinitionQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customObjectEntity = new ToolingAPIWSDL.sObject_x();
        customObjectEntity.QualifiedApiName = TEST_OBJECT_NAME;
        entityDefinitionQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customObjectEntity};

        List<SObject> apexTriggersQueryResult = new List<SObject>();

        MockHttp http = new MockHttp();

        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder()
            .withDatabase(new MockDatabase(new List<List<SObject>>{apexTriggersQueryResult}))
            .withToolingAPI(new MockToolingAPI(new List<ToolingAPIWSDL.QueryResult>{customFieldQueryResult, entityDefinitionQueryResult}))
            .withHttp(http)
            .build();
        saltoExternalIdService.createSaltoIdFieldTriggers();
        System.assert(http.inputRequests.size() == 2, 'Expected 2 triggers to be created');
    }


    @isTest
    static void createSaltoIdFieldTriggers_allTriggersExist() {
        ToolingAPIWSDL.QueryResult customFieldQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customFieldOnStandardObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnStandardObject.TableEnumOrId = TEST_STANDARD_OBJECT;
        final ToolingAPIWSDL.sObject_x customFieldOnCustomObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnCustomObject.TableEnumOrId = TEST_ID;
        customFieldQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customFieldOnStandardObject, customFieldOnCustomObject};

        ToolingAPIWSDL.QueryResult entityDefinitionQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customObjectEntity = new ToolingAPIWSDL.sObject_x();
        customObjectEntity.QualifiedApiName = TEST_OBJECT_NAME;
        entityDefinitionQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customObjectEntity};


        ApexTrigger triggerOnStandardObject = new ApexTrigger();
        triggerOnStandardObject.TableEnumOrId = TEST_STANDARD_OBJECT;
        triggerOnStandardObject.Name = 'StandardSaltoIdTrigger';
        ApexTrigger triggerOnCustomObject = new ApexTrigger(); 
        triggerOnCustomObject.TableEnumOrId = TEST_OBJECT_NAME;
        triggerOnCustomObject.Name = 'CustomSaltoIdTrigger';

        List<SObject> apexTriggersQueryResult = new List<SObject>{triggerOnStandardObject, triggerOnCustomObject};

        MockHttp http = new MockHttp();

        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder()
            .withDatabase(new MockDatabase(new List<List<SObject>>{apexTriggersQueryResult}))
            .withToolingAPI(new MockToolingAPI(new List<ToolingAPIWSDL.QueryResult>{customFieldQueryResult, entityDefinitionQueryResult}))
            .withHttp(http)
            .build();
        saltoExternalIdService.createSaltoIdFieldTriggers();
        System.assert(http.inputRequests.isEmpty(), 'Expected no triggers to be created');
    }

    @isTest
    static void createSaltoIdFieldTriggers_someTriggersExist() {
        ToolingAPIWSDL.QueryResult customFieldQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customFieldOnStandardObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnStandardObject.TableEnumOrId = TEST_STANDARD_OBJECT;
        final ToolingAPIWSDL.sObject_x customFieldOnCustomObject = new ToolingAPIWSDL.sObject_x();
        customFieldOnCustomObject.TableEnumOrId = TEST_ID;
        customFieldQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customFieldOnStandardObject, customFieldOnCustomObject};

        ToolingAPIWSDL.QueryResult entityDefinitionQueryResult = new ToolingAPIWSDL.QueryResult();
        final ToolingAPIWSDL.sObject_x customObjectEntity = new ToolingAPIWSDL.sObject_x();
        customObjectEntity.QualifiedApiName = TEST_OBJECT_NAME;
        entityDefinitionQueryResult.records = new List<ToolingAPIWSDL.sObject_x>{customObjectEntity};


        ApexTrigger triggerOnStandardObject = new ApexTrigger();
        triggerOnStandardObject.TableEnumOrId = TEST_STANDARD_OBJECT;

        List<SObject> apexTriggersQueryResult = new List<SObject>{triggerOnStandardObject};

        MockHttp http = new MockHttp();

        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder()
            .withDatabase(new MockDatabase(new List<List<SObject>>{apexTriggersQueryResult}))
            .withToolingAPI(new MockToolingAPI(new List<ToolingAPIWSDL.QueryResult>{customFieldQueryResult, entityDefinitionQueryResult}))
            .withHttp(http)
            .build();
        saltoExternalIdService.createSaltoIdFieldTriggers();
        System.assert(http.inputRequests.size() == 1, 'Expected 1 trigger to be created');
    }

    @isTest
    static void updateSaltoId_onRecordWithNoExternalId_shouldAddExternalId() {
        Test.startTest();
        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder().build();
        TestSaltoExternalId__c record = new TestSaltoExternalId__c();

        insert record;
        saltoExternalIdService.updateSaltoId(new List<SObject>{record});
        TestSaltoExternalId__c updatedRecord = [
            SELECT Id, SaltoId__c 
            FROM TestSaltoExternalId__c 
            WHERE Id = :record.Id
        ];
        System.assertEquals(updatedRecord.Id, updatedRecord.SaltoId__c, 'Expected record SaltoId__c to equal the record Id');
        Test.stopTest();
    }

    @isTest
    static void updateSaltoId_onRecordWithExternalId_shouldNotModifyTheExternalId() {
        Test.startTest();
        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder().build();
        final String externalId = 'TestExternalId';
        TestSaltoExternalId__c record = new TestSaltoExternalId__c();
        record.SaltoId__c = externalId;
        insert record;
        saltoExternalIdService.updateSaltoId(new List<SObject>{record});
        TestSaltoExternalId__c updatedRecord = [
            SELECT Id, SaltoId__c 
            FROM TestSaltoExternalId__c 
            WHERE Id = :record.Id
        ];
        System.assertEquals(externalId, updatedRecord.SaltoId__c, 'Expected record SaltoId__c to remain the same');
        Test.stopTest();
    }

    static void updateExistingRecordsSaltoIdField_shouldPopulateMissingRecordIds() {
        Test.startTest();
        SaltoExternalIdService saltoExternalIdService = new SaltoExternalIdService.Builder().build();
        final String externalId = 'TestExternalId';
        TestSaltoExternalId__c record1 = new TestSaltoExternalId__c();
        TestSaltoExternalId__c record2 = new TestSaltoExternalId__c();
        TestSaltoExternalId__c recordWithExternalId = new TestSaltoExternalId__c();
        recordWithExternalId.SaltoId__c = externalId;

        insert new List<TestSaltoExternalId__c>{record1, record2, recordWithExternalId};

        saltoExternalIdService.updateExistingRecordsSaltoIdField();
        
        TestSaltoExternalId__c updatedRecord1 = [
            SELECT Id, SaltoId__c 
            FROM TestSaltoExternalId__c 
            WHERE Id = :record1.Id
        ];

        TestSaltoExternalId__c updatedRecord2 = [
            SELECT Id, SaltoId__c 
            FROM TestSaltoExternalId__c 
            WHERE Id = :record1.Id
        ];

        TestSaltoExternalId__c updatedRecordWithExternalId = [
            SELECT Id, SaltoId__c 
            FROM TestSaltoExternalId__c 
            WHERE Id = :record1.Id
        ];

        System.assertEquals(updatedRecord1.Id, updatedRecord1.SaltoId__c, 'Expected record SaltoId__c to equal the record Id');
        System.assertEquals(updatedRecord2.Id, updatedRecord2.SaltoId__c, 'Expected record SaltoId__c to equal the record Id');
        System.assertEquals(externalId, updatedRecordWithExternalId.SaltoId__c, 'Expected record SaltoId__c to remain the same on record that had value in the fiedl');
        Test.stopTest();
    }
}