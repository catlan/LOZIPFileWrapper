[![Build Status](https://travis-ci.org/catlan/LOZIPFileWrapper.svg)](https://travis-ci.org/catlan/LOZIPFileWrapper)

# LOZIPFileWrapper

LOZIPFileWrapper is a Cocoa wrapper around minizip. 

Features:

* `-[LOZIPFileWrapper initWithURL:]` for unzipping file based zips
* `-[LOZIPFileWrapper initWithZIPData:]` for unzipping memory based zips

* `-[LOZIPFileWrapper contentOfZIPFileIncludingFolders:error:]` list of filenames in the zip archive
* `-[LOZIPFileWrapper contentAttributesOfZIPFileIncludingFolders:error:]` dictionary of item details like compressed size, size, encryption in the zip archive
* `-[LOZIPFileWrapper contentsAtPath:error:]` NSData for item in the zip archive
* `-[LOZIPFileWrapper writeContentOfZIPFileToURL:options:error:error` extract zip archive to a folder.

## Adding to your project

1. Add `LOZIPFileWrapper.h`, `LOZIPFileWrapper.m`, and `minizip` (required are `zip.c`, `zip.h`, `unzip.c`, `unzip.h`, `ioapi.c`, `ioapi.h`, `ioapi_mem.c`, `ioapi_mem.h`.) to your project.
2. Add the `libz` library to your target
 
## Write Support
 
 My usage just required reading zips. If somebody is intrested in write support I would suggest to start  with having a look at minizip.c [https://github.com/nmoinvaz/minizip/blob/master/minizip.c]

## License

LOZIPFileWrapper is licensed under the [MIT license](https://github.com/catlan/LOZIPFileWrapper/raw/master/LICENSE).  A version of [Minizip](http://www.winimage.com/zLibDll/minizip.html) is also included and is licensed under the [Zlib license](http://www.zlib.net/zlib_license.html).

## Thanks

Thanks [nmoinvaz](https://github.com/nmoinvaz/minizip) for keeping [minizip](https://github.com/nmoinvaz/minizip) up-to-date. And to everybody in the miniunz.c copyright.
