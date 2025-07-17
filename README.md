# Welcome to the Azure BlobStorageSDK Module

Azure Blob Storage is a messaging as a service platform which supports queues and topics.

This library is a wrapper for CFML/ColdFusion apps to be able to interact with Azure Blob Storage via the Java SDK.

## LICENSE

Apache License, Version 2.0.

## IMPORTANT LINKS

- Source: https://github.com/Ortus-Solutions/BlobStorageSDK
- Issues: https://ortussolutions.atlassian.net/browse/BOX

## SYSTEM REQUIREMENTS

- Lucee 5+
- Adobe 2021+
- BoxLang 1+

## Installation

Install into your modules folder using the `box` cli to install

```bash
box install BlobStorageSDK
```

You are responsible for loading the jars into your application.
If this is a CFML web app, you can add this to your `Application.cfc`

```js
this.javaSettings = {
    loadPaths = directorylist( expandPath( '/modules/BlobStorageSDK/lib' ), true, 'array', '*jar' ),
    loadColdFusionClassPath = true,
    reloadOnChange = false
};
```

Or if you are using this module from the CLI, you can load the jars in a task runner or custom command in CommandBox prior to using the module like so:

```js
classLoad( 'expandPath( '/BlobStorageSDK/lib' )' );
```

## Usage

This module wraps and _simplifies_ the Java SDK. There are only a few CFCs for you to worry about, and while not 100% of the Java SDK functionality is exposed, all the major functions are here.

- Create/list/delete containers
- Upload/download/list blobs in a container
- Upload/download large files straight from/to disk

There is only one CFC you need to know about:

## Client

This is a singleton that represents the main Blob Storage client. This is a singleton which is your entry point to all blob storage operations. It doesn't contain any open connections and doesn't need to be shutdown. It can be re-used across threads.

```js
wirebox.getInstance( 'Client@BlobStorageSDK' );
```

or

```js
property name='client' inject='Client@BlobStorageSDK';
```

You can configure the client with the following module settings

```js
moduleSettings = {
    endpoint : '',
    containerName : '',
    overwrite : false,
    maxDownloadRetries : 0,
	expandPaths : true,
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
```

### Credential Types

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

## Container Management

The following methods help manage containers.  The container name is required for all of these methods.

### createContainer

Creates a new blob container with the specified name, ignoring if it already exists.

```js
client.createContainer( 'test-container-123456789' );
```

### deleteContainer

Deletes the specified blob container, ignoring if it doesn't exist or is being deleted.

```js
client.deleteContainer( 'test-container-123456789' );
```

### containerExists

Checks if a container exists, returning `true` if it does, `false` otherwise.

```js
var exists = client.containerExists( 'test-container-123456789' );
writeOutput( exists ? 'Container exists' : 'Container does not exist' );
```

### listContainers

Lists all containers in the storage account, returning an array of container objects with name, metadata, and properties.

```js
var containers = client.listContainers();
writeDump( containers );
```

## Blob Management

The following methods help manage blobs inside an existing container.  If you set a `containerName` in your module config, you can omit it from these calls. Module defaults such as `timeoutSeconds` will also default to your module settings.

### uploadBlob

Uploads a text string to a blob, replacing it if it exists when `overwrite` is `true`.

```js
client.uploadBlob(
    containerName = 'test-container-123456789',
    blobName = 'test-blob-text.txt',
    content = 'This is a test blob content.',
    overwrite = true
);
```

Uploads binary data, such as an image, to a blob, replacing it if it exists.

```js
client.uploadBlob(
    containerName = 'test-container-123456789',
    blobName = 'test-blob-image.jpg',
    content = fileReadBinary( expandPath( '/tests/resources/blhat.jpg' ) ),
    overwrite = true
);
```

### uploadBlobFromFile

Uploads a file from disk to a blob, streaming it to handle large files efficiently.

```js
client.uploadBlobFromFile(
    containerName = 'test-container-123456789',
    blobName = 'my-stored-file.txt',
    filePath = '/tests/resources/myFile.txt',
    overwrite = true
);
```

### downloadBlob

Downloads a text blob to memory, converting the binary result to a string.

```js
var content = client.downloadBlob(
    containerName = 'test-container-123456789',
    blobName = 'test-blob-text.txt'
);
writeOutput( toString( content ) ); // Outputs: This is a test blob content.
```

Downloads a binary blob, such as an image, to memory as raw binary data.

```js
var content = client.downloadBlob(
    containerName = 'test-container-123456789',
    blobName = 'test-blob-image.jpg'
);
```

### downloadBlobToFile

Downloads a blob to a local file, streaming it to disk with metadata returned.

```js
var blobProperties = client.downloadBlobToFile(
    containerName = 'test-container-123456789',
    blobName = 'test-blob-text.txt',
    filePath = '/tests/resources/downloaded_blob.txt',
    timeoutSeconds = 30,
    maxDownloadRetries = 3,
    overwrite = true
);
writeDump( blobProperties );
```

### blobExists

Checks if a blob exists in the specified container, returning `true` or `false`.

```js
var exists = client.blobExists(
    containerName = 'test-container-123456789',
    blobName = 'test-blob-text.txt'
);
writeOutput( exists ? 'Blob exists' : 'Blob does not exist' );
```

### deleteBlob

Deletes a blob from the specified container, ignoring if it doesn't exist.

```js
client.deleteBlob(
    containerName = 'test-container-123456789',
    blobName = 'test-blob-text.txt'
);
```

### listBlobs

Lists all blobs in the specified container, returning an array of blob objects.

```js
var blobs = client.listBlobs(
    containerName = 'test-container-123456789'
);
writeDump( blobs );
```

Lists blobs in the specified container that start with a given prefix, such as a subfolder.

```js
var blobs = client.listBlobs(
    containerName = 'test-container-123456789',
    prefix = 'subfolder/'
);
writeDump( blobs );
```