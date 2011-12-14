/**
 *
 * Todo.txt-Touch-iOS/Classes/todo_txt_touch_iosAppDelegate.h
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

#import "TaskBagImpl.h"
#import "todo_txt_touch_iosAppDelegate.h"
#import "RemoteClientManager.h"
#import "RemoteClient.h"
#import "LocalFileTaskRepository.h"
#import "TaskIo.h"

Task* find(NSArray *tasks, Task *task) {
	for(int i = 0; i < [tasks count]; i++) {
		Task *taski = [tasks objectAtIndex:i];
		if([taski.text isEqualToString:task.originalText] &&
		   [taski.priority isEqual:task.originalPriority]) {
			return taski;
		}
	}
    return nil;
}

@implementation TaskBagImpl

- (id) initWithRepository:(id <LocalTaskRepository>)repo {
    self = [super init];
    
	if (self) {
        localTaskRepository = [repo retain];
        tasks = nil;
	}
	
	return self;
   
}

- (void) reload {
    [localTaskRepository create];
    [tasks release];
    tasks = [[localTaskRepository load] retain];
}

- (void) reloadWithFile:(NSString*)file {
	if (file) {
		NSMutableArray *remoteTasks = [TaskIo loadTasksFromFile:file];
		[localTaskRepository store:remoteTasks];
		[self reload];
	}
}

- (void) addAsTask:(NSString*)input {
    [self reload];
    
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDate *date = nil;
	if ([defaults boolForKey:@"date_new_tasks_preference"]) {
		date = [NSDate date];
	}
	
    Task *task = [[Task alloc] initWithId:[tasks count] 
							  withRawText:input 
				 withDefaultPrependedDate:date];
    [tasks addObject:task];
	[task release];
    [localTaskRepository store:tasks];
}


- (Task*) update:(Task*)task {
    [self reload];
    Task *found = find(tasks, task);
    if (found) {
        [task copyInto:found];
        [localTaskRepository store:tasks];
		return found;
    }
	return nil;
}


- (void) remove:(Task*)task {
    [self reload];
    Task *found = find(tasks, task);
    if (found) {
        [tasks removeObject:found];
        [localTaskRepository store:tasks];
    }    
}

- (Task*) taskAtIndex:(NSUInteger)index {
	if (index >= [tasks count]) {
		return nil;
	}
	return [tasks objectAtIndex:index];
}

- (NSUInteger) indexOfTask:(Task*)task {
	for (int i = 0; i < [tasks count]; i++) {
		if ([tasks objectAtIndex:i] == task) {
			return i;
		}
	}
	return 0;
}

- (NSArray*) tasks {
    return [self tasksWithFilter:nil withSortOrder:nil];
}

- (NSArray*) tasksWithFilter:(NSObject*)filterSpec withSortOrder:(Sort*)sortOrder {
	NSMutableArray *localTasks = [NSMutableArray arrayWithCapacity:[tasks count]];
	// TODO: implement filtering
	// FIXME: right now we just assume that filterSpec is a string
	// and we will return only those tasks that contain that string.
	// Proper filtering still to come
	if (filterSpec != nil) {
		NSString *searchTerm = (NSString*)filterSpec; 
		for (Task* task in tasks) {
			if ([task.text rangeOfString:searchTerm options:NSCaseInsensitiveSearch].location != NSNotFound) {
				[localTasks addObject:task];
			}
		}
	} else {	
		[localTasks setArray:tasks];
	}
	
	if (sortOrder) {
		[localTasks sortUsingSelector:[sortOrder comparator]];
	}
    return localTasks;
}

- (int) size {
    return [tasks count];
}


- (NSArray*) projects {
	NSMutableSet *set = [NSMutableSet setWithCapacity:32];
	for (Task* task in tasks) {
		[set addObjectsFromArray:[task projects]];
	}
    return [[set allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}


- (NSArray*) contexts {
	NSMutableSet *set = [NSMutableSet setWithCapacity:32];
	for (Task* task in tasks) {
		[set addObjectsFromArray:[task contexts]];
	}
    return [[set allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}


- (NSArray*) priorities {
    return [Priority all];
}

- (void) dealloc {
    [localTaskRepository release];
    [tasks release];
    [super dealloc];
}

@end

