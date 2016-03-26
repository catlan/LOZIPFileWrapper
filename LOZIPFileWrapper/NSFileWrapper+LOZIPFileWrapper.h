//
//  NSFileWrapper+LOZIPFileWrapper.h
//  LOZIPFileWrapper
//
//  Created by Christopher Atlan on 26/03/16.
//  Copyright © 2016 Christopher Atlan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSFileWrapper (LOZIPFileWrapper)

- (BOOL)writeZIPArchiveToURL:(NSURL *)url password:(NSString *)password options:(NSFileWrapperWritingOptions)options error:(NSError **)outError;

@end
