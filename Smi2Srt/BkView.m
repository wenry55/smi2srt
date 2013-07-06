//
//  BkView.m
//  Smi2Srt
//
//  Created by Seo Bongkyo on 13. 7. 4..
//  Copyright (c) 2013년 B&J Studio. All rights reserved.
//

#import "BkView.h"

@implementation BkView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		[self registerForDraggedTypes:[NSArray arrayWithObjects:NSColorPboardType, NSFilenamesPboardType, nil]];
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
	return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
	NSPasteboard *pboard = [sender draggingPasteboard];
	if ([[pboard types] containsObject:NSURLPboardType]) {
		NSURL *fileURL = [NSURL URLFromPasteboard:pboard];
		[self convertSmi:fileURL];
	}
	return YES;
}
- (void)convertSmi:(NSURL *)fileURL {
	if (![[fileURL pathExtension] isEqualToString:@"smi"]) return;
	NSError *error;
	NSStringEncoding encoding;
	NSString *smiStr = [NSString stringWithContentsOfURL:fileURL usedEncoding:&encoding error:&error];
	if (smiStr == nil) {
		smiStr = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
		if (smiStr == nil) {
			smiStr = [NSString stringWithContentsOfURL:fileURL encoding:0x80000422 error:&error];
		}
	}
	
	NSString *pattern = @"<SYNC Start=(.+?)><P Class=.+?>((.|\r\n)*?)(?=(<SYNC|</BODY))";
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
																		   options:NSRegularExpressionCaseInsensitive
																			 error:nil];
	
	NSArray *matchRes = [regex matchesInString:smiStr options:0 range:NSMakeRange(0, [smiStr length])];
	
	NSArray *prevScript;
	int seq = 0;
	NSMutableString *srtStr = [NSMutableString new];
	
	for (NSTextCheckingResult *result in matchRes) {
		
		NSString *scriptStr = [smiStr substringWithRange:[result rangeAtIndex:2]];
		scriptStr = [scriptStr stringByReplacingOccurrencesOfString:@"&nbsp;" withString:[NSString string]];
		scriptStr = [scriptStr stringByReplacingOccurrencesOfString:@"&#8211" withString:@"-"];
		scriptStr = [scriptStr stringByReplacingOccurrencesOfString:@"<br>\r\n" withString:@"\r\n"];
		scriptStr = [scriptStr stringByReplacingOccurrencesOfString:@"<br>" withString:@"\r\n"];
		NSArray *comps = [scriptStr componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
		NSMutableArray *componentsToKeep = [NSMutableArray array];
		for (int i = 0; i < [comps count]; i = i + 2) {
			[componentsToKeep addObject:[comps objectAtIndex:i]];
		}
		scriptStr = [componentsToKeep componentsJoinedByString:@""];
		scriptStr = [scriptStr stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n"]];
		
		if ([scriptStr isEqualToString:@""]) continue;
		
		NSString *timeStr = [smiStr substringWithRange:[result rangeAtIndex:1]];
		
		if (prevScript != nil) {
			[srtStr appendString:[NSString stringWithFormat:@"%d\r\n", seq]];
			int prevTime = [[prevScript objectAtIndex:0] intValue];
			if (([timeStr intValue] - prevTime) > 5000 ) {
				[srtStr appendString:[NSString stringWithFormat:@"%@ --> %@\r\n", [self getSrtTime:[prevScript objectAtIndex:0]], [self getSrtTimeWithInt:prevTime + 5000]]];
			} else {
				[srtStr appendString:[NSString stringWithFormat:@"%@ --> %@\r\n", [self getSrtTime:[prevScript objectAtIndex:0]], [self getSrtTimeWithInt:[timeStr intValue] - 10]]];
			}
			[srtStr appendString:[NSString stringWithFormat:@"%@\r\n\r\n", [prevScript objectAtIndex:1]]];
		}
		
		
		
		seq++;
		prevScript = @[timeStr, scriptStr];
	}
	
	[srtStr appendString:[NSString stringWithFormat:@"%d\r\n", seq]];
	[srtStr appendString:[NSString stringWithFormat:@"%@ --> %@\r\n",
						  [self getSrtTime:[prevScript objectAtIndex:0]], [self getSrtTime:[prevScript objectAtIndex:0]]]];
	[srtStr appendString:[NSString stringWithFormat:@"%@\r\n\r\n", [prevScript objectAtIndex:1]]];
	
	NSURL *srtUrl = [[fileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"srt"];
	[srtStr writeToURL:srtUrl atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)getSrtTime:(NSString *)smiTimeStr {
	return [self getSrtTimeWithInt:[smiTimeStr intValue]];
}

- (NSString *)getSrtTimeWithInt:(int)smiTime {
	int hours = (int)(smiTime / (1000 * 60 * 60));
	int mins = (int)(smiTime / (1000 * 60)) % 60;
	int secs = (int)((smiTime / 1000) % 60);
	int milisecs = (int)(smiTime % 1000);
	return [NSString stringWithFormat:@"%02d:%02d:%02d,%03d", hours, mins, secs, milisecs];
}

@end
