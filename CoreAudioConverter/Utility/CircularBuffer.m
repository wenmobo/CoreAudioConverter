/*
 *  $Id$
 *
 *  Copyright (C) 2005 - 2007 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "CircularBuffer.h"

// ALog always displays output regardless of the DEBUG setting
#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

@interface CircularBuffer (/* Private */)

@property (nonatomic, readwrite) uint8_t *buffer;
@property (nonatomic, readwrite) NSUInteger bufsize;

@property (nonatomic, readwrite) uint8_t *readPtr;
@property (nonatomic, readwrite) uint8_t *writePtr;

- (BOOL)normalizeBuffer;
- (NSUInteger)contiguousBytesAvailable;
- (NSUInteger)contiguousFreeSpaceAvailable;

@end

@implementation CircularBuffer
#pragma mark - Object creation

- (nullable instancetype)init {
	return [self initWithSize:10 * 1024];
}
- (nullable instancetype)initWithSize:(NSUInteger)size {
    
    if (size <= 0) {
        return nil;
    }
	
    self = [super init];
    
	if (self) {
        
		_bufsize	= size;
		_buffer		= (uint8_t *)calloc(_bufsize, sizeof(uint8_t));
		
        if (_buffer == NULL) {
            return nil;
        }
		
		_readPtr	= _buffer;
		_writePtr	= _buffer;
	}
    
	return self;
}

#pragma mark - Methode Implementation

- (void)reset { _readPtr = _writePtr = _buffer; }

- (NSUInteger)size { return _bufsize; }

- (NSUInteger)bytesAvailable {
	return (_writePtr >= _readPtr ? (NSUInteger)(_writePtr - _readPtr) : [self size] - (NSUInteger)(_readPtr - _writePtr));
}

- (NSUInteger)freeSpaceAvailable { return _bufsize - [self bytesAvailable]; }


- (NSUInteger)getData:(void *)buffer byteCount:(NSUInteger)byteCount {
	//NSParameterAssert(NULL != buffer);
    if (buffer == NULL) {
        ALog(@"Failed to get data because the buffer is missing.");
        return 0;
    }

	// Do nothing!
	if(0 == byteCount) {
		return 0;
	}
	
	// Attempt to return some data, if possible
	if(byteCount > [self bytesAvailable]) {
		byteCount = [self bytesAvailable];
	}

	if([self contiguousBytesAvailable] >= byteCount) {
		memcpy(buffer, _readPtr, byteCount);
		_readPtr += byteCount;
	}
	else {
		NSUInteger	blockSize		= [self contiguousBytesAvailable];
		NSUInteger	wrapSize		= byteCount - blockSize;
		
		memcpy(buffer, _readPtr, blockSize);
		_readPtr = _buffer;
		
		memcpy(buffer + blockSize, _readPtr, wrapSize);
		_readPtr += wrapSize;
	}

	return byteCount;
}

- (void)readBytes:(NSUInteger)byteCount {
	uint8_t			*limit		= _buffer + _bufsize;
	
	_readPtr += byteCount; 

	if(_readPtr > limit) {
		_readPtr = _buffer;
	}
}

- (void *)exposeBufferForWriting {
    
    BOOL erfolg = [self normalizeBuffer];
    if (!erfolg) {
        return nil;
    }
    return _writePtr;

}

- (void)wroteBytes:(NSUInteger)byteCount {
	uint8_t			*limit		= _buffer + _bufsize;
	
	_writePtr += byteCount;
	
	if(_writePtr > limit) {
		_writePtr = _buffer;
	}
}

#pragma mark - Private Methode Implementation

- (void)dealloc {
    
    free(_buffer);
}

- (BOOL)normalizeBuffer {
    
    if(_writePtr == _readPtr) {
        _writePtr = _readPtr = _buffer;
    }
    else if(_writePtr > _readPtr) {
        
        NSUInteger	count		= _writePtr - _readPtr;
        NSUInteger	delta		= _readPtr - _buffer;
        
        memmove(_buffer, _readPtr, count);
        
        _readPtr	= _buffer;
        _writePtr	-= delta;
    }
    else {
        
        NSUInteger		chunkASize	= [self contiguousBytesAvailable];
        NSUInteger		chunkBSize	= [self bytesAvailable] - [self contiguousBytesAvailable];
        uint8_t			*chunkA		= NULL;
        uint8_t			*chunkB		= NULL;
        
        chunkA = (uint8_t *)calloc(chunkASize, sizeof(uint8_t));
        //NSAssert1(NULL != chunkA, @"Unable to allocate memory: %s", strerror(errno));
        if (chunkA == NULL) {
            ALog(@"Unable to allocate memory: %s", strerror(errno));
            return NO;
        }
        memcpy(chunkA, _readPtr, chunkASize);
        
        if(0 < chunkBSize) {
            chunkB = (uint8_t *)calloc(chunkBSize, sizeof(uint8_t));
            //NSAssert1(NULL != chunkA, @"Unable to allocate memory: %s", strerror(errno));
            if (chunkB == NULL) {
                ALog(@"Unable to allocate memory: %s", strerror(errno));
                free(chunkA);
                return NO;
            }
            memcpy(chunkB, _buffer, chunkBSize);
        }
        
        memcpy(_buffer, chunkA, chunkASize);
        memcpy(_buffer + chunkASize, chunkB, chunkBSize);
        
        _readPtr	= _buffer;
        _writePtr	= _buffer + chunkASize + chunkBSize;
        
        // else analyser shows memory leak 
        free(chunkA);
        free(chunkB);
    }
    return YES;
}

- (NSUInteger)contiguousBytesAvailable {
    
    uint8_t	*limit = _buffer + _bufsize;
    
    return (_writePtr >= _readPtr ? _writePtr - _readPtr : limit - _readPtr);
}

- (NSUInteger)contiguousFreeSpaceAvailable {
    
    uint8_t			*limit		= _buffer + _bufsize;
    
    return (_writePtr >= _readPtr ? limit - _writePtr : _readPtr - _writePtr);
}

#pragma mark -
@end
