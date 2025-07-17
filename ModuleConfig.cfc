/**
*********************************************************************************
* Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
* www.ortussolutions.com
* ---
* Module Config.
*/
component {

	// Module Properties
	this.title 				= 'BlobStorageSDK';
	this.author 			= 'Brad Wood';
	this.version 			= '@build.version@+@build.number@';
	this.cfmapping			= 'blobstoragesdk';

	function configure(){
		settings = {
			endpoint : '',
			containerName : '',
			overwrite : false,
			maxDownloadRetries : 0,
			expandPaths : true,
			/*
				Credential Types and value option used for each:

				- type : "connectionString"
					- connectionString
				- type : "default"
					- authorityHost
					- tenantId
					- maxRetry
					- tokenRefreshOffsetSeconds
				- type : "ClientSecret"
					- authorityHost
					- tenantId
					- clientId
					- clientSecret
					- maxRetry
					- tokenRefreshOffsetSeconds
					- enablePersistentCache
				- type : "ClientCertificate"
					- authorityHost
					- tenantId
					- clientId
					- pemCertificatePath (mutex with pfxCertificatePath)
					- pfxCertificatePath (mutex with pemCertificatePath)
					- certificatePassword (only used for pfx)
					- maxRetry
					- tokenRefreshOffsetSeconds
					- enablePersistentCache
			*/
			credentials : {
				type : 'connectionString', // connectionString, default, ClientSecret, ClientCertificate
				connectionString : '',
				authorityHost : '',
				tenantId : '',
				clientId : '',
				clientSecret : '',
				pemCertificatePath : '',
				pfxCertificatePath : '',
				certificatePassword : '',
				maxRetry : 3,
				tokenRefreshOffsetSeconds : 0,
				enablePersistentCache : false
			}
		};
		
	}

	function onLoad(){
	}

	function onUnload(){
	}

}
