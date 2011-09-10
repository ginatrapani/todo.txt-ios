/**
 *
 * Todo.txt-Touch-iOS/Classes/todo_txt_touch_iosViewController.m
 *
 * Copyright (c) 2009-2011 Gina Trapani, Shawn McGuire
 *
 * LICENSE:
 *
 * This file is part of Todo.txt Touch, an iOS app for managing your todo.txt file (http://todotxt.com).
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
 * @author Gina Trapani <ginatrapani[at]gmail[dot]com>
 * @author Shawn McGuire <mcguiresm[at]gmail[dot]com> 
 * @license http://www.gnu.org/licenses/gpl.html
 * @copyright 2009-2011 Gina Trapani, Shawn McGuire
 *
 * Copyright (c) 2011 Gina Trapani and contributors, http://todotxt.com
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

#import "todo_txt_touch_iosViewController.h"
#import "todo_txt_touch_iosAppDelegate.h"
#import "TaskEditViewController.h"
#import "TaskViewController.h"
#import "Color.h"
#import "ActionSheetPicker.h"
#import "AsyncTask.h"

@implementation todo_txt_touch_iosViewController

#pragma mark -
#pragma mark Synthesizers

@synthesize table, tableCell;

- (Sort*) sortOrderPref {
	SortName name = SortPriority;
	NSUserDefaults* def = [NSUserDefaults standardUserDefaults];
	if (def) name = [def integerForKey:@"sortOrder"];
	return [Sort byName:name];
}

- (void) setSortOrderPref {
	NSUserDefaults* def = [NSUserDefaults standardUserDefaults];
	if (def) {
		[def setInteger:[sort name] forKey:@"sortOrder"];
		[AsyncTask runTask:@selector(synchronize) onTarget:def];
	}
}

- (void) reloadData:(NSNotification *) notification {
	[[todo_txt_touch_iosAppDelegate sharedTaskBag] reload];	
	[tasks release];
	tasks = [[[todo_txt_touch_iosAppDelegate sharedTaskBag] tasksWithFilter:nil withSortOrder:sort] retain];
	[table reloadData];
}


/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/



// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = @"Todo.txt Touch";
	self.navigationItem.backBarButtonItem =
		[[[UIBarButtonItem alloc] initWithTitle:@"Task List"
										  style:UIBarButtonItemStyleBordered
										 target:nil
										 action:nil] autorelease];
	
	sort = [self sortOrderPref];
	tasks = nil;
	
	// FIXME: This logout button is temporary until we implement the settings screen.
	UIBarButtonItem *logoutButton = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStyleBordered target:self action:@selector(logoutButtonPressed:)];          
	self.navigationItem.rightBarButtonItem = logoutButton;
	[logoutButton release];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSLog(@"viewWillAppear - tableview");
	[table setContentOffset:CGPointZero animated:NO];
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

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

#pragma mark -
#pragma mark Table view datasource methods

// Return the number of sections in table view
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

// Return the number of rows in the section of table view
-(NSInteger) tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [tasks count];
}

// Return cell for the rows in table view
-(UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Create the cell identifier
	static NSString *CellIdentifier = @"TaskTableCell";
	
	// Create the cell if cells are available with same cell identifier
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	
	// If there are no cells available, allocate a new one with Default style
	if (cell == nil) {
		[[NSBundle mainBundle] loadNibNamed:CellIdentifier owner:self options:nil];
		cell = tableCell;
		self.tableCell = nil;
	}
	
	// Set the title for the cell
	Task *task = [tasks objectAtIndex:indexPath.row];
		
	UILabel *label;
    label = (UILabel *)[cell viewWithTag:1];
    label.text = [NSString stringWithFormat:@"%02d", [task taskId] + 1];
	
    label = (UILabel *)[cell viewWithTag:2];
    label.text = [[task priority] listFormat];
	// Set the priority color
	PriorityName n = [[task priority] name];
	switch (n) {
		case PriorityA:
			//Set color to green #587058
			label.textColor = [Color green];
			break;
		case PriorityB:
			//Set color to blue #587498
			label.textColor = [Color blue];
			break;
		case PriorityC:
			//Set color to orange #E86850
			label.textColor = [Color orange];
			break;
		case PriorityD:
			//Set color to gold #587058
			label.textColor = [Color gold];
			break;			
		default:
			//Set color to black #000000
			label.textColor = [Color black];
			break;
	}
	
    label = (UILabel *)[cell viewWithTag:3];
    label.text = [task inScreenFormat];
	if ([task completed]) {
		// TODO: There doesn't seem to be a strikethrough option for UILabel.
		// For now, let's just disable the label.
		label.enabled = NO;
	} else {
		label.enabled = YES;
	}
	
	label = (UILabel *)[cell viewWithTag:4];
    if (![task completed]) {
		label.text = [task relativeAge];
	} else {
		label.text = @"";
	}
	
	return cell;
}


#pragma mark -
#pragma mark Table view delegate methods

// Return the height for tableview cells
-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 50; // Default height for the cell is 44 px;
}

// Load the detail view controller when user taps the row
-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
    
	/*
     When a row is selected, create the detail view controller and set its detail item to the item associated with the selected row.
     */
    TaskViewController *detailViewController = [[TaskViewController alloc] initWithStyle:UITableViewStyleGrouped];
    
    detailViewController.taskIndex = 
		[[todo_txt_touch_iosAppDelegate sharedTaskBag] indexOfTask:
			[tasks objectAtIndex:indexPath.row]];
    
    // Push the detail view controller.
    [[self navigationController] pushViewController:detailViewController animated:YES];
    [detailViewController release];
}

- (IBAction)addButtonPressed:(id)sender {
	NSLog(@"addButtonPressed called");
    TaskEditViewController *taskEditView = [[[TaskEditViewController alloc] init] autorelease];
    [taskEditView setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    [self presentModalViewController:taskEditView animated:YES];
}

- (IBAction)syncButtonPressed:(id)sender {
	NSLog(@"syncButtonPressed called");
	[todo_txt_touch_iosAppDelegate syncClient];
}

- (IBAction)logoutButtonPressed:(id)sender {
	NSLog(@"syncButtonPressed called");
	
	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Are you sure?" 
													 message:@"Are you sure you wish to log out of Dropbox?" 
													delegate:self 
										   cancelButtonTitle:@"Cancel"
										   otherButtonTitles:nil] autorelease];
    [alert addButtonWithTitle:@"Log out"];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [todo_txt_touch_iosAppDelegate logout];
    }
}

- (void) sortOrderWasSelected:(NSNumber *)selectedIndex:(id)element {
	sort = [Sort byName:selectedIndex.intValue];
	[self setSortOrderPref];
	[tasks release];
	tasks = [[[todo_txt_touch_iosAppDelegate sharedTaskBag] tasksWithFilter:nil withSortOrder:sort] retain];
	[table reloadData];
    [table setContentOffset:CGPointZero animated:NO];	
}

- (IBAction)segmentControlPressed:(id)sender {
	UISegmentedControl *segmentedControl = (UISegmentedControl *)sender;
	switch (segmentedControl.selectedSegmentIndex) {
		case 0: // Filter
			break;
		case 1: // Sort
			[ActionSheetPicker displayActionPickerWithView:self.view 
					data:[Sort descriptions]
					selectedIndex:[sort name]
					target:self 
					action:@selector(sortOrderWasSelected::) 
					 title:@"Select Sort Order"];			
			break;
	}
}

- (void)didReceiveMemoryWarning {
	NSLog(@"Memory warning!");
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	self.table = nil;
}


- (void)dealloc {
	[table release];
    [super dealloc];
}

@end
