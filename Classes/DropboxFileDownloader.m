/**
 * This file is part of Todo.txt Touch, an iOS app for managing your todo.txt file.
 *
 * @author Todo.txt contributors <todotxt@yahoogroups.com>
 * @copyright 2011-2012 Todo.txt contributors (http://todotxt.com)
 *  
 * Dual-licensed under the GNU General Public License and the MIT License
 *
 * @license GNU General Public License http://www.gnu.org/licenses/gpl.html
 *
 * Todo.txt Touch is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any
 * later version.
 *
 * Todo.txt Touch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with Todo.txt Touch.  If not, see
 * <http://www.gnu.org/licenses/>.
 *
 *
 * @license The MIT License http://www.opensource.org/licenses/mit-license.php
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "DropboxFileDownloader.h"

@interface DropboxFileDownloader () <DBRestClientDelegate>
@end

@implementation DropboxFileDownloader 

@synthesize files, status, error;

- (id) initWithTarget:(id)aTarget onComplete:(SEL)selector {
	self = [super init];
	if (self) {
		target = aTarget;
		onComplete = selector;
		status = dbInitialized;
		curFile = -1;
	}
	return self;
}

- (DBRestClient*)restClient {
    if (restClient == nil) {
    	restClient = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    	restClient.delegate = self;
    }
    return restClient;
}

- (void) loadNextFile {
	if (++curFile < files.count) {
		DropboxFile *file = [files objectAtIndex:curFile];
		if (file.status == dbFound) {
			[self.restClient loadFile:file.remoteFile
								atRev:file.loadedMetadata.rev 
							 intoPath:file.localFile];		
		} else {
			[self loadNextFile];
		}
	} else {
		// we're done!
		status = dbSuccess;
		[target performSelector:onComplete];
	}
}

- (void) loadNextMetadata {
	if (++curFile < files.count) {
		DropboxFile *file = [files objectAtIndex:curFile];
		file.status = dbStarted;
		[self.restClient loadMetadata:file.remoteFile];
	} else {
		// we got all of the metadata, now get the files
		curFile = -1;
		[self loadNextFile];
	}
}

- (void) pullFiles:(NSArray*)dropboxFiles {
	[files release];
	files = [dropboxFiles retain];
	curFile = -1;
	status = dbStarted;
	
	// first check metadata of each file, starting with the first
	[self loadNextMetadata];
}

#pragma mark -
#pragma mark DBRestClientDelegate methods

- (void)restClient:(DBRestClient*)client loadedMetadata:(DBMetadata*)metadata {
	DropboxFile *file = [files objectAtIndex:curFile];

	// save off the returned metadata
	file.loadedMetadata = metadata;	
	
	if ([metadata.rev isEqualToString:file.originalRev]) {
		// don't bother downloading if the rev is the same
		file.status = dbNotChanged;
	} else {
		file.status = dbFound;
	}

	// get the next metadata
	[self loadNextMetadata];
}

- (void)restClient:(DBRestClient*)client loadMetadataFailedWithError:(NSError*)error {
	DropboxFile *file = [files objectAtIndex:curFile];

	// there was no metadata for the todo file, meaning it does not exist
	// so there is nothing to load
	file.status = dbNotFound;
	
	// get the next metadata
	[self loadNextMetadata];
}

- (void)restClient:(DBRestClient*)client loadedFile:(NSString*)destPath {
	DropboxFile *file = [files objectAtIndex:curFile];

	file.status = dbSuccess;

	[self loadNextFile];
}

- (void)restClient:(DBRestClient*)client loadFileFailedWithError:(NSError*)theError {
	DropboxFile *file = [files objectAtIndex:curFile];
	
	file.status = dbError;
	file.error = theError;
	
	status = dbError;
	[error release];
	error = [theError retain];

	// don't bother downloading any more files after the first error
	[target performSelector:onComplete];
}

- (void) dealloc {
	[error release];
	[files release];
	[restClient release];
	[super dealloc];
}

@end
