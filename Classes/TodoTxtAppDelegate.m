/**
 * This file is part of Todo.txt, an iOS app for managing your todo.txt file.
 *
 * @author Todo.txt contributors <todotxt@yahoogroups.com>
 * @copyright 2011-2013 Todo.txt contributors (http://todotxt.com)
 *
 * Dual-licensed under the GNU General Public License and the MIT License
 *
 * @license GNU General Public License http://www.gnu.org/licenses/gpl.html
 *
 * Todo.txt is free software: you can redistribute it and/or modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any
 * later version.
 *
 * Todo.txt is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with Todo.txt.  If not, see
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

#import "TodoTxtAppDelegate.h"
#import "FilterViewController.h"
#import "TaskFilterTarget.h"
#import "TaskBag.h"
#import "TaskBagFactory.h"
#import "AsyncTask.h"
#import "DropboxFile.h"
#import "Network.h"
#import "LocalFileTaskRepository.h"
#import "Util.h"
#import "Reachability.h"
#import "SJNotificationViewController.h"

static NSString * const kLoginScreenSegueIdentifier = @"LoginScreenSegue";
static NSString * const kLoginScreenSegueNotAnimatedIdentifier = @"LoginScreenSegueNotAnimated";

NSString * const kTODOSyncErrorKey = @"__kTODOSyncErrorKey";

NSString * const kTODOSyncFinishedNotificationName = @"__kTODOSyncFinishedNotificationName";

@interface TodoTxtAppDelegate ()

@property (nonatomic, weak) TasksViewController *viewController;
@property (nonatomic, weak) UIViewController *loginController;
@property (nonatomic, weak) UINavigationController *contentNavController;
@property (nonatomic, strong) RemoteClientManager *remoteClientManager;
@property (nonatomic, strong) id<TaskBag> taskBag;
@property (nonatomic, strong) NSDate *lastSync;
@property (nonatomic) BOOL wasConnected;

+ (NSError *)noInternetError;
+ (NSError *)fileConflictError;

/**
 Callback when syncing completes. Syncing assumed to be successful
 if no error is passed in.
 @param error The error, if any, that occurred. nil indicates success.
 */
- (void) syncCompleteWithError:(NSError *)error;

@end

@implementation TodoTxtAppDelegate

#pragma mark -
#pragma mark Application lifecycle

+ (BOOL) needToPush {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:@"need_to_push"];
}

+ (void) setNeedToPush:(BOOL)needToPush {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:needToPush forKey:@"need_to_push"];
}

+ (NSError *)noInternetError {
    return [NSError errorWithDomain:kTODOErrorDomain
                               code:kTODOErrorCodeNoInternet
                           userInfo:@{ NSLocalizedDescriptionKey : @"No internet connection: Cannot sync with Dropbox right now." }];
}

+ (NSError *)fileConflictError {
    return [NSError errorWithDomain:kTODOErrorDomain
                               code:kTODOErrorCodeFileConflict
                           userInfo:@{ NSLocalizedDescriptionKey : @"Dropbox file conflict." }];
}

- (void)presentLoginControllerAnimated:(BOOL)animated {
    if (animated) {
        [self.window.rootViewController performSegueWithIdentifier:kLoginScreenSegueIdentifier sender:self];
    } else {
        [self.window.rootViewController performSegueWithIdentifier:kLoginScreenSegueNotAnimatedIdentifier sender:self];
    }
}

- (void) presentLoginController {
    [self presentLoginControllerAnimated:YES];
}

- (void) presentMainViewController {
    [self.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

// http://stackoverflow.com/questions/9679163/why-does-clearing-nsuserdefaults-cause-exc-crash-later-when-creating-a-uiwebview
//
- (void) clearUserDefaults {
	NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
	
	id workaround51Crash = [[NSUserDefaults standardUserDefaults] objectForKey:@"WebKitLocalStorageDatabasePathPreferenceKey"];
	
	NSDictionary *emptySettings = (workaround51Crash != nil)
	? [NSDictionary dictionaryWithObject:workaround51Crash forKey:@"WebKitLocalStorageDatabasePathPreferenceKey"]
	: [NSDictionary dictionary];
	
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:emptySettings forName:appDomain];
}

- (void)reachabilityChanged {
	if ([self isManualMode]) return;
	
	if ([self.remoteClientManager.currentClient isNetworkAvailable]) {
		if (!self.wasConnected) {
			[self displayNotification:@"Connection reestablished: syncing with Dropbox now..."];
		}
		[self syncClient];
		self.wasConnected = YES;
	} else {
		self.wasConnected = NO;
	}
}

- (void)displayNotification:(NSString *)message {
    // Performing UI operations, so run on the main thread
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        SJNotificationViewController *notificationController = [[SJNotificationViewController alloc] initWithNibName:@"SJNotificationViewController" bundle:nil];
        [notificationController setParentView:self.contentNavController.view];
        [notificationController setNotificationTitle:message];
        
        [notificationController setNotificationDuration:2000];
        [notificationController setBackgroundColor:[UIColor colorWithRed:0
                                                                   green:0
                                                                    blue:0 
                                                                   alpha:0.6f]];
        
        [notificationController show];
    }];
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.taskBag = [TaskBagFactory getTaskBag];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.wasConnected = YES;
   
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
								 @"YES", @"date_new_tasks_preference",
								 @"NO", @"manual_sync_preference", 
								 @"NO", @"need_to_push",
								 @"/todo", @"file_location_preference",
								 @"none", @"badgeCount_preference", nil];
    [defaults registerDefaults:appDefaults];
	
    self.remoteClientManager = [[RemoteClientManager alloc] initWithDelegate:self];
		
	// Start listening for network status updates.
	[Network startNotifier];
    
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(reachabilityChanged) 
												 name:kReachabilityChangedNotification object:nil];
    
    if (![self.remoteClientManager.currentClient isAuthenticated]) {
        // Show the login view during the next iteration of the run loop.
        // It is too early to show the view at this point.
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self presentLoginControllerAnimated:YES];
        }];
    }
	

    UIViewController *rootViewController = self.window.rootViewController;
    
    // Get the nav controller on whose active view notification toasts should show
    self.contentNavController = (UINavigationController *)rootViewController;
    
    // Connect the FilterViewController to its filtering target.
    // The FilterViewController and its target are the two VCs in a split VC;
    // the FilterViewController is the master view controller, and its target is the detail view controller.
    // The detail nav controller is the one on which toasts should show, at index 1 on iPad.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)rootViewController;
        NSArray *viewControllers = [splitViewController viewControllers];
        splitViewController.delegate = (id<UISplitViewControllerDelegate>)[(UINavigationController *)viewControllers[1] topViewController];
        
        [(FilterViewController *)[(UINavigationController *)viewControllers[0] topViewController]
         setFilterTarget:(id<TaskFilterTarget>)[(UINavigationController *)viewControllers[1] topViewController]];
        self.contentNavController = viewControllers[1];
    }
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults synchronize];
	[[NSNotificationCenter defaultCenter] postNotificationName: kTodoChangedNotification object: nil];
	
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
	
	if (![self isManualMode] && [self.remoteClientManager.currentClient isAuthenticated]) {
		[self syncClient];
	}
}


- (void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if ([self.remoteClientManager.currentClient handleOpenURL:url]) {
        if ([self.remoteClientManager.currentClient isAuthenticated]) {
            NSLog(@"App linked successfully!");
            // At this point you can start making API calls
        }
        return YES;
    }
    // Add whatever other url handling code your app requires here
    return NO;
}

#pragma mark -
#pragma mark Remote functions

- (void) syncClient {
	[self syncClientForce:NO];
}

- (void) syncClientForce:(BOOL)force {
	if ([self isManualMode]) {
		UIActionSheet* dlg = [[UIActionSheet alloc] 
							  initWithTitle:@"Manual Sync: Do you want to upload or download your todo.txt file?"
							  delegate:self 
							  cancelButtonTitle:@"Cancel" 
							  destructiveButtonTitle:nil 
							  otherButtonTitles:@"Upload changes", @"Download to device", nil ];
		dlg.tag = 10;
		[dlg showInView:self.contentNavController.visibleViewController.view];
	} else if ([TodoTxtAppDelegate needToPush]) {
		[self pushToRemoteOverwrite:NO force:force];
	} else {
		[self pullFromRemoteForce:force];
	}
}

- (void) pushToRemoteOverwrite:(BOOL)overwrite force:(BOOL)force {
	[TodoTxtAppDelegate setNeedToPush:YES];

	if (!force && [self isManualMode]) {
		return;
	}
	
	if (![self.remoteClientManager.currentClient isNetworkAvailable]) {
		[self displayNotification:@"No internet connection: Cannot sync with Dropbox right now."];
        NSError *err = [TodoTxtAppDelegate noInternetError];
        [self syncCompleteWithError:err];
		return;
	}
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	// We probably shouldn't be assuming LocalFileTaskRepository here, 
	// but that is what the Android app does, so why not?
	NSString *todoPath = [LocalFileTaskRepository todoFilename];
	NSString *donePath = nil;
	
	if ([self.taskBag doneFileModifiedSince:self.lastSync]) {
		donePath = [LocalFileTaskRepository doneFilename];
	}
	
	[self.remoteClientManager.currentClient pushTodoOverwrite:overwrite
                                                     withTodo:todoPath
                                                     withDone:donePath];

    // pushTodo is asynchronous. When it returns, it will call
    // the delegate method 'uploadedFile'
}

- (void) pushToRemote {
	[self pushToRemoteOverwrite:NO force:NO];
}

- (void) pullFromRemoteForce:(BOOL)force {
	if (!force && [self isManualMode]) {
		return;
	}
	
	[TodoTxtAppDelegate setNeedToPush:NO];

	if (![self.remoteClientManager.currentClient isNetworkAvailable]) {
		[self displayNotification:@"No internet connection: Cannot sync with Dropbox right now."];
        [self syncCompleteWithError:[TodoTxtAppDelegate noInternetError]];
		return;
	}
	
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
	[self.remoteClientManager.currentClient pullTodo];
    // pullTodo is asynchronous. When it returns, it will call
    // the delegate method 'loadedFile'
}

- (void) pullFromRemote {
	[self pullFromRemoteForce:NO];
}

- (BOOL) isManualMode {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
	return [defaults boolForKey:@"manual_sync_preference"];
}

- (void) logout {
	[self.remoteClientManager.currentClient deauthenticate];
	[self clearUserDefaults];
	[self presentLoginController];
}

- (void) syncCompleteWithError:(NSError *)error {
    NSDictionary *syncInfoDict = nil;
    
	if (error == nil) {
		[TodoTxtAppDelegate setNeedToPush:NO];
		self.lastSync = [NSDate date];
        
        syncInfoDict = @{ };
	} else {
        syncInfoDict = @{ kTODOSyncErrorKey : error };
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kTODOSyncFinishedNotificationName
                                                        object:nil
                                                      userInfo:syncInfoDict];
}

#pragma mark -
#pragma mark RemoteClientDelegate methods

- (void)remoteClient:(id<RemoteClient>)client loadedTodoFile:(NSString*)todoPath loadedDoneFile:(NSString*)donePath{
	if (todoPath) {
		[self.taskBag reloadWithFile:todoPath];
		// Send notification so that whichever screen is active can refresh itself
		[[NSNotificationCenter defaultCenter] postNotificationName: kTodoChangedNotification object: nil];
	}
	
	if (donePath) {
		[self.taskBag loadDoneTasksWithFile:donePath];
	}

	[self syncCompleteWithError:nil];
}

- (void) remoteClient:(id<RemoteClient>)client loadFileFailedWithError:(NSError *)error {
	NSLog(@"Error downloading todo.txt file: %@", error);
	
	if (error.code == 404) {
		// ignore missing file. They may not have created one yet.
		[self syncCompleteWithError:nil];
		return;
	}
	
	[self syncCompleteWithError:error];
    
	UIAlertView *alert =
	[[UIAlertView alloc] initWithTitle: @"Error"
							   message: @"There was an error downloading your todo.txt file."
							  delegate: nil
					 cancelButtonTitle: @"OK"
					 otherButtonTitles: nil];
    [alert show];
}

- (void)remoteClient:(id<RemoteClient>)client uploadedFile:(NSString*)destPath {
	[TodoTxtAppDelegate setNeedToPush:NO];

    // Push is complete. Let's do a pull now in case the remote done.txt changed
	[self pullFromRemoteForce:YES];
}

- (void) remoteClient:(id<RemoteClient>)client uploadFileFailedWithError:(NSError *)error {
	NSLog(@"Error uploading todo file: %@", error);
	
	[self syncCompleteWithError:error];
	
	UIAlertView *alert =
	[[UIAlertView alloc] initWithTitle: @"Error"
							   message: @"There was an error uploading your todo.txt file."
							  delegate: nil
					 cancelButtonTitle: @"OK"
					 otherButtonTitles: nil];
    [alert show];
}

- (void)remoteClient:(id<RemoteClient>)client uploadFileFailedWithConflict:(NSString*)destPath {
	// alert user to the conflict and ask if he wants to force push or pull
	NSLog(@"Upload conflict");
    
    NSError *err = [TodoTxtAppDelegate fileConflictError];
	[self syncCompleteWithError:err];
	
	NSString *message = [NSString 
		stringWithFormat:@"Oops! There is a newer version of your %@ file in Dropbox. "
						 "Do you want to upload your local changes, or download the Dropbox version?",
						 [destPath lastPathComponent]
						 ];
	
	UIAlertView *alert =
	[[UIAlertView alloc] initWithTitle: @"File Conflict"
							   message: message
							  delegate: self
					 cancelButtonTitle: @"Cancel"
					 otherButtonTitles: @"Upload changes", @"Download to device", nil];
    [alert show];
}

- (void)remoteClient:(id<RemoteClient>)client loginControllerDidLogin:(BOOL)success {
	if (success) {
		// If we login using the Dropbox app we will sync after re-activation.
		// But, if we login using the webview, we never leave the app,
		// so we have to sync now. Unfortunately, this causes a double
		// sync when the Dropbox app is used, but I don't see an easy way around that.
        [self syncClient];
		[self presentMainViewController];
	}
}

#pragma mark -
#pragma mark Alert view delegate methods

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == [alertView firstOtherButtonIndex]) {
		[self pushToRemoteOverwrite:YES force:YES];
	} else if (buttonIndex == [alertView firstOtherButtonIndex] + 1){
		[self pullFromRemoteForce:YES];
	}
}

#pragma mark -
#pragma mark Action sheet delegate methods

- (void)actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (actionSheet.tag == 10) {
        if (buttonIndex == [actionSheet firstOtherButtonIndex]) {
            [self pushToRemoteOverwrite:NO force:YES];
        } else if (buttonIndex == [actionSheet firstOtherButtonIndex] + 1){
            [self pullFromRemoteForce:YES];
        }
	}
}

#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}

- (void)dealloc {
    self.loginController = nil;
    self.viewController = nil;
}


@end
