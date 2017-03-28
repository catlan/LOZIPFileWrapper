//
//  NSFileWrapper+LOZIPFileWrapper.m
//  LOZIPFileWrapper
//
//  Created by Christopher Atlan on 26/03/16.
//  Copyright © 2016 Christopher Atlan. All rights reserved.
//

#import "NSFileWrapper+LOZIPFileWrapper.h"

#import "LOZIPFileWrapper.h"

#include "zip.h"
#include "unzip.h"
#include "ioapi_mem.h"

#include <AssertMacros.h>
#include <sys/stat.h>



#define WRITEBUFFERSIZE (16384)
#define MAXFILENAME     (256)



@implementation NSFileWrapper (LOZIPFileWrapper)

- (BOOL)writeZIPArchiveToURL:(NSURL *)URL password:(NSString *)password options:(NSFileWrapperWritingOptions)options error:(NSError **)outError;
{
    zipFile zip;
    int err = UNZ_OK;
    int errclose = UNZ_OK;
    void* buf = NULL;
    int size_buf = WRITEBUFFERSIZE;
    int opt_overwrite = APPEND_STATUS_CREATE;
    int opt_compress_level = Z_DEFAULT_COMPRESSION;
    
    zip = zipOpen64((const char*)[[URL path] UTF8String], opt_overwrite);
    if (zip == NULL)
    {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"error in unzOpen" };
        if (outError)
        {
            *outError = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorDocumentStart userInfo:userInfo];
        }
        return NO;
    }
    
    NSDictionary <NSString *, NSFileWrapper *> *fileWrappers = nil;
    if ([self isDirectory])
    {
        fileWrappers = [self fileWrappers];
    }
    else
    {
        NSString *filename = @"Untitled Document";;
        if ([self preferredFilename])
        {
            filename = [self preferredFilename];
        }
        else if ([self filename])
        {
            filename = [self filename];
        }
        fileWrappers = @{ filename : self };
    }
    
    for (NSString *key in fileWrappers)
    {
        NSFileWrapper *fileWrapper = [fileWrappers objectForKey:key];
        NSData *data = [fileWrapper regularFileContents];
        
        NSString *filename = @"Untitled Document";;
        if ([fileWrapper preferredFilename])
        {
            filename = [fileWrapper preferredFilename];
        }
        else if ([fileWrapper filename])
        {
            filename = [fileWrapper filename];
        }
        
        char savefilenameinzip[256] = {0};
        zip_fileinfo zi = {0};
        unsigned long crcFile = 0;
        int zip64 = ([data length] >= 0xffffffff);
        
        [filename getCString:savefilenameinzip maxLength:256 encoding:NSUTF8StringEncoding];
        
        crcFile = crc32(crcFile, [data bytes], (unsigned int)[data length]);
        
        
        time_t tm_t = 0;
        struct tm *filedate = 0;
        
        time( &tm_t );
        filedate = localtime(&tm_t);
        
        zi.tmz_date.tm_sec  = filedate->tm_sec;
        zi.tmz_date.tm_min  = filedate->tm_min;
        zi.tmz_date.tm_hour = filedate->tm_hour;
        zi.tmz_date.tm_mday = filedate->tm_mday;
        zi.tmz_date.tm_mon  = filedate->tm_mon ;
        zi.tmz_date.tm_year = filedate->tm_year;
        
        
        buf = (void*)malloc(size_buf);
        if (buf == NULL)
        {
            printf("Error allocating memory\n");
            return NO;
        }
        
        /* Add to zip file */
        err = zipOpenNewFileInZip3_64(zip, savefilenameinzip, &zi,
                                      NULL, 0, NULL, 0, NULL /* comment*/,
                                      (opt_compress_level != 0) ? Z_DEFLATED : 0,
                                      opt_compress_level,0,
                                      -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY,
                                      [password UTF8String], crcFile, zip64);
        
        if (err != ZIP_OK)
        {
            printf("error in opening %s in zipfile (%d)\n", savefilenameinzip, err);
            free(buf);
            return NO;
        }
        
        if (err == ZIP_OK)
        {
            int read_pos = 0;
            /* Read contents of file and write it to zip */
            do
            {
                /*
                 Could also be impl with:
                 [data enumerateByteRangesUsingBlock:^(const void * _Nonnull bytes, NSRange byteRange, BOOL * _Nonnull stop) {
                 
                 }]*/
                NSRange byteRange = NSMakeRange(read_pos, size_buf);
                if ([data length] - read_pos < size_buf)
                {
                    byteRange.length = [data length] - read_pos;
                }
                
                [data getBytes:buf range:byteRange];
                read_pos += byteRange.length;
                
                unsigned int size_read = (unsigned int)byteRange.length;
                if (size_read > 0)
                {
                    err = zipWriteInFileInZip(zip, buf, size_read);
                    if (err < 0)
                        printf("error in writing %s in the zipfile (%d)\n", savefilenameinzip, err);
                }
            }
            while ((err == ZIP_OK) && ([data length] > read_pos));
        }
        
        if (err < 0)
            err = ZIP_ERRNO;
        else
        {
            err = zipCloseFileInZip(zip);
            if (err != ZIP_OK)
                printf("error in closing %s in the zipfile (%d)\n", savefilenameinzip, err);
        }
        
        free(buf);
    }
    
    errclose = zipClose(zip, NULL);
    if (errclose != ZIP_OK)
        printf("error in closing zip (%d)\n", errclose);
    
    return (err == ZIP_OK);
}

@end
