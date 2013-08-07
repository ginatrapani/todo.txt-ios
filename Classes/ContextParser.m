/**
 * This file is part of Todo.txt, an iOS app for managing your todo.txt file.
 *
 * @author Todo.txt contributors <todotxt@yahoogroups.com>
 * @copyright 2011-2012 Todo.txt contributors (http://todotxt.com)
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

#import "ContextParser.h"

static NSRegularExpression* contextPattern = nil;

@implementation ContextParser
+ (void)initialize {
	contextPattern = [[NSRegularExpression alloc] 
                      initWithPattern:@"(?:^|\\s)@(\\S*\\w)"
                      options:0
                      error:nil];
}

+ (NSRegularExpression*)textPattern { return contextPattern; }

+ (NSArray*) parse:(NSString*)inputText {
	if (!inputText) {
		return [NSArray array];
	}
	
	NSArray *contextMatches = 
				 [contextPattern matchesInString:inputText
					options:0
					range:NSMakeRange(0, [inputText length])];
	
	NSMutableArray* contexts = [NSMutableArray arrayWithCapacity:[contextMatches count]];
	for (NSTextCheckingResult *match in contextMatches) {
		[contexts addObject:[inputText substringWithRange:[match rangeAtIndex:1]]];
	}	
	
	return contexts;
}

+ (NSArray *)rangesOfContextsForString:(NSString *)string
{
	if (!string) {
		return @[ ];
	}
	
	NSArray *contextMatches =
	[contextPattern matchesInString:string
							options:0
							  range:NSMakeRange(0, string.length)];
    
    NSMutableArray *ranges = [NSMutableArray array];
    [contextMatches enumerateObjectsUsingBlock:^(NSTextCheckingResult *result, NSUInteger idx, BOOL *stop) {
        if (result.range.location != NSNotFound) {
            [ranges addObject:[NSValue valueWithRange:[result range]]];
        }
    }];
    
    return ranges;
}

@end
