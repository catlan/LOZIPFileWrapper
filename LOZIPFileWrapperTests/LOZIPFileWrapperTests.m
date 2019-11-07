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
#import "NSFileWrapper+LOZIPFileWrapper.h"

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
    
    NSDate *dateControlValue = [NSDate dateWithTimeIntervalSince1970:1439545980];
    NSDate *dateValue = test1[NSFileCreationDate];
    XCTAssertEqualWithAccuracy([dateControlValue timeIntervalSince1970], [dateValue timeIntervalSince1970], 0.001);
    
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

- (void)testOverwrite {
    NSString *outputPath = [self _cachesPath:@"Overwrite"];
    
    NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Overwrite1" withExtension:@"zip"];
    NSData *data = [NSData dataWithContentsOfURL:URL];
    
    LOZIPFileWrapper *fileWrapper = [[LOZIPFileWrapper alloc] initWithZIPData:data password:nil error:NULL];
    BOOL rtn = [fileWrapper writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:NULL];
    XCTAssert(rtn == YES , @"Pass");
    
    NSString *content = [NSString stringWithContentsOfFile:[outputPath stringByAppendingPathComponent:@"HelloWorld.txt"] encoding:NSUTF8StringEncoding error:NULL];
    XCTAssert([content isEqualToString:@"Hello World\n"] , @"Pass");
    
    
    
    URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Overwrite2" withExtension:@"zip"];
    data = [NSData dataWithContentsOfURL:URL];
    
    fileWrapper = [[LOZIPFileWrapper alloc] initWithZIPData:data password:nil error:NULL];
    rtn = [fileWrapper writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:NSDataWritingWithoutOverwriting error:NULL];
    XCTAssert(rtn == YES , @"Pass");
    
    content = [NSString stringWithContentsOfFile:[outputPath stringByAppendingPathComponent:@"HelloWorld.txt"] encoding:NSUTF8StringEncoding error:NULL];
    XCTAssert([content isEqualToString:@"Hello World\n"] , @"Pass");
    
    
    
    rtn = [fileWrapper writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:NULL];
    XCTAssert(rtn == YES , @"Pass");
    
    content = [NSString stringWithContentsOfFile:[outputPath stringByAppendingPathComponent:@"HelloWorld.txt"] encoding:NSUTF8StringEncoding error:NULL];
    XCTAssert([content isEqualToString:@"Overwritten World\n"] , @"Pass");
}


- (void)testPassword {
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"PasswordArchive" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"Password"];
    
    NSError *openError = nil;
    LOZIPFileWrapper *fileWrapper1 = [[LOZIPFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipPath] password:@"passw0rd" error:&openError];
    NSError *error1 = nil;
    BOOL rtn1 = [fileWrapper1 writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:&error1];
    XCTAssert(rtn1 == YES , @"Pass");
    
    
    
    NSError *error2 = nil;
    LOZIPFileWrapper *fileWrapper2 = [[LOZIPFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipPath] password:@"Hello" error:&error2];
    XCTAssert(fileWrapper2 == nil , @"Password");
    XCTAssert(error2.code == LOZIPFileWrapperErrorWrongPassword, @"Password");
}


- (void)testResourceForkIgnore__MACOSX
{
    // macosx_metadata_test.zip
    NSString *zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"macosx_metadata_test" ofType:@"zip"];
    NSString *outputPath = [self _cachesPath:@"macosx_metadata_test"];
    
    NSError *openError = nil;
    LOZIPFileWrapper *fileWrapper1 = [[LOZIPFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipPath] password:nil error:&openError];
    
    NSDictionary *contentAttributes1 = [fileWrapper1 contentAttributesOfZIPFileIncludingFolders:NO error:NULL];
    XCTAssert([contentAttributes1 count] == 4, @"Pass");
    
    NSArray *contentOfZIPFile1 = [fileWrapper1 contentOfZIPFileIncludingFolders:NO error:NULL];
    XCTAssert([contentOfZIPFile1 count] == 4, @"Pass");
    XCTAssert([contentOfZIPFile1 containsObject:@"macosx_metadata_test/"], @"Pass");
    XCTAssert([contentOfZIPFile1 containsObject:@"macosx_metadata_test/readme.txt"], @"Pass");
    XCTAssert([contentOfZIPFile1 containsObject:@"macosx_metadata_test/catty_with_resource.jpg"], @"Pass");
    XCTAssert([contentOfZIPFile1 containsObject:@"macosx_metadata_test/catty_with_no_resource.jpg"], @"Pass");
    
    
    NSError *error1 = nil;
    BOOL rtn1 = [fileWrapper1 writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:&error1];
    XCTAssert(rtn1 == YES , @"Pass");
    
    NSArray *contentsOfDirectory1 = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:outputPath error:NULL];
    XCTAssert([contentsOfDirectory1 count] == 1, @"Pass");
    
    NSArray *contentsOfDirectory2 = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[outputPath stringByAppendingPathComponent:@"macosx_metadata_test"] error:NULL];
    XCTAssert([contentsOfDirectory2 count] == 3, @"Pass");
    
    
    // TestfileRes.zip
    zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"TestfileRes" ofType:@"zip"];
    outputPath = [self _cachesPath:@"TestfileRes"];
    
    LOZIPFileWrapper *fileWrapper2 = [[LOZIPFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipPath] password:nil error:&openError];
    
    NSDictionary *contentAttributes2 = [fileWrapper2 contentAttributesOfZIPFileIncludingFolders:NO error:NULL];
    XCTAssert([contentAttributes2 count] == 2, @"Pass");
    
    NSArray *contentOfZIPFile2 = [fileWrapper2 contentOfZIPFileIncludingFolders:NO error:NULL];
    XCTAssert([contentOfZIPFile2 count] == 2, @"Pass");
    XCTAssert([contentOfZIPFile2 containsObject:@"TestFileData.rsrc"], @"Pass");
    XCTAssert([contentOfZIPFile2 containsObject:@"TestfileRes.rsrc"], @"Pass");
    // TestfileRes.rsrc is empty, only the resource fork includes data.
    
    
    // Test.bundle.zip
    zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Test.bundle" ofType:@"zip"];
    outputPath = [self _cachesPath:@"Test-bundle"];
    
    LOZIPFileWrapper *fileWrapper3 = [[LOZIPFileWrapper alloc] initWithURL:[NSURL fileURLWithPath:zipPath] password:nil error:&openError];
    
    NSDictionary *contentAttributes3 = [fileWrapper3 contentAttributesOfZIPFileIncludingFolders:NO error:NULL];
    XCTAssert([contentAttributes3 count] == 3, @"Pass");
    
    NSArray *contentOfZIPFile3 = [fileWrapper3 contentOfZIPFileIncludingFolders:NO error:NULL];
    XCTAssert([contentOfZIPFile3 count] == 3, @"Pass");
    XCTAssert([contentOfZIPFile3 containsObject:@"Test.bundle/"], @"Pass");
    XCTAssert([contentOfZIPFile3 containsObject:@"Test.bundle/Hello World.txt"], @"Pass");
    XCTAssert([contentOfZIPFile3 containsObject:@"Test.bundle/Icon\r"], @"Pass");
    
    BOOL rtn3 = [fileWrapper3 writeContentOfZIPFileToURL:[NSURL fileURLWithPath:outputPath] options:0 error:NULL];
    XCTAssert(rtn3, @"Pass");
}

- (void)testCreateZIP {
    
    NSURL *URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"HelloWorld" withExtension:@"txt"];
    NSFileWrapper *fileWrapper = [[NSFileWrapper alloc] initWithURL:URL options:0 error:NULL];
    
    NSString *outputPath = [self _cachesPath:@"NewHelloWorld"];
    NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
    outputURL = [outputURL URLByAppendingPathComponent:@"HelloWorld.zip"];
    
    NSError *error = nil;
    BOOL success = [fileWrapper writeZIPArchiveToURL:outputURL password:nil options:0 error:&error];
    
    XCTAssert(success == YES, @"writeZIPArchiveToURL");
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CC_MD5(data.bytes, (unsigned int)data.length, digest);
#pragma clang diagnostic pop
    NSMutableString *string = [NSMutableString string];
    
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [string appendFormat:@"%02x", (int)(digest[i])];
    }
    
    return [string copy];
}

@end
