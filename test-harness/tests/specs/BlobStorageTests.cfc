component extends='coldbox.system.testing.BaseTestCase' appMapping='/root'{

/*********************************** LIFE CYCLE Methods ***********************************/

	this.unloadColdBox = true;
	this.testContainerName = "test-container-" & getTickCount();

	// executes before all suites+specs in the run() method
	function beforeAll(){
		super.beforeAll();		
	}

	// executes after all suites+specs in the run() method
	function afterAll(){
		getBSClient().shutdown();
		super.afterAll();
	}

/*********************************** BDD SUITES ***********************************/

	function run(){
		
		describe( 'BlobStorageSDK Module', function(){

			/* logManager = createObject("java", "org.apache.logging.log4j.LogManager");
			levelClass = createObject("java", "org.apache.logging.log4j.Level");
			context = logManager.getContext(false);
			config = context.getConfiguration();

			// Silence com.azure
			azureLoggerConfig = config.getLoggerConfig("com.azure");
			azureLoggerConfig.setLevel(levelClass.OFF);

			// Silence reactor.netty
			reactorLoggerConfig = config.getLoggerConfig("reactor.netty");
			reactorLoggerConfig.setLevel(levelClass.OFF);

			// Apply the changes
			context.updateLoggers(); */

			beforeEach(function( currentSpec ){
				setup();
			});

			describe( 'Client management', function(){
					
				it( 'should register library', function(){
					var sbClient = getBSClient();
					expect(	sbClient ).toBeComponent();
				});

				it( 'can add container', function(){
					var sbClient = getBSClient();
					var containerName = this.testContainerName;
					sbClient.createContainer( containerName );
				});

				it( 'can check if container exists', function(){
					var sbClient = getBSClient();
					var exists = sbClient.containerExists( this.testContainerName );
					expect( exists ).toBeBoolean();
					expect( exists ).toBeTrue();
				});

				it( 'can list containers', function(){
					var sbClient = getBSClient();
					var containers = sbClient.listContainers();
					expect( containers ).toBeArray();
					//writedump( containers );
				});

				it( 'can write blob text', function(){
					var sbClient = getBSClient();
					var blobName = "test-blob-text.txt";
					sbClient.uploadBlob( this.testContainerName, blobName, "This is a test blob content.", true );
				});

				it( 'can write blob binary', function(){
					var sbClient = getBSClient();
					var blobName = "test-blob-image.jpg";
					sbClient.uploadBlob( this.testContainerName, blobName, fileReadBinary( expandpath( '/tests/resources/blhat.jpg' ) ), true );
				});

				it( 'can write blob from file', function(){
					var sbClient = getBSClient();
					var blobName = "my-stored-file.txt";
					var filePath = '/tests/resources/myFile.txt';
					sbClient.uploadBlobFromFile( this.testContainerName, blobName, filePath, true );

					expect( sbClient.blobExists( this.testContainerName, blobName ) ).toBeTrue();
				});

				it( 'can download blob text', function(){
					var sbClient = getBSClient();
					var blobName = "test-blob-text.txt";
					sbClient.uploadBlob( this.testContainerName, blobName, "This is a test blob content.", true );
					var content = toString( sbClient.downloadBlob( this.testContainerName, blobName ) );
					expect( content ).toBeString();
					expect( content ).toBe( "This is a test blob content." );
				});

				it( 'can download blob binary', function(){
					var sbClient = getBSClient();
					var blobName = "test-blob-image.jpg";
					sbClient.uploadBlob( this.testContainerName, blobName, fileReadBinary( expandpath( '/tests/resources/blhat.jpg' ) ), true );
					var content = sbClient.downloadBlob( this.testContainerName, blobName );
					expect( content ).toBeBinary();
				});

				it( 'can download blob text to file', function(){
					var sbClient = getBSClient();
					var blobName = "test-blob-text.txt";
					sbClient.uploadBlob( this.testContainerName, blobName, "This is a test blob content.", true );
					var filePath = '/tests/resources/downloaded_blob.txt';
					var blobProperties = sbClient.downloadBlobToFile( this.testContainerName, blobName, filePath, 30, 3, true );
					expect( fileExists( expandPath( filePath ) ) ).toBeTrue();
					expect( toString( fileRead( expandPath( filePath ) ) ) ).toBe( "This is a test blob content." );
					expect( blobProperties ).toBeStruct();
				});

				it( 'can check if blob exists', function(){
					var sbClient = getBSClient();
					var blobName = "test-blob-text.txt";
					sbClient.uploadBlob( this.testContainerName, blobName, "This is a test blob content.", true );
					var exists = sbClient.blobExists( this.testContainerName, blobName );
					expect( exists ).toBeBoolean();
					expect( exists ).toBeTrue();
				});

				it( 'can delete blob', function(){
					var sbClient = getBSClient();
					var blobName = "test-blob-text.txt";
					sbClient.uploadBlob( this.testContainerName, blobName, "This is a test blob content.", true );
					sbClient.deleteBlob( this.testContainerName, blobName );
					sbClient.deleteBlob( this.testContainerName, blobName );
					sbClient.deleteBlob( this.testContainerName, blobName );
					sbClient.deleteBlob( this.testContainerName, blobName );
				});

				it( 'can list blobs in container', function(){
					var sbClient = getBSClient();
					var blobName = "test-blob-text.txt";
					sbClient.uploadBlob( this.testContainerName, blobName, "This is a test blob content.", true );
					blobs = sbClient.listBlobs( this.testContainerName );
					expect( blobs ).toBeArray();
					expect( blobs.len() ).toBeGT( 0 );
				//	writedump( blobs );
				});

				it( 'can list blobs in container with prefix', function(){
					var sbClient = getBSClient();
					var blobName = "subfolder/test-blob-text.txt";
					sbClient.uploadBlob( this.testContainerName, blobName, "This is a test blob content.", true );
					blobs = sbClient.listBlobs( this.testContainerName, 'subfolder/' );
					expect( blobs ).toBeArray();
					expect( blobs.len() ).toBeGT( 0 );
				//	writedump( blobs );
				});

				it( 'can delete container', function(){
					var sbClient = getBSClient();
					sbClient.deleteContainer( this.testContainerName );
				});
	
			});
		});
				
	}

	private function getBSClient( name='Client@BlobStorageSDK' ){
		return getWireBox().getInstance( name );
	}

}