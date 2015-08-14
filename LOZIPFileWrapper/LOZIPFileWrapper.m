//
//  LOZIPFileWrapper.m
//  
//
//  Created by Christopher Atlan on 13/08/15.
//
//

#import "LOZIPFileWrapper.h"

#include "zip.h"
#include "unzip.h"
#include "ioapi_mem.h"

#include <sys/stat.h>


#define CHUNK 16384

#define WRITEBUFFERSIZE (8192)
#define MAXFILENAME     (256)


NSString *const LOZIPFileWrapperCompressedSize = @"LOZIPFileWrapperCompressedSize";
NSString *const LOZIPFileWrapperCompresseRation = @"LOZIPFileWrapperCompresseRation";
NSString *const LOZIPFileWrapperEncrypted = @"LOZIPFileWrapperEncrypted";
NSString *const LOZIPFileWrapperErrorDomain = @"LOZIPFileWrapperErrorDomain";

@interface LOZIPFileWrapper () {
    zipFile zip;
    ourmemory_t *unzmem;
}

// For reading
@property (copy) NSURL *URL;
@property (copy) NSData *ZIPData;
@property (copy) NSString *password;

@end

@implementation LOZIPFileWrapper

- (instancetype)initWithURL:(NSURL *)URL password:(NSString *)password error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        self.URL = URL;
        self.password = password;
        
        zip = unzOpen((const char*)[[URL path] UTF8String]);
        if (zip == NULL)
        {
            NSString *desc = @"error in unzOpen";
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
            if (error)
            {
                *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
            }
            return nil;
        }
    }
    return self;
}

- (instancetype)initWithZIPData:(NSData *)data password:(NSString *)password error:(NSError **)error
{
    self = [super init];
    if (self)
    {
        self.ZIPData = data;
        self.password = password;
        
        zlib_filefunc_def filefunc32 = {0};
        unzmem = malloc(sizeof(ourmemory_t));
        
        unzmem->grow = 1;
        
        unzmem->size = [data length];
        unzmem->base = (char *)malloc(unzmem->size);
        memcpy(unzmem->base, [data bytes], unzmem->size);
        
        fill_memory_filefunc(&filefunc32, unzmem);
        
        zip = unzOpen2("__notused__", &filefunc32);
        if (zip == NULL)
        {
            NSString *desc = @"error in unzOpen2";
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
            if (error)
            {
                *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
            }
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (zip)
    {
        unzClose(zip);
    }
    if (unzmem)
    {
        if (unzmem->base)
        {
            free(unzmem->base);
        }
        free(unzmem);
    }
}

#pragma mark - Reading ZIP Archives

- (BOOL)writeContentOfZIPFileToURL:(NSURL *)URL options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)error
{
    return [self internalWriteContentToURL:URL options:writeOptionsMask error:error];
}

- (NSArray *)contentOfZIPFileIncludingFolders:(BOOL)includeFolders error:(NSError **)error
{
    NSDictionary *contentsOfArchive = nil;
    contentsOfArchive = [self contentAttributesOfZIPFileIncludingFolders:includeFolders error:error];
    if (contentsOfArchive)
    {
        return [[contentsOfArchive keyEnumerator] allObjects];
    }
    return nil;
}

- (NSDictionary *)contentAttributesOfZIPFileIncludingFolders:(BOOL)includeFolders error:(NSError **)error
{
    NSMutableDictionary *contentsOfArchive = [NSMutableDictionary dictionary];
    
    int err = unzGoToFirstFile(zip);
    if (err != UNZ_OK)
    {
        NSString *desc = [NSString stringWithFormat:@"error %d with zipfile in unzGoToFirstFile", err];
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return nil;
    }
    
    do
    {
        char filename_inzip[MAXFILENAME] = {0};
        unz_file_info64 file_info = {0};
        uLong ratio = 0;
        BOOL encrypted = NO;
#ifdef MORE_DETAILS_IMPL
        const char *string_method = NULL;
#endif
        
        err = unzGetCurrentFileInfo64(zip, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
        if (err != UNZ_OK)
        {
            NSLog(@"LOZIPFileWrapper: error %d with zipfile in unzGetCurrentFileInfo", err);
            break;
        }
        
        if (file_info.uncompressed_size > 0)
            ratio = (uLong)((file_info.compressed_size*100) / file_info.uncompressed_size);
        
        /* Display a '*' if the file is encrypted */
        if ((file_info.flag & 1) != 0)
            encrypted = YES;
        
#ifdef MORE_DETAILS_IMPL
        if (file_info.compression_method == 0)
            string_method = "Stored";
        else if (file_info.compression_method == Z_DEFLATED)
        {
            uInt iLevel = (uInt)((file_info.flag & 0x6) / 2);
            if (iLevel == 0)
                string_method = "Defl:N";
            else if (iLevel == 1)
                string_method = "Defl:X";
            else if ((iLevel == 2) || (iLevel == 3))
                string_method = "Defl:F"; /* 2:fast , 3 : extra fast*/
        }
        else if (file_info.compression_method == Z_BZIP2ED)
        {
            string_method = "BZip2 ";
        }
        else
            string_method = "Unkn. ";
#endif
        
        NSString *filename = [[NSString alloc] initWithBytes:filename_inzip
                                                      length:file_info.size_filename
                                                    encoding:NSUTF8StringEncoding];
        // Contains a path
        if ([filename rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location != NSNotFound)
        {
            filename = [filename stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        }
        
        
        NSDictionary *itemAttributes = nil; // Used in our delegates, includes compressed and uncompressed size.
        NSDate *fileDate = [[self class] dateFromTM_UNZ:&file_info.tmu_date];
        itemAttributes = @{ NSFileCreationDate : fileDate, NSFileModificationDate : fileDate,  NSFileSize : @(file_info.uncompressed_size), LOZIPFileWrapperCompressedSize : @(file_info.compressed_size), LOZIPFileWrapperCompresseRation : @(ratio),  LOZIPFileWrapperEncrypted : @(encrypted) };
        
        
        if (contentsOfArchive)
        {
            NSString *parentPath = [filename stringByDeletingLastPathComponent];
            while (includeFolders && ![parentPath isEqualToString:@""] &&  ![contentsOfArchive valueForKey:parentPath])
            {
                // this makes a wrong file list order because /1/2/3 would show up before /1/2.
                contentsOfArchive[parentPath] = @{ NSFileType : NSFileTypeDirectory };
                parentPath = [parentPath stringByDeletingLastPathComponent];
            }
            contentsOfArchive[filename] = itemAttributes;
        }
        
        err = unzGoToNextFile(zip);
    }
    while (err == UNZ_OK);
    
    if (err != UNZ_END_OF_LIST_OF_FILE && err != UNZ_OK)
    {
        NSString *desc = [NSString stringWithFormat:@"error %d with zipfile in unzGoToNextFile", err];
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return nil;
    }
    
    return [NSDictionary dictionaryWithDictionary:contentsOfArchive];
}

- (NSData *)contentsAtPath:(NSString *)path error:(NSError **)error
{
    int ret = unzLocateFile(zip, [path UTF8String], NULL);
    if (ret == UNZ_END_OF_LIST_OF_FILE)
    {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"file not found"};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorFileNotFound userInfo:userInfo];
        }
        return nil;
    }
    
    unz_file_info64 file_info = {0};
    void* buf = NULL;
    uInt size_buf = WRITEBUFFERSIZE;
    int err = UNZ_OK;
    int errclose = UNZ_OK;
    
    err = unzGetCurrentFileInfo64(zip, &file_info, NULL, 0, NULL, 0, NULL, 0);
    if (err != UNZ_OK)
    {
        NSString *desc = [NSString stringWithFormat:@"error %d with zipfile in unzGetCurrentFileInfo", err];
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return nil;
    }
    
    NSMutableData *data = [NSMutableData dataWithCapacity:file_info.uncompressed_size];
    
    buf = (void*)malloc(size_buf);
    if (buf == NULL)
    {
        NSString *desc = @"Error allocating memory";
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return nil;
    }
    
    err = unzOpenCurrentFilePassword(zip, [self.password UTF8String]);
    if (err != UNZ_OK)
    {
        NSString *desc = [NSString stringWithFormat:@"error %d with zipfile in unzOpenCurrentFilePassword", err];
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return nil;
    }
    
    /* Read from the zip, unzip to buffer, and write to data */
    int byteCopied = 0;
    do
    {
        byteCopied = unzReadCurrentFile(zip, buf, size_buf);
        if (byteCopied < 0)
        {
            NSLog(@"LOZIPFileWrapper: error %d with zipfile in unzReadCurrentFile", err);
            break;
        }
        if (byteCopied == 0)
            break;
        
        [data appendBytes:buf length:byteCopied];
    }
    while (byteCopied > 0);

    

    
    errclose = unzCloseCurrentFile(zip);
    if (errclose != UNZ_OK)
        NSLog(@"LOZIPFileWrapper: error %d with zipfile in unzCloseCurrentFile", errclose);
    
    free(buf);
    
    return [NSData dataWithData:data];
}

- (BOOL)internalWriteContentToURL:(NSURL *)URL
                          options:(NSDataWritingOptions)writeOptionsMask
                            error:(NSError **)error
{
    int err = unzGoToFirstFile(zip);
    if (err != UNZ_OK)
    {
        NSString *desc = [NSString stringWithFormat:@"error %d with zipfile in unzGoToFirstFile", err];
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return NO;
    }
    
    if ([self.delegate respondsToSelector:@selector(zipFileWrapper:willUnzipArchiveAtURL:)])
    {
        [self.delegate zipFileWrapper:self willUnzipArchiveAtURL:URL];
    }
    
    do
    {
        BOOL rtn = [self internalWriteCurrentFileToURL:URL options:writeOptionsMask error:error];
        if (!rtn)
            return NO;
        err = unzGoToNextFile(zip);
    }
    while (err == UNZ_OK);
    
    if ([self.delegate respondsToSelector:@selector(zipFileWrapper:didUnzipArchiveAtURL:)])
    {
        [self.delegate zipFileWrapper:self didUnzipArchiveAtURL:URL];
    }
    
    if (err != UNZ_END_OF_LIST_OF_FILE)
    {
        NSString *desc = [NSString stringWithFormat:@"error %d with zipfile in unzGoToNextFile", err];
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return NO;
    }
    
    return YES;
}



- (BOOL)internalWriteCurrentFileToURL:(NSURL *)URL
                              options:(NSDataWritingOptions)writeOptionsMask
                                error:(NSError **)error
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    unz_file_info64 file_info = {0};
    FILE* fout = NULL;
    void* buf = NULL;
    uInt size_buf = WRITEBUFFERSIZE;
    int err = UNZ_OK;
    int errclose = UNZ_OK;
    char filename_inzip[256] = {0};
    uLong ratio = 0;
    BOOL encrypted = NO;
    BOOL skip = NO;
    
    
    err = unzGetCurrentFileInfo64(zip, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
    if (err != UNZ_OK)
    {
        NSString *desc = [NSString stringWithFormat:@"error %d with zipfile in unzGetCurrentFileInfo", err];
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return NO;
    }
    
    if (file_info.uncompressed_size > 0)
        ratio = (uLong)((file_info.compressed_size*100) / file_info.uncompressed_size);
    
    /* Display a '*' if the file is encrypted */
    if ((file_info.flag & 1) != 0)
        encrypted = YES;
    
    
    NSString *filenameInZip = [[NSString alloc] initWithBytes:filename_inzip
                                                  length:file_info.size_filename
                                                encoding:NSUTF8StringEncoding];
    // Contains a path
    if ([filenameInZip rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location != NSNotFound)
    {
        filenameInZip = [filenameInZip stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    }
    NSString *writeFilename = [[URL path] stringByAppendingPathComponent:filenameInZip];
    
    NSDictionary *fileAttributes = nil; // Used for the NSFileManager APIs
    NSDictionary *itemAttributes = nil; // Used in our delegates, includes compressed and uncompressed size.
    NSDate *fileDate = [[self class] dateFromTM_UNZ:&file_info.tmu_date];
    fileAttributes = @{ NSFileCreationDate : fileDate, NSFileModificationDate : fileDate };
    itemAttributes = @{ NSFileCreationDate : fileDate, NSFileModificationDate : fileDate,  NSFileSize : @(file_info.uncompressed_size), LOZIPFileWrapperCompressedSize : @(file_info.compressed_size), LOZIPFileWrapperCompresseRation : @(ratio),  LOZIPFileWrapperEncrypted : @(encrypted) };

    
    // Check if it contains directory
    BOOL isDirectory = NO;
    if (filename_inzip[file_info.size_filename-1] == '/' || filename_inzip[file_info.size_filename-1] == '\\')
    {
        isDirectory = YES;
    }
    
    buf = (void*)malloc(size_buf);
    if (buf == NULL)
    {
        NSString *desc = @"Error allocating memory";
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return NO;
    }
    
    err = unzOpenCurrentFilePassword(zip, [self.password UTF8String]);
    if (err != UNZ_OK)
    {
        NSString *desc = [NSString stringWithFormat:@"error %d with zipfile in unzOpenCurrentFilePassword", err];
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : desc};
        if (error)
        {
            *error = [NSError errorWithDomain:LOZIPFileWrapperErrorDomain code:LOZIPFileWrapperErrorInternal userInfo:userInfo];
        }
        return NO;
    }
    
    /* Determine if the file should be overwritten or not and ask the user if needed */
    if ([fileManager fileExistsAtPath:writeFilename] && !isDirectory && (writeOptionsMask & NSDataWritingWithoutOverwriting))
    {
        skip = YES;
    }
    
    if (!skip && [self.delegate respondsToSelector:@selector(zipFileWrapper:shouldUnzipFileWithName:attributes:)])
    {
        if (![self.delegate zipFileWrapper:self shouldUnzipFileWithName:filenameInZip attributes:itemAttributes])
        {
            skip = YES;
        }
    }
    
    if (!skip && [self.delegate respondsToSelector:@selector(zipFileWrapper:willUnzipFileWithName:attributes:)])
    {
        [self.delegate zipFileWrapper:self willUnzipFileWithName:filenameInZip attributes:itemAttributes];
    }
    
    if (!skip)
    {
        NSString *directoryPath = writeFilename;
        if (!isDirectory)
        {
            directoryPath = [writeFilename stringByDeletingLastPathComponent];
        }
        
        NSError *createDirectoryError = nil;
        BOOL rtn = [fileManager createDirectoryAtPath:directoryPath
                          withIntermediateDirectories:YES
                                           attributes:fileAttributes
                                                error:&createDirectoryError];
        if (!rtn)
        {
            NSLog(@"LOZIPFileWrapper: error createDirectoryAtPath %@", createDirectoryError);
        }
    }
    
    /* Create the file on disk so we can unzip to it */
    if (!skip && (err == UNZ_OK))
    {
        fout = fopen([writeFilename UTF8String], "wb");
        /* Some zips don't contain directory alone before file */
        /*if ((fout == NULL) && (opt_extract_without_path == 0) &&
            (filename_withoutpath != (char*)filename_inzip))
        {
            char c = *(filename_withoutpath-1);
            *(filename_withoutpath-1) = 0;
            makedir(write_filename);
            *(filename_withoutpath-1) = c;
            fout = FOPEN_FUNC(write_filename, "wb");
        }*/
        if (fout == NULL)
            NSLog(@"LOZIPFileWrapper: error %d in opening %@", errno, writeFilename);
    }
    
    /* Read from the zip, unzip to buffer, and write to disk */
    if (fout != NULL)
    {
        do
        {
            err = unzReadCurrentFile(zip, buf, size_buf);
            if (err < 0)
            {
                NSLog(@"LOZIPFileWrapper: error %d with zipfile in unzReadCurrentFile", err);
                break;
            }
            if (err == 0)
                break;
            if (fwrite(buf, err, 1, fout) != 1)
            {
                NSLog(@"LOZIPFileWrapper: error %d in writing extracted file", errno);
                err = UNZ_ERRNO;
                break;
            }
        }
        while (err > 0);
        
        if (fout)
            fclose(fout);
        
        /* Set the time of the file that has been unzipped */
        if (err == 0)
        {
            NSError *attributesError = nil;
            if (![fileManager setAttributes:fileAttributes ofItemAtPath:writeFilename error:&attributesError])
            {
                NSLog(@"LOZIPFileWrapper: Set attributes failed: %@.", attributesError);
            }
        }
    }
    
    errclose = unzCloseCurrentFile(zip);
    if (errclose != UNZ_OK)
        NSLog(@"LOZIPFileWrapper: error %d with zipfile in unzCloseCurrentFile", errclose);
    
    free(buf);
    
    if ((skip == 0) && [self.delegate respondsToSelector:@selector(zipFileWrapper:didUnzipFileWithName:attributes:)])
    {
        [self.delegate zipFileWrapper:self didUnzipFileWithName:filenameInZip attributes:itemAttributes];
    }
    
    return YES;
}


#pragma mark - Writing ZIP Archives





#pragma mark - Helper

+ (NSDate *)dateFromTM_UNZ:(tm_unz *)tmu_date
{
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *c = [[NSDateComponents alloc] init];
    
    [c setYear:tmu_date->tm_year];
    [c setMonth:tmu_date->tm_mon + 1];
    [c setDay:tmu_date->tm_mday];
    [c setHour:tmu_date->tm_hour];
    [c setMinute:tmu_date->tm_min];
    [c setSecond:tmu_date->tm_sec];
    
    return [gregorian dateFromComponents:c];
}

@end
