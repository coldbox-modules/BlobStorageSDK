/**
*********************************************************************************
* Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
* www.ortussolutions.com
* ---
* Azure Blob Storage Client.  This is a singleton that represents your entrypoint into all blob storage operations.
*/
component accessors=true singleton ThreadSafe {

	// DI
	property name="settings" inject="box:moduleSettings:BlobStorageSDK";
	property name="wirebox" inject="wirebox";
	property name="moduleConfig" inject="box:moduleConfig:BlobStorageSDK";
	property name="interceptorService" inject="box:InterceptorService";
	property name="log" inject="logbox:logger:{this}";

	property name="jBlobService";
	property name="base64Encoder";
	property name="StandardOpenOptions";

	/**
	 * Constructor
	 */
	function init(){
		variables.noneContext = createObject( 'java', 'com.azure.core.util.Context' ).NONE;
		setStandardOpenOptions( createObject( 'java', 'java.nio.file.StandardOpenOption' ) );
		return this;
	}

	/**
	 * Finish constructing our client
	 */
	function onDIComplete(){
		// Create this once as a singleton.  It holds no state and no open connections.
		setJBlobService( newBlobService() );
		setBase64Encoder( createObject("java", "java.util.Base64").getEncoder() );
		log.debug( 'Blob Storage client intialized.' );
		interceptorService.registerInterceptor(
			interceptor 	= this,
			interceptorObject 	= this,
			interceptorName 	= "BlobStorageSDK-client"
		);
	}


	// TODO: implement these methods
	/* 
		
		
		getStatistics()
		getProperties()
		setProperties(BlobServiceProperties properties)
		getAccountInfo()
		findBlobsByTags()
		findBlobsByTags() // searches across all containers
	*/

	/**
	 * Create a Blob Container
	 * 
	 * @containerName The name of the container to create
	 */
	function createContainer( required string containerName ) {
		/*
		This name may only contain lowercase letters, numbers, and hyphens, and must begin with a letter or a number. 
		Each hyphen must be preceded and followed by a non-hyphen character.
		The name must also be between 3 and 63 characters long.
		*/
		if (
			containerName.len() < 3 || containerName.len() > 63 ||
			!reFind( "^[a-z0-9]([a-z0-9\-]*[a-z0-9])?$", containerName ) ||
			find( "--", containerName ) 
		) {
			throw(
				type = "BlobStorage.InvalidContainerName",
				message = "Invalid container name: #containerName#. The name must be 3-63 characters, only lowercase letters, numbers, and hyphens, must start with a letter or number, and hyphens must be surrounded by non-hyphens."
			);
		}
		try {
			getJBlobService().createBlobContainer( containerName );
		} catch ( any e ) {
			if( !e.message contains 'ContainerAlreadyExists' ) {
				rethrow;
			}
		}
		return this;
	}

	/**
	 * Delete a Blob Container
	 * @containerName The name of the container to delete
	 */
	function deleteContainer( required string containerName ) {
		try {
			getJBlobService().deleteBlobContainer( containerName );
		} catch ( any e ) {
			if( !e.message contains 'ContainerNotFound' && !e.message contains 'ContainerBeingDeleted' ) {
				rethrow;
			}
		}
		return this;
	}

	/**
	 * Check if a Blob Container exists
	 * @containerName The name of the container to check
	 * @return True if the container exists, false otherwise
	 */
	function containerExists( required string containerName ) {
		return getContainerClient( containerName ).exists();
	}

	/**
	 * List all Blob Containers
	 * @return An array of container objects with name, metadata, properties, etc.
	 */
	function listContainers() {
		return arrayMap( getJBlobService().listBlobContainers().stream().toList(), (c)=>{
			var prop = c.getProperties();
			return {
				"name": c.getName(),
				"metadata": {}.append( c.getMetadata() ?: {} ),
				"version": c.getVersion() ?: '',
				"isDeleted": c.isDeleted() ?: false,
				"properties": {
					"defaultEncryptionScope": prop.getDefaultEncryptionScope(),
					"deletedTime": prop.getDeletedTime() ?: '',
					"etag": prop.getETag(),
					"lastModified": prop.getLastModified().toString(),
					"leaseDuration": prop.getLeaseDuration() ?: '',
					"leaseState": prop.getLeaseState().toString(),
					"leaseStatus": prop.getLeaseStatus().toString(),
					"publicAccess": prop.getPublicAccess() ?: '',
					"remainingRetentionDays": prop.getRemainingRetentionDays() ?: '',
					"encryptionScopeOverridePrevented": prop.isEncryptionScopeOverridePrevented(),
					"hasImmutabilityPolicy": prop.isHasImmutabilityPolicy(),
					"hasLegalHold": prop.isHasLegalHold(),
					"immutableStorageWithVersioningEnabled": prop.isImmutableStorageWithVersioningEnabled()
				}
			};
		} );
	}

	/**
	 * Upload a Blob
	 * @containerName The name of the container to upload the blob to
	 * @blobName The name of the blob to upload
	 * @content The content of the blob
	 * @overwrite Whether to overwrite the blob if it already exists
	 * @timeoutSeconds The timeout for the upload operation
	 */
	function uploadBlob( required string containerName=settings.containerName, required string blobName, required any content, boolean overwrite=settings.overwrite, numeric timeoutSeconds=60 ) {
		if( !overwrite && blobExists( containerName, blobName, timeoutSeconds ) ) {
			throw(
				type = "BlobStorage.BlobAlreadyExists",
				message = "Blob '#blobName#' already exists in container '#containerName#'. Use overwrite=true to replace it."
			);
		}

		var timeoutDuration = getDuration( timeoutSeconds );
		var blobClient = getContainerClient( containerName ).getBlobClient( blobName );
		var binaryData = createObject( 'java', 'com.azure.core.util.BinaryData' ).fromBytes( isBinary( content ) ? content : toString( content ).getBytes() );
		var uploadOptions = createObject( 'java', 'com.azure.storage.blob.options.BlobParallelUploadOptions' ).init( binaryData );
		blobClient.uploadWithResponse( uploadOptions, timeoutDuration, noneContext );
		return this;
	}

	/**
	 * Upload a Blob from a local file.  The benefit of this method is that it can handle large files without needing to load the entire file into memory.
	 * 
	 * @containerName The name of the container to upload the blob to
	 * @blobName The name of the blob to upload
	 * @filePath The path to the local file to upload
	 * @overwrite Whether to overwrite the blob if it already exists
	 * @timeoutSeconds The timeout for the upload operation
	 */
	function uploadBlobFromFile( required string containerName=settings.containerName, required string blobName, required string filePath, boolean overwrite=settings.overwrite, numeric timeoutSeconds=60 ) {
		if( !overwrite && blobExists( containerName, blobName, timeoutSeconds ) ) {
			throw(
				type = "BlobStorage.BlobAlreadyExists",
				message = "Blob '#blobName#' already exists in container '#containerName#'. Use overwrite=true to replace it."
			);
		}

		var timeoutDuration = getDuration( timeoutSeconds );
		var blobClient = getContainerClient( containerName ).getBlobClient( blobName );
		var uploadOptions = createObject( 'java', 'com.azure.storage.blob.options.BlobUploadFromFileOptions' ).init( expandPath( filePath ) );
		blobClient.uploadFromFileWithResponse( uploadOptions, timeoutDuration, noneContext );
		return this;
	}

	/**
	 * Download a Blob to memory.  
	 * 
	 * @containerName The name of the container to download the blob from
	 * @blobName The name of the blob to download
	 * @timeoutSeconds The timeout in seconds for the operation
	 * @return The content of the blob as binary data.  use toString() if you want a string response.
	 * @maxDownloadRetries The maximum number of retries for the download operation.
	 */
	function downloadBlob( required string containerName=settings.containerName, required string blobName, numeric timeoutSeconds=60, numeric maxDownloadRetries=settings.maxDownloadRetries ) {
		var timeoutDuration = getDuration( timeoutSeconds );
		var blobClient = getContainerClient( containerName ).getBlobClient( blobName );
		var response = blobClient.downloadContentWithResponse(
			getDownloadRetryOptions( maxDownloadRetries ),
			getBlobRequestConditions(),
			timeoutDuration,
			noneContext
		);
		return response.getValue().toBytes();
	}

	/**
	 * Download a Blob to a local file.  The benefit of this method is that it can handle large files without needing to load the entire file into memory.
	 * 
	 * @containerName The name of the container to download the blob from
	 * @blobName The name of the blob to download
	 * @filePath The path to the local file to save the blob to
	 * @timeoutSeconds The timeout in seconds for the operation
	 * @maxDownloadRetries The maximum number of retries for the download operation.
	 * @overwrite Whether to overwrite the file if it already exists
	 * 
	 * @return The response object containing metadata about the download operation.
	 */
	function downloadBlobToFile( required string containerName=settings.containerName, required string blobName, required string filePath, numeric timeoutSeconds=60, numeric maxDownloadRetries=settings.maxDownloadRetries, boolean overwrite=settings.overwrite ) {
		if( !overwrite && fileExists( expandPath( filePath ) ) ) {
			throw(
				type = "BlobStorage.FileAlreadyExists",
				message = "File '#filePath#' already exists. Use overwrite=true to replace it."
			);
		}
		var timeoutDuration = getDuration( timeoutSeconds );
		var blobClient = getContainerClient( containerName ).getBlobClient( blobName );

		var downloadOptions = // TODO: 	setOpenOptions(Set<OpenOption> openOptions), setParallelTransferOptions(ParallelTransferOptions parallelTransferOptions), setRange(BlobRange range), setRequestConditions(BlobRequestConditions requestConditions), setRetrieveContentRangeMd5(boolean retrieveContentRangeMd5) 
			createObject( 'java', 'com.azure.storage.blob.options.BlobDownloadToFileOptions' )
				.init( expandPath( filePath ) )
				.setDownloadRetryOptions( getDownloadRetryOptions( maxDownloadRetries ) );

		if( arguments.overwrite ) {
			openOptions = createObject( 'java', 'java.util.HashSet' ).init();
			openOptions.add(StandardOpenOptions.CREATE);
			openOptions.add(StandardOpenOptions.TRUNCATE_EXISTING);
			openOptions.add(StandardOpenOptions.WRITE);
			downloadOptions.setOpenOptions(
				openOptions
			);
		}

		var response = blobClient.downloadToFileWithResponse(
			downloadOptions,
			timeoutDuration,
			noneContext
		);
		return generateProperties( response.getValue() );
	}

	/**
	 * Check if a blob exists in a container.
	 * 
	 * @containerName The name of the container to check.
	 * @blobName The name of the blob to check.
	 * @timeoutSeconds The timeout in seconds for the operation.
	 * @return True if the blob exists, false otherwise.
	 */
	function blobExists( required string containerName=settings.containerName, required string blobName, numeric timeoutSeconds=60 ) {
		var timeoutDuration = getDuration( timeoutSeconds );
		return getContainerClient( containerName ).getBlobClient( blobName ).existsWithResponse( timeoutDuration, noneContext ).getValue();
	}

	/**
	 * Delete a blob from a container.
	 * 
	 * @containerName The name of the container to delete the blob from.
	 * @blobName The name of the blob to delete.
	 * @timeoutSeconds The timeout in seconds for the operation.
	 */
	function deleteBlob( required string containerName=settings.containerName, required string blobName, numeric timeoutSeconds=60 ) {
		var timeoutDuration = getDuration( timeoutSeconds );
		try {
			getContainerClient( containerName )
				.getBlobClient( blobName )
				.deleteWithResponse(
					// TODO: support "ONLY".  The java docs here are dumb and confusing.
					// https://javadoc.io/doc/com.azure/azure-storage-blob/12.14.2/com/azure/storage/blob/specialized/BlobClientBase.html#existsWithResponse-java.time.Duration-com.azure.core.util.Context-
					createObject( 'java', 'com.azure.storage.blob.models.DeleteSnapshotsOptionType' ).INCLUDE,
					getBlobRequestConditions(),
					timeoutDuration,
					noneContext
				);
		} catch( any e ) {
			// Ignore if the blob does not exist
			 if (e.getClass().name == 'com.azure.storage.blob.models.BlobStorageException' && e.getStatusCode() != 404) {
				rethrow;
			 }
		}

		return this;
	}

	/**
	 * List blobs for a given container.
	 * @containerName The name of the container to list blobs for.  If not specified, the module settings containerName will be used.
	 * @prefix If specified, will only list blobs that start with this prefix.  
	 * @include List of blob details to include in the response, comma-separated. properties,retrieveCopy,retrieveDeletedBlobs,retrieveDeletedBlobsWithVersions,retrieveImmutabilityPolicy,retrieveLegalHold,retrieveMetadata,retrieveSnapshots,retrieveTags,retrieveUncommittedBlobs,retrieveVersions
	 * @timeoutSeconds The timeout in seconds for the operation.
	 */
	function listBlobs(
		required string containerName=settings.containerName,
		string prefix='',
		string includeList='',
		numeric timeoutSeconds=60
	) {
		if( isNull( containerName ) || containerName.isEmpty() ) {
			throw(
				type = "BlobStorage.InvalidContainerName",
				message = "Container name is required"
			);
		}
		var timeoutDuration = getDuration( timeoutSeconds );
		var blobListDetails = createObject( "java", "com.azure.storage.blob.models.BlobListDetails" ).init();
		var includeArray = listToArray( includeList, ',' ).map( (i)=>i.trim() );
		var includeProperties = !!includeArray.len();

		blobListDetails = blobListDetails.setRetrieveCopy( !!includeArray.findNoCase( 'retrieveCopy' ) );
		blobListDetails = blobListDetails.setRetrieveDeletedBlobs( !!includeArray.findNoCase( 'retrieveDeletedBlobs' ) );
		blobListDetails = blobListDetails.setRetrieveDeletedBlobsWithVersions( !!includeArray.findNoCase( 'retrieveDeletedBlobsWithVersions' ) );
		blobListDetails = blobListDetails.setRetrieveImmutabilityPolicy( !!includeArray.findNoCase( 'retrieveImmutabilityPolicy' ) );
		blobListDetails = blobListDetails.setRetrieveLegalHold( !!includeArray.findNoCase( 'retrieveLegalHold' ) );
		blobListDetails = blobListDetails.setRetrieveMetadata( !!includeArray.findNoCase( 'retrieveMetadata' ) );
		blobListDetails = blobListDetails.setRetrieveSnapshots( !!includeArray.findNoCase( 'retrieveSnapshots' ) );
		blobListDetails = blobListDetails.setRetrieveTags( !!includeArray.findNoCase( 'retrieveTags' ) );
		blobListDetails = blobListDetails.setRetrieveUncommittedBlobs( !!includeArray.findNoCase( 'retrieveUncommittedBlobs' ) );
		blobListDetails = blobListDetails.setRetrieveVersions( !!includeArray.findNoCase( 'retrieveVersions' ) );

		var	listBlobsOptions = createObject( "java", "com.azure.storage.blob.models.ListBlobsOptions" )
			.init()
			.setPrefix( prefix )
			.setDetails( blobListDetails );

		var containerClient = getContainerClient( containerName );
		return arrayMap( containerClient.listBlobs( listBlobsOptions, timeoutDuration ).stream().toList(), (b)=> {

			var item = {
				"metadata": {}.append( b.getMetadata() ?: {} ),
				"name": b.getName(),
				"objectReplicationSourcePolicies": [].append( b.getObjectReplicationSourcePolicies() ?: [], true ),
				"snapshot": b.getSnapshot() ?: '',
				"tags": {}.append( b.getTags() ?: {} ),
				"versionId": b.getVersionId() ?: '',
				"hasVersionsOnly": b.hasVersionsOnly() ?: false,
				"isCurrentVersion": b.isCurrentVersion() ?: false,
				"isDeleted": b.isDeleted() ?: false,
				"isPrefix": b.isPrefix() ?: false
			}

			if( includeProperties ) {
				var props = b.getProperties();
				var immutabilityPolicy = props.getImmutabilityPolicy();
				item.properties = generateProperties( props );
				if( !isNull( immutabilityPolicy ) ) {
					item.properties.immutabilityPolicy = {
						"expiryTime": immutabilityPolicy.getExpiryTime()?.toString() ?: '',
						"policyMode": immutabilityPolicy.getPolicyMode()?.toString() ?: ''
					};
				}
			}
			return item;
		} );
	}
	

	/**
	 * private helper methods
	 */

	/**
	 * Convert BlobProperties or BlobItemProperties instance to a struct.
	 * 
	 * https://javadoc.io/doc/com.azure/azure-storage-blob/12.14.2/com/azure/storage/blob/models/BlobProperties.html
	 * https://javadoc.io/doc/com.azure/azure-storage-blob/12.14.2/com/azure/storage/blob/models/BlobItemProperties.html
	 */
	private function generateProperties( required props ) {
		return {
			"accessTier": props.getAccessTier()?.toString() ?: '',
			"accessTierChangeTime": props.getAccessTierChangeTime()?.toString() ?: '',
			"archiveStatus": props.getArchiveStatus()?.toString() ?: '',
			"blobSequenceNumber": props.getBlobSequenceNumber() ?: 0,
			"blobType": props.getBlobType()?.toString() ?: '',
			"cacheControl": props.getCacheControl() ?: '',
			"contentDisposition": props.getContentDisposition() ?: '',
			"contentEncoding": props.getContentEncoding() ?: '',
			"contentLanguage": props.getContentLanguage() ?: '',
			"contentLength": props?.getContentLength() ?: 0,
			"contentMd5": bytesToHex( props?.getContentMd5() ?: [] ),
			"contentType": props.getContentType() ?: '',
			"copyCompletionTime": props.getCopyCompletionTime()?.toString() ?: '',
			"copyId": props.getCopyId() ?: '',
			"copyProgress": props.getCopyProgress() ?: '',
			"copySource": props.getCopySource() ?: '',
			"copyStatus": props.getCopyStatus()?.toString() ?: '',
			"copyStatusDescription": props.getCopyStatusDescription() ?: '',
			"creationTime": props.getCreationTime()?.toString() ?: '',
			"customerProvidedKeySha256": props?.getCustomerProvidedKeySha256() ?: '',
			"deletedTime": props.getDeletedTime()?.toString() ?: '',
			"destinationSnapshot": props?.getDestinationSnapshot() ?: '',
			"etag": props.getETag() ?: '',
			"encryptionScope": props.getEncryptionScope() ?: '',
			"expiryTime": props.getExpiryTime()?.toString() ?: '',
			"immutabilityPolicy": {},
			"lastAccessedTime": props.getLastAccessedTime()?.toString() ?: '',
			"lastModified": props.getLastModified()?.toString() ?: '',
			"leaseDuration": props.getLeaseDuration()?.toString() ?: '',
			"leaseState": props.getLeaseState()?.toString() ?: '',
			"leaseStatus": props.getLeaseStatus()?.toString() ?: '',
			"rehydratePriority": props.getRehydratePriority()?.toString() ?: '',
			"remainingRetentionDays": props?.getRemainingRetentionDays() ?: 0,
			"tagCount": props.getTagCount() ?: 0,
			"hasLegalHold": props.hasLegalHold() ?: false,
			"isAccessTierInferred": props.isAccessTierInferred() ?: false,
			"isIncrementalCopy": props.isIncrementalCopy() ?: false,
			"isSealed": props.isSealed() ?: false,
			"isServerEncrypted": props.isServerEncrypted() ?: false
		};
	}

	/**
	 * https://javadoc.io/doc/com.azure/azure-storage-blob/12.14.2/com/azure/storage/blob/BlobServiceClientBuilder.html
	 * Create a new blob service client.
	 */
	private function newBlobService() {		
		var clientBuilder = createObject( 'java', 'com.azure.storage.blob.BlobServiceClientBuilder' ).init();
		var credOptions = settings.credentials;

		if( !isNull( settings.endpoint ) && !settings.endpoint.isEmpty() ) {
			clientBuilder.endpoint( settings.endpoint );
		
		}

		if( credOptions.type == 'connectionString' ) {
			clientBuilder.connectionString( credOptions.connectionString );
		} else if( credOptions.type == 'default' ) {
			var credBuilder = createObject( 'java', 'com.azure.identity.DefaultAzureCredentialBuilder' ).init();
			
			doAuthorityHost( credOptions, credBuilder );
			doTenantId( credOptions, credBuilder );
			doMaxRetry( credOptions, credBuilder );
			doTokenRefreshOffset( credOptions, credBuilder );

			clientBuilder.credential( credBuilder.build() );
		} else if( credOptions.type == 'ClientSecret' ) {
			var credBuilder = createObject( 'java', 'com.azure.identity.ClientSecretCredentialBuilder' ).init();

			doAuthorityHost( credOptions, credBuilder );
			doTenantId( credOptions, credBuilder );
			doMaxRetry( credOptions, credBuilder );
			doTokenRefreshOffset( credOptions, credBuilder );
			doClientSecret( credOptions, credBuilder );
			doEnablePersistentCache( credOptions, credBuilder );
			doClientId( credOptions, credBuilder );

			clientBuilder.credential( credBuilder.build() );
		} else if( credOptions.type == 'ClientCertificate' ) {
			var credBuilder = createObject( 'java', 'com.azure.identity.ClientCertificateCredentialBuilder' ).init();

			doAuthorityHost( credOptions, credBuilder );
			doClientId( credOptions, credBuilder );
			doTenantId( credOptions, credBuilder );
			doMaxRetry( credOptions, credBuilder );
			doTokenRefreshOffset( credOptions, credBuilder );
			doEnablePersistentCache( credOptions, credBuilder );
			doCertificatePath( credOptions, credBuilder );

			clientBuilder.credential( credBuilder.build() );
		}

		// TODO: implement the rest of the methods
		/* addPolicy(com.azure.core.http.policy.HttpPipelinePolicy pipelinePolicy)
		blobContainerEncryptionScope(BlobContainerEncryptionScope blobContainerEncryptionScope)
		clientOptions(com.azure.core.util.ClientOptions clientOptions)
		configuration(com.azure.core.util.Configuration configuration)
		customerProvidedKey(CustomerProvidedKey customerProvidedKey)
		encryptionScope(String encryptionScope)
		httpLogOptions(com.azure.core.http.policy.HttpLogOptions logOptions)
		pipeline(com.azure.core.http.HttpPipeline httpPipeline)
		retryOptions(RequestRetryOptions retryOptions)
		sasToken(String sasToken)
		serviceVersion(BlobServiceVersion version)
		*/

		return clientBuilder.buildClient();
	}

	/**
	 * helper to set the tokenRefreshOffset on the builder
	 */
	private function doTokenRefreshOffset( required struct credOptions, required builder ) {
		if( !isNull( credOptions.tokenRefreshOffsetSeconds ) && isNumeric( credOptions.tokenRefreshOffsetSeconds ) && credOptions.tokenRefreshOffsetSeconds > 0 ) {
			builder.tokenRefreshOffset( getDuration( credOptions.tokenRefreshOffsetSeconds ) );
		}
		return builder;
	}

	/**
	 * helper to set the maxRetry on the builder
	 */
	private function doMaxRetry( required struct credOptions, required builder ) {
		if( !isNull( credOptions.maxRetry ) && isNumeric( credOptions.maxRetry ) && credOptions.maxRetry > 0 ) {
			builder.maxRetry( credOptions.maxRetry );
		}
		return builder;
	}

	/**
	 * helper to set the tenantId on the builder
	 */
	private function doTenantId( required struct credOptions, required builder ) {
		if( !isNull( credOptions.tenantId ) && !credOptions.tenantId.isEmpty() ) {
			builder.tenantId( credOptions.tenantId );
		}
		return builder;
	}

	/**
	 * helper to set the authorityHost on the builder
	 */
	private function doAuthorityHost( required struct credOptions, required builder ) {
		if( !isNull( credOptions.authorityHost ) && !credOptions.authorityHost.isEmpty() ) {
			builder.authorityHost( credOptions.authorityHost );
		}
		return builder;
	}

	/**
	 * helper to set the clientSecret on the builder
	 * @credOptions The credentials options struct
	 * @builder The builder to modify
	 */
	private function doClientSecret( required struct credOptions, required builder ) {
		if( !isNull( credOptions.clientSecret ) && !credOptions.clientSecret.isEmpty() ) {
			builder.clientSecret( credOptions.clientSecret );
		}
		return builder;
	}

	/**
	 * helper to set the enablePersistentCache on the builder
	 * @credOptions The credentials options struct
	 * @builder The builder to modify
	 */
	private function doEnablePersistentCache( required struct credOptions, required builder ) {
		if( !isNull( credOptions.enablePersistentCache ) && isBoolean( credOptions.enablePersistentCache ) ) {
			builder.enablePersistentCache( credOptions.enablePersistentCache );
		}
		return builder;
	}

	/**
	 * helper to set the clientId on the builder
	 * @credOptions The credentials options struct
	 * @builder The builder to modify
	 */
	private function doClientId( required struct credOptions, required builder ) {
		if( !isNull( credOptions.clientId ) && !credOptions.clientId.isEmpty() ) {
			builder.clientId( credOptions.clientId );
		}
		return builder;
	}

	/**
	 * helper to set the certificate path on the builder
	 * @credOptions The credentials options struct
	 * @builder The builder to modify
	 */
	private function doCertificatePath( required struct credOptions, required builder ) {
		if( !isNull( credOptions.pemCertificatePath ) && !credOptions.pemCertificatePath.isEmpty() ) {
			builder.pemCertificate( credOptions.pemCertificatePath );
		} else if( !isNull( credOptions.pfxCertificatePath ) && !credOptions.pfxCertificatePath.isEmpty() ) {
			builder.pfxCertificate( credOptions.pfxCertificatePath, credOptions.certificatePassword ?: '' );
		}
		return builder;
	}

	/**
	 * Convert a byte array to a hex string. 
	 * This is for displaying MD5 hashes
	 */
	private function bytesToHex(required bytes) {
		if( isNull( bytes ) ) {
			return '';
		}
		var hex = "";
		var hexChars = "0123456789abcdef";
		for (var i = 1; i <= arrayLen(bytes); i++) {
			var byte = bytes[i];
			if (byte lt 0) {
				byte += 256; // handle signed bytes
			}
			var hi = int(byte / 16);
			var lo = byte mod 16;
			hex &= mid(hexChars, hi + 1, 1) & mid(hexChars, lo + 1, 1);
		}
		return hex;
	}

	/**
	 * Helper to get the duration object for a given number of seconds
	 * 
	 * @timeSeconds The number of seconds to create a duration for
	 * @return A java.time.Duration object representing the given seconds
	 */
	private function getDuration( required numeric timeSeconds ) {
		return createObject( "java", "java.time.Duration" ).ofSeconds( timeSeconds );
	}

	/**
	 * Build a DownloadRetryOptions object with the specified maximum number of retries.
	 */
	private function getDownloadRetryOptions( required numeric maxDownloadRetries ) {
		return createObject( 'java', 'com.azure.storage.blob.models.DownloadRetryOptions' ).init().setMaxRetryRequests( maxDownloadRetries );
	}


	/**
	 * Get the BlobRequestConditions object for blob operations.
	 * This is used to set conditions like If-Match, If-None-Match, etc.
	 * 
	 * TODO: support 
	 *  - setIfMatch(String ifMatch)
	 *  - setDateTime ifModifiedSince)
	 *  - setIfNoneMatch(String ifNoneMatch)
	 *  - setDateTime ifUnmodifiedSince)
	 *  - setLeaseId(String leaseId)
	 *  - setTagsConditions(String tagsConditions)
	 * 
	 * @return A BlobRequestConditions object
	 */
	private function getBlobRequestConditions() {
		return createObject( 'java', 'com.azure.storage.blob.models.BlobRequestConditions' ).init();
	}	
	/**
	 * Get the blob container client for a given container name.
	 * 
	 * @containerName The name of the container to get the client for
	 * @return A blob container client for the specified container
	 */
	function getContainerClient( required string containerName ) {
		return getJBlobService().getBlobContainerClient( containerName );
	}
	/**
	 * Listen to the ColdBox app reinitting or shutting down
	 */
	function preReinit() {
		log.debug( 'Framework shutdown detected.' );
		shutdown();
	}

	/**
	 * Listen to the CommandBox CLI shutting down
	 */
	function onCLIExit() {
		log.debug( 'CLI shutdown detected.' );
		shutdown();
	}

	/**
	 * Call this when the app shuts down or reinits.
	 * This is very important so that orphaned connections are not left in memory
	 */
	function shutdown() {
		lock timeout="20" type="exclusive" name="Blob Storage shutdown" {
			interceptorService.unregister( "BlobStorageSDK-client" );
		}
	}

}