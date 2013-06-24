/**
 * This file is part of Todo.txt Touch, an iOS app for managing your todo.txt file.
 *
 * @author Todo.txt contributors <todotxt@yahoogroups.com>
 * @copyright 2011-2013 Todo.txt contributors (http://todotxt.com)
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

#import "ActionSheetPicker.h"
#import "AsyncTask.h"
#import "UIColor+CustomColors.h"
#import "Task.h"
#import "TaskCell.h"
#import "TaskCellViewModel.h"
#import "TaskEditViewController.h"
#import "TaskViewController.h"
#import "TasksViewController.h"
#import "TodoTxtAppDelegate.h"
#import "FilterFactory.h"
#import "IASKAppSettingsViewController.h"
#import "ActionSheetPicker.h"

#import <ReactiveCocoa/ReactiveCocoa.h>

#define LOGOUT_TAG 10
#define ARCHIVE_TAG 11

static NSString *const kEmptyFileMessage = @"Your todo.txt file is empty. \
\n\n\
Tap the + button to add your first todo.";

static NSString *const kNoFilterResultsMessage = @"No results for chosen \
contexts and projects.";

static NSString *const kCellIdentifier = @"FlexiTaskCell";

@interface TasksViewController () <IASKSettingsDelegate>

@property (nonatomic, strong) IBOutlet UITableView *table;
@property (nonatomic, strong) IBOutlet UITableViewCell *tableCell;
@property (strong, nonatomic) IBOutlet UILabel *emptyLabel;
@property (nonatomic, strong) NSArray *tasks;
@property (nonatomic, strong) Sort *sort;
@property (nonatomic, copy) NSString *savedSearchTerm;
@property (nonatomic, strong) NSArray *searchResults;
@property (weak, nonatomic, readonly) NSArray *filteredTasks;
@property (nonatomic, strong) id<Filter> filter;
@property (nonatomic, strong) IASKAppSettingsViewController *appSettingsViewController;
@property (nonatomic, strong) ActionSheetPicker *actionSheetPicker;
@property (nonatomic) BOOL needSync;

@end

@implementation TasksViewController

#pragma mark -
#pragma mark Synthesizers

- (Sort*) sortOrderPref {
	SortName name = SortPriority;
	NSUserDefaults* def = [NSUserDefaults standardUserDefaults];
	if (def) name = [def integerForKey:@"sortOrder"];
	return [Sort byName:name];
}

- (void) setSortOrderPref {
	NSUserDefaults* def = [NSUserDefaults standardUserDefaults];
	if (def) {
		[def setInteger:[self.sort name] forKey:@"sortOrder"];
		[AsyncTask runTask:@selector(synchronize) onTarget:def];
	}
}

- (void) reloadData:(NSNotification *) notification {
	// reload global tasklist from disk
	[[TodoTxtAppDelegate sharedTaskBag] reload];	

	// reload main tableview data
	self.tasks = [[TodoTxtAppDelegate sharedTaskBag] tasksWithFilter:nil withSortOrder:self.sort];
	[self.table reloadData];
	
	// reload searchbar tableview data if necessary
	if (self.savedSearchTerm)
	{	
		id<Filter> filter = [FilterFactory getAndFilterWithPriorities:nil contexts:nil projects:nil text:self.savedSearchTerm caseSensitive:NO];
		self.searchResults = [[TodoTxtAppDelegate sharedTaskBag] tasksWithFilter:filter withSortOrder:self.sort];
		[self.searchDisplayController.searchResultsTableView reloadData];
	}
}

- (NSArray*) taskListForTable:(UITableView*)tableView {
	if(tableView == self.searchDisplayController.searchResultsTableView) {
		return self.searchResults;
	} else {
		return self.filteredTasks;
	}
}

- (Task*) taskForTable:(UITableView*)tableView atIndex:(NSUInteger)index {
	if(tableView == self.searchDisplayController.searchResultsTableView) {
		return [self.searchResults objectAtIndex:index];
	} else {
		return [self.filteredTasks objectAtIndex:index];
	}
}


- (void)hideSearchBar:(BOOL)animated {
	if (animated) {
		[UIView beginAnimations:@"hidesearchbar" context:nil];
		[UIView setAnimationDuration:0.4];
		[UIView setAnimationBeginsFromCurrentState:YES];
	}
	
	self.table.contentOffset = CGPointMake(0, self.searchDisplayController.searchBar.frame.size.height);
	
	if (animated) {
		[UIView commitAnimations];
	}
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = @"Tasks";
    
	self.sort = [self sortOrderPref];
	self.tasks = nil;
	
	// Restore search term
	if (self.savedSearchTerm)
	{
		self.searchDisplayController.searchBar.text = self.savedSearchTerm;
	}
	
	UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonPressed:)];          
	self.navigationItem.rightBarButtonItem = addButton;
	
	UIBarButtonItem *sortButton = [[UIBarButtonItem alloc] initWithTitle:@"Sort" style:UIBarButtonItemStyleBordered target:self action:@selector(sortButtonPressed:)];          
	self.navigationItem.leftBarButtonItem = sortButton;

    self.emptyLabel.text = kEmptyFileMessage;
    
    [self.table registerNib:[UINib nibWithNibName:@"TaskCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:kCellIdentifier];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSLog(@"viewWillAppear - tableview");
	[self hideSearchBar:NO];
	[self reloadData:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(reloadData:) 
												 name:kTodoChangedNotification 
											   object:nil];
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) viewDidAppear:(BOOL)animated {	
	if (self.needSync) {
		self.needSync = NO;
        if (![TodoTxtAppDelegate isManualMode]) {
			[TodoTxtAppDelegate syncClient];
        }
	}	
}

#pragma mark -
#pragma mark Overridden getters/setters

- (NSArray *)filteredTasks
{
    return [[TodoTxtAppDelegate sharedTaskBag] tasksWithFilter:self.filter withSortOrder:self.sort];
}

- (IASKAppSettingsViewController*)appSettingsViewController {
	if (!_appSettingsViewController) {
		_appSettingsViewController = [[IASKAppSettingsViewController alloc] initWithNibName:@"IASKAppSettingsView" bundle:nil];
		_appSettingsViewController.delegate = self;
	}
	return _appSettingsViewController;
}

#pragma mark -
#pragma mark Table view datasource methods

// Return the number of sections in table view
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Return the number of rows in the section of table view
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[self taskListForTable:tableView] count];
}

// Return cell for the rows in table view
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Task *task = [self taskForTable:tableView atIndex:indexPath.row];
    TaskCellViewModel *viewModel = [[TaskCellViewModel alloc] init];
    viewModel.task = task;
    
    TaskCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    cell.viewModel = viewModel;
    
    // Dispose of any existing connections
    if (cell.textDisposable) {
        [@[
         cell.textDisposable,
         cell.ageDisposable,
         cell.priorityDisposable,
         cell.priorityColorDisposable,
         cell.showDateDisposable
         ] enumerateObjectsUsingBlock:^(RACDisposable *disposable, NSUInteger idx, BOOL *stop) {
             [disposable dispose];
         }];
    }
    
    // Avoid RAC(...) so that we can save the RACDisposables, to manually dispose of later.
    // This is necessary since cells are (usually) re-used, rather than destroyed and recreated.
    cell.textDisposable = [RACAbleWithStart(viewModel, attributedText) toProperty:@keypath(cell.taskTextView, attributedText)
                                                                         onObject:cell.taskTextView];
    cell.ageDisposable = [RACAbleWithStart(viewModel, ageText) toProperty:@keypath(cell.ageLabel, text)
                                                                 onObject:cell.ageLabel];
    cell.priorityDisposable = [RACAbleWithStart(viewModel, priorityText) toProperty:@keypath(cell.priorityLabel, text)
                                                                           onObject:cell.priorityLabel];
    cell.priorityColorDisposable = [RACAbleWithStart(viewModel, priorityColor) toProperty:@keypath(cell.priorityLabel, textColor)
                                                                                 onObject:cell.priorityLabel];
    cell.showDateDisposable = [RACAbleWithStart(viewModel, shouldShowDate) toProperty:@keypath(cell, shouldShowDate)
                                                                             onObject:cell];
    
    cell.viewModel = viewModel;
    
    // Set the height of our frame as necessary for the task's text.
    CGRect frame = cell.frame;
    frame.size.height = [TaskCell heightForTask:task givenWidth:CGRectGetWidth(tableView.frame)];
    cell.frame = frame;
    
	return cell;
}


#pragma mark -
#pragma mark Table view delegate methods

// Return the height for tableview cells
-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    Task* task = [self taskForTable:tableView atIndex:indexPath.row];
    return [TaskCell heightForTask:task givenWidth:CGRectGetWidth(tableView.frame)];
}

// Load the detail view controller when user taps the row
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Task *task = [self taskForTable:tableView atIndex:indexPath.row];
	
	/*
     When a row is selected, create the detail view controller and set its detail item to the item associated with the selected row.
     */
    TaskViewController *detailViewController = [[TaskViewController alloc] init];
    detailViewController.task = task;
    
    // Push the detail view controller.
    [[self navigationController] pushViewController:detailViewController animated:YES];
}

#pragma mark -
#pragma mark Search bar delegate methods

- (void)handleSearchForTerm:(NSString *)searchTerm {
	self.savedSearchTerm = searchTerm;
	id<Filter> filter = [FilterFactory getAndFilterWithPriorities:nil contexts:nil projects:nil text:self.savedSearchTerm caseSensitive:NO];
	self.searchResults = [[TodoTxtAppDelegate sharedTaskBag] tasksWithFilter:filter withSortOrder:self.sort];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller 
shouldReloadTableForSearchString:(NSString *)searchString
{
	[self handleSearchForTerm:searchString];
    
	return YES;
}

- (void)searchDisplayControllerWillEndSearch:(UISearchDisplayController *)controller
{
	self.savedSearchTerm = nil;
	[self reloadData:nil];
}

-(UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;    
}

-(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    id<TaskBag> taskBag = [TodoTxtAppDelegate sharedTaskBag];
    Task *task = [self taskForTable:tableView atIndex:indexPath.row];
    
    if (task.completed) {
        [task markIncomplete];
    } else {
        [task markComplete:[NSDate date]];
    }
    
    [taskBag update:task];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"auto_archive_preference"]) {
		[taskBag archive];
	}
	
    [self reloadData:nil];
    [TodoTxtAppDelegate pushToRemote];
}

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    Task *task = [self taskForTable:tableView atIndex:indexPath.row];
    
    if (task.completed) {
        return @"Undo Complete";
    } else {
        return @"Complete";
    }
}


- (IBAction)addButtonPressed:(id)sender {
	NSLog(@"addButtonPressed called");
    TaskEditViewController *taskEditView = [[TaskEditViewController alloc] init];
    [taskEditView setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    [self presentModalViewController:taskEditView animated:YES];
}

- (IBAction)syncButtonPressed:(id)sender {
	NSLog(@"syncButtonPressed called");
	[TodoTxtAppDelegate displayNotification:@"Syncing with Dropbox now..."];
	[TodoTxtAppDelegate syncClient];
}

- (IBAction)settingsButtonPressed:(id)sender {
    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:self.appSettingsViewController];
    //[viewController setShowCreditsFooter:NO];   // Uncomment to not display InAppSettingsKit credits for creators.
    // But we encourage you not to uncomment. Thank you!
    self.appSettingsViewController.showDoneButton = YES;
    [self presentModalViewController:aNavController animated:YES];
}

#pragma mark -
#pragma mark IASKAppSettingsViewControllerDelegate protocol
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    [self dismissModalViewControllerAnimated:YES];
    [[TodoTxtAppDelegate sharedTaskBag] updateBadge];
	self.needSync = YES;
}

#pragma mark -
- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForKey:(NSString*)key {
	if ([key isEqualToString:@"logout_button"]) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Are you sure?" 
														 message:@"Are you sure you wish to log out of Dropbox?" 
														delegate:self 
											   cancelButtonTitle:@"Cancel"
											   otherButtonTitles:nil];
		alert.tag = LOGOUT_TAG;
		[alert addButtonWithTitle:@"Log out"];
		[alert show];
	}
	if ([key isEqualToString:@"archive_button"]) {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Are you sure?" 
														 message:@"Are you sure you wish to archive your completed tasks?" 
														delegate:self 
											   cancelButtonTitle:@"Cancel"
											   otherButtonTitles:nil];
		alert.tag = ARCHIVE_TAG;
		[alert addButtonWithTitle:@"Archive"];
		[alert show];
	}
    else if([key isEqualToString:@"about_todo"]) {
        NSURL *url = [NSURL URLWithString:@"http://todotxt.com"];
        [[UIApplication sharedApplication] openURL:url];
    }
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {

        switch (alertView.tag) {
			case LOGOUT_TAG:
                [self dismissModalViewControllerAnimated:NO];
				[TodoTxtAppDelegate logout];
				break;
			case ARCHIVE_TAG:
                [self dismissModalViewControllerAnimated:YES];
                NSLog(@"Archiving...");
				[TodoTxtAppDelegate displayNotification:@"Archiving completed tasks..."];
				[[TodoTxtAppDelegate sharedTaskBag] archive];
				[self reloadData:nil];
				[TodoTxtAppDelegate pushToRemote];
				break;
			default:
				break;
		}		
    }
}

- (void) sortOrderWasSelected:(NSNumber *)selectedIndex element:(id)element {
	self.actionSheetPicker = nil;
	if (selectedIndex.intValue >= 0) {
		self.sort = [Sort byName:selectedIndex.intValue];
		[self setSortOrderPref];
		[self reloadData:nil];
		[self hideSearchBar:NO];
	}
}

//- (IBAction)segmentControlPressed:(id)sender {
//	[actionSheetPicker actionPickerCancel];
//	self.actionSheetPicker = nil;
//	UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
//	CGRect rect = [self.view convertRect:segmentedControl.frame fromView:segmentedControl];
//	rect = CGRectMake(segmentedControl.frame.origin.x + segmentedControl.frame.size.width / 4, rect.origin.y, 
//					  rect.size.width, rect.size.height);
//	switch (segmentedControl.selectedSegmentIndex) {
//		case 0: // Filter
//			break;
//		case 1: // Sort
//			self.actionSheetPicker = [ActionSheetPicker displayActionPickerWithView:self.view 
//																			   data:[Sort descriptions]
//																	  selectedIndex:[sort name]
//																			 target:self 
//																			 action:@selector(sortOrderWasSelected:element:)
//																			  title:@"Select Sort Order"
//																			   rect:rect
//																	  barButtonItem:nil];			
//			break;
//	}
//}

- (IBAction)sortButtonPressed:(id)sender {
	[self.actionSheetPicker actionPickerCancel];
	self.actionSheetPicker = nil;
	self.actionSheetPicker = [ActionSheetPicker displayActionPickerWithView:self.view 
																	   data:[Sort descriptions]
															  selectedIndex:[self.sort name]
																	 target:self 
																	 action:@selector(sortOrderWasSelected:element:)
																	  title:@"Select Sort Order"
																	   rect:CGRectZero
															  barButtonItem:sender];			
}

- (void)didReceiveMemoryWarning {
	NSLog(@"Memory warning!");
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	[super viewDidUnload];
	
	// Save the state of the search UI so that it can be restored if the view is re-created.
	self.savedSearchTerm = self.searchDisplayController.searchBar.text;
	self.searchResults = nil;
	
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	self.table = nil;
	self.tableCell = nil;
	self.actionSheetPicker = nil;
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self reloadData:nil];
    [self hideSearchBar:YES];   
	[self.actionSheetPicker actionPickerCancel];
	self.actionSheetPicker = nil;
}

#pragma mark - TaskFilterable methods

- (void)filterForContexts:(NSArray *)contexts projects:(NSArray *)projects
{
    self.filter = [FilterFactory getAndFilterWithPriorities:nil contexts:contexts projects:projects text:nil caseSensitive:NO];
    
    if (contexts.count || projects.count) {
        self.emptyLabel.text = kNoFilterResultsMessage;
    } else {
        self.emptyLabel.text = kEmptyFileMessage;
    }
    
	// reload main tableview data to use the filter
    [self.table reloadData];
}

@end
