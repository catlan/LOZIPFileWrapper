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
    
    NSString *path = [self _cachesPath:nil];
    [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEmpty {
    NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Empty" withExtension:@""];
    NSError *error = nil;
    LOZIPFileWrapper *fileWrapper = [[LOZIPFileWrapper alloc] initWithURL:URL password:nil error:&error];
    XCTAssert(fileWrapper == nil, @"empty test");
    XCTAssert(error.code == LOZIPFileWrapperErrorDocumentStart, @"empty test");
    
    NSError *error2 = nil;
    LOZIPFileWrapper *fileWrapper2 = [[LOZIPFileWrapper alloc] initWithZIPData:[NSData data] password:nil error:&error2];
    XCTAssert(fileWrapper2 == nil, @"empty test");
    XCTAssert(error2.code == LOZIPFileWrapperErrorDocumentStart, @"empty test");
}

- (void)testNotAZipFile {
    NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"HelloWorld" withExtension:@"txt"];
    NSError *error = nil;
    LOZIPFileWrapper *fileWrapper = [[LOZIPFileWrapper alloc] initWithURL:URL password:nil error:&error];
    XCTAssert(fileWrapper == nil, @"txt test");
    XCTAssert(error.code == LOZIPFileWrapperErrorDocumentStart, @"txt test");
    
    
    NSError *error2 = nil;
    LOZIPFileWrapper *fileWrapper2 = [[LOZIPFileWrapper alloc] initWithZIPData:[NSData dataWithContentsOfURL:URL] password:nil error:&error2];
    XCTAssert(fileWrapper2 == nil, @"txt test");
    XCTAssert(error2.code == LOZIPFileWrapperErrorDocumentStart, @"txt test");
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
    XCTAssert(fileNotFoundData == nil, @"Pass");
    XCTAssert(fileNotFoundError.code == LOZIPFileWrapperErrorFileNotFound, @"Pass");
    
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
    
    LOZIPFileWrapper *fileWrapper1 = [[LOZIPFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipPath] password:@"passw0rd" error:NULL];
    NSError *error1 = nil;
    BOOL rtn1 = [fileWrapper1 writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:&error1];
    XCTAssert(rtn1 == YES , @"Pass");
    
    
    
    NSError *error2 = nil;
    LOZIPFileWrapper *fileWrapper2 = [[LOZIPFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipPath] password:@"Hello" error:&error2];
    XCTAssert(fileWrapper2 == nil , @"Password");
    XCTAssert(error2.code == LOZIPFileWrapperErrorWrongPassword, @"Password");
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
