/**
 * This file is part of Todo.txt Touch, an iOS app for managing your todo.txt file.
 *
 * @author Todo.txt contributors <todotxt@yahoogroups.com>
 * @copyright 2011 Todo.txt contributors (http://todotxt.com)
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

#import "DropboxRemoteClientTest.h"
#import "RemoteClient.h"
#import "DropboxRemoteClient.h"
#import <OCMock/OCMock.h>

@interface DropboxRemoteClientTest () <RemoteClientDelegate>
@end

@implementation DropboxRemoteClientTest

static enum { none, loaded, loadError, uploaded, uploadConflict, uploadError } status = none;

#pragma mark -
#pragma mark RemoteClientDelegate methods

- (void)remoteClient:(id<RemoteClient>)client loadedTodoFile:(NSString*)todoPath  loadedDoneFile:(NSString*)donePath{
	status = loaded;
}

- (void) remoteClient:(id<RemoteClient>)client loadFileFailedWithError:(NSError *)error {
	status = loadError;
}

- (void)remoteClient:(id<RemoteClient>)client uploadedFile:(NSString*)destPath {
	status = uploaded;
}

- (void) remoteClient:(id<RemoteClient>)client uploadFileFailedWithError:(NSError *)error {
	status = uploadError;
}

- (void)remoteClient:(id<RemoteClient>)client uploadFileFailedWithConflict:(NSString*)destPath {
	status = uploadConflict;
}

- (void)remoteClient:(id<RemoteClient>)client loginControllerDidLogin:(BOOL)success {
	/* not currently used in tests */
}

- (void) setUp {
	waiter = [[AsyncWaiter alloc] init];
}

- (void) tearDown {
	[waiter release];
}

- (void) testPullBothFilesMissing {
//	DropboxRemoteClient *client = [[DropboxRemoteClient alloc] init];
//	client.delegate = self;
//	[client pullTodo];
//	
//	STAssertTrue([waiter waitForCompletion:15.0], @"Failed to complete in time");
//	STAssertEquals(status, loaded, @"status should be LOADED");
}

@end
