//
//  LOZIPFileWrapperTests.m
//  LOZIPFileWrapperTests
//
//  Created by Christopher Atlan on 13/08/15.
//  Copyright (c) 2015 Christopher Atlan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>
#import <CommonCrypto/CommonDigest.h>

#import "LOZIPFileWrapper.h"

@interface LOZIPFileWrapperTests : XCTestCase

@end

@implementation LOZIPFileWrapperTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    
    NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"HelloWorld" withExtension:@"zip"];
    
    LOZIPFileWrapper *fileWrapper = [[LOZIPFileWrapper alloc] initWithURL:URL password:nil error:NULL];
    
    NSArray *contentWithFolders = [fileWrapper contentOfZIPFileIncludingFolders:YES error:NULL];
    XCTAssert([contentWithFolders count] == 13 , @"Pass");
    
    
    NSArray *contentWithoutFolders = [fileWrapper contentOfZIPFileIncludingFolders:NO error:NULL];
    XCTAssert([contentWithoutFolders count] == 8 , @"Pass");
    
    NSDictionary *contentAttributes = [fileWrapper contentAttributesOfZIPFileIncludingFolders:YES error:NULL];
    
    NSDictionary *test1 = contentAttributes[@"[Content_Types].xml"];
    XCTAssert([test1[LOZIPFileWrapperCompressedSize] isEqual:@(290)], @"Pass");
    XCTAssert([test1[NSFileSize] isEqual:@(783)], @"Pass");
    
    //XCTAssert([test1[NSFileCreationDate] isEqual:[NSDate dateWithTimeIntervalSinceReferenceDate:461231580]], @"Pass");
    //XCTAssert([test1[NSFileCreationDate] isEqual:[NSDate dateWithString:@"2015-08-14 07:53:00 +0000"]], @"Pass");
    
    
    NSDictionary *test2 = contentAttributes[@"_rels"];
    XCTAssert([test2[NSFileType] isEqual:NSFileTypeDirectory], @"Pass");
    
    NSError *fileNotFoundError = nil;
    NSData *fileNotFoundData = [fileWrapper contentsAtPath:@"lala" error:&fileNotFoundError];
    XCTAssert(fileNotFoundData == nil && fileNotFoundError.code == LOZIPFileWrapperErrorFileNotFound, @"Pass");
    
    NSData *contentTypesData = [fileWrapper contentsAtPath:@"[Content_Types].xml" error:NULL];
    NSString *contentTypesString = [[NSString alloc] initWithData:contentTypesData encoding:NSUTF8StringEncoding];
    XCTAssert([contentTypesString hasPrefix:@"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>"], @"Pass");
    
}

- (void)testInMemory {
    NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"HelloWorld" withExtension:@"zip"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    LOZIPFileWrapper *fileWrapper = [[LOZIPFileWrapper alloc] initWithZIPData:data password:nil error:NULL];
    
    NSError *contentAttributesError = nil;
    NSDictionary *contentAttributes = [fileWrapper contentAttributesOfZIPFileIncludingFolders:YES error:&contentAttributesError];
    XCTAssert([contentAttributes count] == 13 , @"Pass");
    
    NSArray *contentWithoutFolders = [fileWrapper contentOfZIPFileIncludingFolders:NO error:NULL];
    XCTAssert([contentWithoutFolders count] == 8 , @"Pass");
}

- (void)testExtract {
    NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"HelloWorld" withExtension:@"zip"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    NSString *outputPath = [self _cachesPath:@"HelloWorld"];
    
    LOZIPFileWrapper *fileWrapper = [[LOZIPFileWrapper alloc] initWithZIPData:data password:nil error:NULL];
    BOOL rtn = [fileWrapper writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:NULL];
    XCTAssert(rtn == YES , @"Pass");
    
    NSArray *contentsOfDirectory =[[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:outputPath] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
    XCTAssert([contentsOfDirectory count] == 4 , @"Pass");
}


- (void)testPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"PasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];
    
    LOZIPFileWrapper *fileWrapper = [[LOZIPFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipPath] password:@"passw0rd" error:NULL];
    [fileWrapper writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:NULL];
    
    BOOL rtn = [fileWrapper writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:NULL];
    XCTAssert(rtn == YES , @"Pass");
    
    NSArray *contentsOfDirectory =[[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:outputPath] includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:NULL];
    XCTAssert([contentsOfDirectory count] == 4 , @"Pass");
}

#pragma mark - Private
- (NSString *)_cachesPath:(NSString *)directory {
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]
                      stringByAppendingPathComponent:@"com.creativeinaustria.LOZIPFileWrapper.tests"];
    if (directory) {
        path = [path stringByAppendingPathComponent:directory];
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    return path;
}

- (NSString *)_calculateMD5Digest:(NSData *)data {
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5(data.bytes, (unsigned int)data.length, digest);
    NSMutableString *string = [NSMutableString string];
    
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [string appendFormat:@"%02x", (int)(digest[i])];
    }
    
    return [string copy];
}

@end
