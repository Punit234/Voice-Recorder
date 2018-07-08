/*
     File: PutController.m
 Abstract: Manages the Put tab.
  Version: 1.4
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2013 Apple Inc. All Rights Reserved.
 
 */

#import "PutController.h"
#include <CFNetwork/CFNetwork.h>



enum {
    kSendBufferSize = 32768
};

@interface PutController () <NSStreamDelegate>

@property (nonatomic, strong, readwrite) NSOutputStream *  networkStream;
@property (nonatomic, strong, readwrite) NSInputStream *   fileStream;
@property (nonatomic, assign, readonly ) uint8_t *         buffer;
@property (nonatomic, assign, readwrite) size_t            bufferOffset;
@property (nonatomic, assign, readwrite) size_t            bufferLimit;

@end

@implementation PutController
{
    uint8_t _buffer[kSendBufferSize];
}

// Because buffer is declared as an array, you have to use a custom getter.
// A synthesised getter doesn't compile.

- (uint8_t *)buffer
{
    return self->_buffer;
}


- (void)startSend:(NSData *)dataToUpload withURL:(NSURL *)toURL withUsername:(NSString *)username andPassword:(NSString *)password
{
    printf(__FUNCTION__);
    
    self.fileStream = [NSInputStream inputStreamWithData:dataToUpload];
    
    [self.fileStream open];
    
    // Open a CFFTPStream for the URL.
    
    self.networkStream = CFBridgingRelease(
                                           CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef) toURL)
                                           );
    
    [self.networkStream setProperty:username forKey:(id)kCFStreamPropertyFTPUserName];
    [self.networkStream setProperty:password forKey:(id)kCFStreamPropertyFTPPassword];
    
    self.networkStream.delegate = self;
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.networkStream open];
    
}

- (void)stopSendWithStatus:(NSString *)statusString
{
    printf(__FUNCTION__);
    
    if (self.networkStream != nil) {
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.networkStream.delegate = nil;
        [self.networkStream close];
        self.networkStream = nil;
    }
    if (self.fileStream != nil) {
        [self.fileStream close];
        self.fileStream = nil;
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
// An NSStream delegate callback that's called when events happen on our
// network stream.
{
    printf(__FUNCTION__);
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            printf("Opened connection");
            if ([self._delegatePutVC respondsToSelector:@selector(didStart)] == YES)
            {
                [self._delegatePutVC didStart];
            }
        } break;
        case NSStreamEventHasBytesAvailable: {
            printf("should never happen for the output stream");
        } break;
        case NSStreamEventHasSpaceAvailable: {
            printf("Sending");
            if ([self._delegatePutVC respondsToSelector:@selector(didUploading)] == YES)
            {
                [self._delegatePutVC didUploading];
            }
            // If we don't have any data buffered, go read the next chunk of data.
            
            if (self.bufferOffset == self.bufferLimit) {
                NSInteger   bytesRead;
                
                bytesRead = [self.fileStream read:self.buffer maxLength:kSendBufferSize];
                
                if (bytesRead == -1) {
                    if ([self._delegatePutVC respondsToSelector:@selector(didFail:)] == YES)
                    {
                        [self._delegatePutVC didFail:@"File read error"];
                    }

                    [self stopSendWithStatus:@"File read error"];
                    
                } else if (bytesRead == 0) {
                    if ([self._delegatePutVC respondsToSelector:@selector(didSuccessfullyUploaded)] == YES)
                    {
                        [self._delegatePutVC didSuccessfullyUploaded];
                    }
                    [self stopSendWithStatus:nil];
                } else {
                    self.bufferOffset = 0;
                    self.bufferLimit  = bytesRead;
                }
            }
            
            // If we're not out of data completely, send the next chunk.
            
            if (self.bufferOffset != self.bufferLimit) {
                NSInteger   bytesWritten;
                bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                assert(bytesWritten != 0);
                if (bytesWritten == -1) {
                    if ([self._delegatePutVC respondsToSelector:@selector(didFail:)] == YES)
                    {
                        [self._delegatePutVC didFail:@"Network write error"];
                    }
                    [self stopSendWithStatus:@"Network write error"];
                } else {
                    self.bufferOffset += bytesWritten;
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            if ([self._delegatePutVC respondsToSelector:@selector(didFail:)] == YES)
            {
                [self._delegatePutVC didFail:@"Stream open error"];
            }
            [self stopSendWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}

@end