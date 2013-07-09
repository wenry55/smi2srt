//
//  BkView2.m
//  Smi2Srt
//
//  Created by Seo Bongkyo on 13. 7. 9..
//  Copyright (c) 2013년 B&J Studio. All rights reserved.
//

#import "BkView2.h"

@implementation BkView2


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
		[self convertSrt:fileURL];
	}
	return YES;
}
- (void)convertSrt:(NSURL *)fileURL {
	if (![[fileURL pathExtension] isEqualToString:@"srt"]) return;
	NSError *error;
	NSStringEncoding encoding;
	NSString *srtStr = [NSString stringWithContentsOfURL:fileURL usedEncoding:&encoding error:&error];
	if (srtStr == nil) {
		srtStr = [NSString stringWithContentsOfURL:fileURL encoding:NSUTF8StringEncoding error:&error];
		if (srtStr == nil) {
			srtStr = [NSString stringWithContentsOfURL:fileURL encoding:0x80000422 error:&error];
		}
	}
	

	NSString *pattern = @"[0-9]+?\r\n(\\d{2}):(\\d{2}):(\\d{2})[,.](\\d{3}) --> (\\d{2}):(\\d{2}):(\\d{2})[,.](\\d{3})\r\n((.|\r\n)*?)\r\n\r\n";
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
																		   options:NSRegularExpressionCaseInsensitive
																			 error:nil];
	
	NSArray *matchRes = [regex matchesInString:srtStr options:0 range:NSMakeRange(0, [srtStr length])];
	
	NSMutableString *resultStr = [NSMutableString new];
	[resultStr appendString:@"\
	 <SAMI>\
	 <HEAD>\
	 <TITLE></TITLE>\
	 <STYLE TYPE=\"text/css\">\
	 <!--\
	 P { margin-left:2pt; margin-right:2pt; margin-bottom:1pt;\
		 margin-top:1pt; font-size:20pt; text-align:center;\
		 font-family:Arial, Sans-serif; font-weight:bold; color:white;\
	 }\
	 .KRCC { Name:한국어; lang:ko-KR; SAMIType:CC; }\
	 -->\
	 </STYLE>\
	 </HEAD>\
	 <BODY>"];

	for (NSTextCheckingResult *item in matchRes) {
		// 1:2:3:4 --> 5:6:7:8 9(str)
		int fromOffset =
		[[srtStr substringWithRange:[item rangeAtIndex:1]] intValue] * 60 * 60 * 1000 +
		[[srtStr substringWithRange:[item rangeAtIndex:2]] intValue] * 60 * 1000 +
		[[srtStr substringWithRange:[item rangeAtIndex:3]] intValue] * 1000 +
		[[srtStr substringWithRange:[item rangeAtIndex:4]] intValue];
		
		int toOffset =
		[[srtStr substringWithRange:[item rangeAtIndex:5]] intValue] * 60 * 60 * 1000 +
		[[srtStr substringWithRange:[item rangeAtIndex:6]] intValue] * 60 * 1000 +
		[[srtStr substringWithRange:[item rangeAtIndex:7]] intValue] * 1000 +
		[[srtStr substringWithRange:[item rangeAtIndex:8]] intValue];
		
		NSString *scriptStr = [srtStr substringWithRange:[item rangeAtIndex:9]];
		
		scriptStr = [scriptStr stringByReplacingOccurrencesOfString:@"-" withString:@"&#8211"];
		scriptStr = [scriptStr stringByReplacingOccurrencesOfString:@"\r\n" withString:@"<br>"];
		
		NSString *convStr = [NSString stringWithFormat:@"<SYNC Start=%d><P Class=KRCC>%@\r\n<SYNC Start=%d><P Class=KRCC>&nbsp;\r\n",
							 fromOffset, scriptStr, toOffset];
		
		NSLog(@"%@", convStr);
		[resultStr appendFormat:@"%@\r\n", convStr];
	}
	
	[resultStr appendString:@"</BODY></SAMI>"];
	
	NSURL *smiUrl = [[fileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"smi"];
	[resultStr writeToURL:smiUrl atomically:YES encoding:NSUTF8StringEncoding error:nil];
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
