//
//  FilterViewController.m
//  todo.txt-touch-ios
//
//  Created by Brendon Justin on 6/14/13.
//
//

#import "FilterViewController.h"

#import "Task.h"
#import "TaskBag.h"
#import "todo_txt_touch_iosAppDelegate.h"

typedef NS_ENUM(NSInteger, FilterViewFilterTypes) {
    FilterViewFilterTypesContexts = 0,
    FilterViewFilterTypesProjects,
    FilterViewFilterTypesFirst = FilterViewFilterTypesContexts,
    FilterViewFilterTypesLast = FilterViewFilterTypesProjects
};

typedef NS_OPTIONS(NSInteger, FilterViewActiveTypes) {
    FilterViewActiveTypesContexts = 1 << 0,
    FilterViewActiveTypesProjects = 1 << 1,
    FilterViewActiveTypesAll = FilterViewActiveTypesContexts | FilterViewActiveTypesProjects
};

@interface FilterViewController ()

- (FilterViewFilterTypes)typeOfFilterForSection:(NSInteger)section;
- (void)filterOnContextsAndProjects;
- (IBAction)selectedSegment:(UISegmentedControl *)sender;

@property (assign, nonatomic) IBOutlet UISegmentedControl *typeSegmentedControl;
@property (strong, nonatomic) NSArray *contexts;
@property (strong, nonatomic) NSArray *projects;
@property (strong, nonatomic) NSMutableArray *selectedContexts;
@property (strong, nonatomic) NSMutableArray *selectedProjects;
@property (readonly, nonatomic) BOOL haveContexts;
@property (readonly, nonatomic) BOOL haveProjects;
@property (nonatomic) FilterViewActiveTypes activeTypes;

@end

@implementation FilterViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Filter";
    self.navigationItem.titleView = self.typeSegmentedControl;
    
    self.selectedContexts = [NSMutableArray array];
    self.selectedProjects = [NSMutableArray array];
    
    self.activeTypes = FilterViewActiveTypesAll;
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"FilterCell"];
}

- (void)viewWillAppear:(BOOL)animated
{
    __weak __typeof(&*self)weakSelf = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:kTodoChangedNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      __strong __typeof(&*weakSelf)strongSelf = weakSelf;
                                                      
                                                      id<TaskBag> taskBag = [todo_txt_touch_iosAppDelegate sharedTaskBag];
                                                      [taskBag reload];
                                                      NSArray *tasks = taskBag.tasks;
                                                      
                                                      // Get unique contexts and projects by adding all such items
                                                      // to two sets, then creating arrays from those sets.
                                                      NSMutableSet *contexts = [NSMutableSet set];
                                                      NSMutableSet *projects = [NSMutableSet set];
                                                      for (Task *task in tasks) {
                                                          [contexts addObjectsFromArray:task.contexts];
                                                          [projects addObjectsFromArray:task.projects];
                                                      }
                                                      
                                                      NSSortDescriptor *sortDesc = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES];
                                                      strongSelf.contexts = [contexts sortedArrayUsingDescriptors:@[ sortDesc ]];
                                                      strongSelf.projects = [projects sortedArrayUsingDescriptors:@[ sortDesc ]];
                                                      
                                                      [strongSelf.tableView reloadData];
                                                  }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kTodoChangedNotification
                                                  object:nil];
}

#pragma mark - Custom getters/setters

- (BOOL)haveContexts
{
    return (self.contexts.count > 0 && (self.activeTypes & FilterViewActiveTypesContexts));
}

- (BOOL)haveProjects
{
    return (self.projects.count > 0 && (self. activeTypes & FilterViewActiveTypesProjects));
}

#pragma mark - Private methods

- (FilterViewFilterTypes)typeOfFilterForSection:(NSInteger)section
{
    if (self.haveContexts && section == 0) {
        return FilterViewFilterTypesContexts;
    } else {
        return FilterViewFilterTypesProjects;
    }
}

- (void)filterOnContextsAndProjects
{
    NSArray *filterContexts = nil;
    NSArray *filterProjects = nil;
    
    if (self.haveContexts) {
        filterContexts = self.selectedContexts;
    }
    
    if (self.haveProjects) {
        filterProjects = self.selectedProjects;
    }
    
    [self.filterTarget filterForContexts:filterContexts projects:filterProjects];
}

#pragma mark - Table view data source

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *const contextsTitle = @"Contexts";
    NSString *const projectsTitle = @"Projects";
    
    switch ([self typeOfFilterForSection:section]) {
        case FilterViewFilterTypesContexts:
            return contextsTitle;
            break;
            
        case FilterViewFilterTypesProjects:
            return projectsTitle;
            break;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    NSInteger numSections = 0;
    
    if (self.haveContexts) {
        numSections++;
    }
    
    if (self.haveProjects) {
        numSections++;
    }
    
    return numSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    switch ([self typeOfFilterForSection:section]) {
        case FilterViewFilterTypesContexts:
            return self.contexts.count;
            break;
            
        case FilterViewFilterTypesProjects:
            return self.projects.count;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"FilterCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    // Configure the cell...
    
    NSString *text = nil;
    switch ([self typeOfFilterForSection:indexPath.section]) {
        case FilterViewFilterTypesContexts:
            text = [NSString stringWithFormat:@"@%@", self.contexts[indexPath.row]];
            break;
            
        case FilterViewFilterTypesProjects:
            text = [NSString stringWithFormat:@"+%@", self.projects[indexPath.row]];
            break;
    }
    cell.textLabel.text = text;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Update contexts and projects to filter on
    switch ([self typeOfFilterForSection:indexPath.section]) {
        case FilterViewFilterTypesContexts:
            [self.selectedContexts addObject:self.contexts[indexPath.row]];
            break;
            
        case FilterViewFilterTypesProjects:
            [self.selectedProjects addObject:self.projects[indexPath.row]];
            break;
    }
    
    [self filterOnContextsAndProjects];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Update contexts and projects to filter on
    switch ([self typeOfFilterForSection:indexPath.section]) {
        case FilterViewFilterTypesContexts:
            [self.selectedContexts removeObject:self.contexts[indexPath.row]];
            break;
            
        case FilterViewFilterTypesProjects:
            [self.selectedProjects removeObject:self.projects[indexPath.row]];
            break;
    }
    
    [self filterOnContextsAndProjects];
}

#pragma mark - IBActions

- (void)selectedSegment:(UISegmentedControl *)sender
{
    // Clear selections whenever a different section is selected.
    [self.selectedContexts removeAllObjects];
    [self.selectedProjects removeAllObjects];
    [self filterOnContextsAndProjects];
    
    // Set the filter types to show based on the selected segment.
    switch (sender.selectedSegmentIndex) {
        case 0:
            self.activeTypes = FilterViewActiveTypesAll;
            [self.tableView reloadData];
            break;
            
        case 1:
            self.activeTypes = FilterViewActiveTypesContexts;
            [self.tableView reloadData];
            break;
            
        case 2:
            self.activeTypes = FilterViewActiveTypesProjects;
            [self.tableView reloadData];
            break;
            
        default:
            break;
    }
}

@end