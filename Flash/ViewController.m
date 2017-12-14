//
//  ViewController.m
//  WMLinkMapAnalyzer
//
//  Created by Mac on 16/1/5.
//  Copyright © 2016年 wmeng. All rights reserved.
//

#import "ViewController.h"
#import "symbolModel.h"

static BOOL stastic_0 = NO;
static BOOL stastic_1 = NO;
static BOOL stastic_2 = NO;
static BOOL stastic_3 = NO;
static BOOL stastic_4 = NO;

@interface ViewController()

@property (weak) IBOutlet NSScrollView *contentView;//分析的内容
@property (unsafe_unretained) IBOutlet NSTextView *contentTextView;

@property (nonatomic,strong)NSURL *ChooseLinkMapFileURL;
@property (nonatomic,strong)NSString *linkMapContent;

@property (nonatomic,strong)NSURL *appFileURL;
@property (nonatomic,strong)NSURL *ignoreFileURL;
@property (nonatomic,strong)NSURL *whitelistFileURL;

@property (nonatomic) NSMutableDictionary *allFuncs;
@property (nonatomic) NSMutableDictionary *allIvars;
@property (nonatomic) NSMutableDictionary *data;
@property (nonatomic) NSMutableDictionary *unuseds;
@property (nonatomic) NSString *result;
@property (nonatomic) NSDictionary *ignores;
@property (nonatomic) NSArray *whitelist;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}
- (IBAction)option_0:(NSButton *)sender {
    stastic_0 = sender.state == NSControlStateValueOn;
}
- (IBAction)option_1:(NSButton *)sender {
    stastic_1 = sender.state == NSControlStateValueOn;
}
- (IBAction)option_2:(NSButton *)sender {
    stastic_2 = sender.state == NSControlStateValueOn;
}
- (IBAction)option_3:(NSButton *)sender {
    stastic_4 = sender.state == NSControlStateValueOn;
}
- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}

- (IBAction)ChooseFile:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setResolvesAliases:NO];
    [panel setCanChooseFiles:NO];
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[panel URLs] objectAtIndex:0];
            NSString *linkMap = [[theDoc path] stringByAppendingPathComponent:@"LinkMap.txt"];
            self.ChooseLinkMapFileURL = [NSURL fileURLWithPath:linkMap];
            
            NSString *ignore = [[theDoc path] stringByAppendingPathComponent:@"ignores.plist"];
            self.ignoreFileURL = [NSURL fileURLWithPath:ignore];
            
            NSString *whitelist = [[theDoc path] stringByAppendingPathComponent:@"whitelist.plist"];
            self.whitelistFileURL = [NSURL fileURLWithPath:whitelist];
            
            self.appFileURL = nil;

            if (!_ChooseLinkMapFileURL|| ![[NSFileManager defaultManager] fileExistsAtPath:[_ChooseLinkMapFileURL path] isDirectory:nil]){
            }
            if (!_ignoreFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:[_ignoreFileURL path] isDirectory:nil]){
            }
   
        }
    }];
}

- (IBAction)ChooseAppFile:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setResolvesAliases:NO];
    [panel setCanChooseFiles:YES];
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[panel URLs] objectAtIndex:0];
            self.appFileURL = theDoc;
        }
    }];
}

- (IBAction)ChooseIgnoreFile:(id)sender {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    [panel setResolvesAliases:NO];
    [panel setCanChooseFiles:YES];
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[panel URLs] objectAtIndex:0];
            NSLog(@"%@", theDoc);
            self.ignoreFileURL = theDoc;
        }
    }];
}

- (void)analyStep1 {
    if (!_ChooseLinkMapFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:[_ChooseLinkMapFileURL path] isDirectory:nil])
    {
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"没有找到 LinkMap.txt";
        [alert addButtonWithTitle:@"是的"];
        [alert beginSheetModalForWindow:[NSApplication sharedApplication].windows[0] completionHandler:^(NSModalResponse returnCode) {
            
        }];
        return;
    }
    
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfURL:_ChooseLinkMapFileURL encoding:NSMacOSRomanStringEncoding error:&error];
    NSRange objsFileTagRange = [content rangeOfString:@"# Object files:"];
    NSString *subObjsFileSymbolStr = [content substringFromIndex:objsFileTagRange.location + objsFileTagRange.length];
    NSRange symbolsRange = [subObjsFileSymbolStr rangeOfString:@"# Symbols:"];
    if ([content rangeOfString:@"# Path:"].length <= 0||objsFileTagRange.location == NSNotFound||symbolsRange.location == NSNotFound)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc]init];
            alert.messageText = @"文件格式不正确";
            [alert addButtonWithTitle:@"是的"];
            [alert beginSheetModalForWindow:[NSApplication sharedApplication].windows[0] completionHandler:^(NSModalResponse returnCode) {
                
            }];
            
        });
        return;
    }
    
    NSMutableDictionary <NSString *,symbolModel *>*sizeMap = [NSMutableDictionary new];
    // 符号文件列表
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    BOOL reachFiles = NO;
    BOOL reachSymbols = NO;
    BOOL reachSections = NO;
    
    for(NSString *line in lines)
    {
        if([line hasPrefix:@"#"])   //注释行
        {
            if ([line hasPrefix:@"# Path:"]) {
                NSString *appPath = [line substringFromIndex:8];
                _appFileURL = [NSURL URLWithString:appPath];
             } else if([line hasPrefix:@"# Object files:"])
                reachFiles = YES;
            else if ([line hasPrefix:@"# Sections:"])
                reachSections = YES;
            else if ([line hasPrefix:@"# Symbols:"])
                reachSymbols = YES;
            else if ([line hasPrefix:@"# Dead Stripped Symbols:"]) {
                reachFiles = NO;
                reachSections = NO;
                reachSymbols = NO;
            }
        }
        else
        {
            if(reachFiles == YES && reachSections == NO && reachSymbols == NO)
            {
                NSRange range = [line rangeOfString:@"]"];
                if(range.location != NSNotFound)
                {
                    if ([[line pathExtension] isEqualToString:@"o"] || ([[line lastPathComponent] rangeOfString:@".a("].location != NSNotFound && [[line lastPathComponent] rangeOfString:@"dummy.o)"].location == NSNotFound)) {
                        symbolModel *symbol = [symbolModel new];
                        symbol.file = [self safeSubString:line from:range.location+1];
                        NSString *key = [self safeSubString:line to:range.location+1];
                        sizeMap[key] = symbol;
                    }
                }
            }
            else if (reachFiles == YES &&reachSections == YES && reachSymbols == NO)
            {
            }
            else if (reachFiles == YES && reachSections == YES && reachSymbols == YES)
            {
                NSArray <NSString *>*symbolsArray = [line componentsSeparatedByString:@"\t"];
                if(symbolsArray.count == 3)
                {
                    //Address Size File Name
                    NSString *fileKeyAndName = symbolsArray[2];
                    NSUInteger size = strtoul([symbolsArray[1] UTF8String], nil, 16);
                    
                    NSRange range = [fileKeyAndName rangeOfString:@"]"];
                    if(range.location != NSNotFound)
                    {
                        NSString *key = [self safeSubString:fileKeyAndName to:range.location+1];
                        symbolModel *symbol = sizeMap[key];
                        if(symbol)
                        {
                            symbol.size += size;
                        }
                        if ([fileKeyAndName rangeOfString:@"literal string"].location == NSNotFound) {
                            //ivar
                            range = [fileKeyAndName rangeOfString:@"_OBJC_IVAR_$_"];
                            if(range.location != NSNotFound) {
                                NSString *classIvar = [fileKeyAndName substringFromIndex:NSMaxRange(range)];
                                range = [classIvar rangeOfString:@"."];
                                NSString *classN = [classIvar substringToIndex:range.location];
                                if (![self filterClass:classN]) {
                                    NSMutableArray *arr = _allIvars[classN];
                                    if (!arr) {
                                        arr = [NSMutableArray array];
                                        _allIvars[classN] = arr;
                                    }
                                    
                                    NSString *ivar = [classIvar substringFromIndex:NSMaxRange(range)];
                                    [arr addObject:ivar];
                                }
                            } else {
                                
                                range = [fileKeyAndName rangeOfString:@"]"];
                                NSString *method = [self safeSubString:fileKeyAndName from:range.location+2];
                                range = [method rangeOfString:@"-["];
                                if (range.location == NSNotFound) {
                                    range = [method rangeOfString:@"+["];
                                }
                                if (range.location != NSNotFound) {
                                    method = [self safeSubString:method from:NSMaxRange(range)];
                                    range = [method rangeOfString:@" "];
                                    NSString *classN = [self safeSubString:method to:range.location];
                                    if (![self filterClass:classN]) {
                                        //func
                                        NSMutableArray *arr = _allFuncs[classN];
                                        if (!arr) {
                                            arr = [NSMutableArray array];
                                            _allFuncs[classN] = arr;
                                        }
                                        range = [method rangeOfString:@"_block_invoke"];
                                        if (range.location == NSNotFound) {
                                            range = [method rangeOfString:@"]"];
                                            method = [self safeSubString:method to:range.location];
                                            range = [method rangeOfString:classN];
                                            method = [self safeSubString:method from:NSMaxRange(range) + 1];
                                            if (![self filterMethod:method]) {
                                                [arr addObject:method];
                                            }
                                        }
                                        
                                    }
                                }
                            }
                            
                        }
                        
                    }
                }
            }
        }
        
    }
    
    NSArray <symbolModel *>*symbols = [sizeMap allValues];

    NSUInteger totalSize = 0;
    NSMutableDictionary *fi = [NSMutableDictionary dictionary];
    for(symbolModel *symbol in symbols)
    {
        NSString *key = [[symbol.file componentsSeparatedByString:@"/"] lastObject];
        NSRange range = [key rangeOfString:@".a("];
        if (range.location != NSNotFound) {
            key = [self safeSubString:key to:NSMaxRange(range) - 1];
        } else {
            key = @"nativeCodeSize";
        }
        NSNumber *size = fi[key];
        if (size) {
            NSUInteger temp = [size unsignedIntegerValue];
            temp += symbol.size;
            fi[key] = @(temp);
        } else {
            fi[key] = @(symbol.size);
        }
    }
    
    NSMutableArray *formatFi = [NSMutableArray array];
    NSString *myCode = nil;
    for(NSString *file in fi.allKeys)
    {
        NSString *value = [NSString stringWithFormat:@"%@ : %.3fKB(%.2fM)" ,file,([fi[file]unsignedIntegerValue]/1024.0), ([fi[file]unsignedIntegerValue]/1024.0/1024.0)];
        if ([file isEqualToString:@"nativeCodeSize"]) {
            myCode = value;
        } else {
            [formatFi addObject:value];
        }
        totalSize += [fi[file]unsignedIntegerValue];
    }
    if (myCode) {
        [formatFi addObject:myCode];
    }
    if(stastic_0) {
        self.data[@"大小统计"] = formatFi;
        
        self.data[@"total"] = [NSString stringWithFormat:@"%.2fM",(totalSize/1024.0/1024.0)];
    }
    for (NSString *key in _allFuncs.allKeys) {
        if ([_allFuncs[key]count] == 0) {
            [_allFuncs removeObjectForKey:key];
        }
    }
    if(stastic_1) {
        self.data[@"所有方法"] = _allFuncs;
    }
    if (stastic_4) {
        for (NSString *key in _allFuncs.allKeys) {
            NSMutableArray *arr = _allFuncs[key];
            NSArray *ivars = _allIvars[key];
            for (NSString *ivar in ivars) {
                NSString *getIvar = [ivar substringFromIndex:1];
                NSString *temp = [NSString stringWithFormat:@"%@%@",[[getIvar substringToIndex:1]uppercaseString],[getIvar substringFromIndex:1]];
                NSString *setIvar = [NSString stringWithFormat:@"set%@:",temp];
                [arr removeObject:getIvar];
                [arr removeObject:setIvar];
            }
        }
    }
    
}

- (IBAction)StartAnalyzer:(id)sender {
    self.contentTextView.string = @"正在分析，可能需要等一等~~";
    stastic_3 = YES;
    self.data = [NSMutableDictionary dictionary];
    self.allFuncs = [NSMutableDictionary dictionary];
    self.allIvars = [NSMutableDictionary dictionary];
    self.unuseds = [NSMutableDictionary dictionary];
    [self loadIgnores];
    [self loadWitelist];
    [self analyStep1];
    [self analyStep2];
    NSData *data = [self toJSONData:self.data];
    self.result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    self.contentTextView.string = _result;
}

- (IBAction)inputFile:(id)sender {
    
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:YES];
    [panel setResolvesAliases:NO];
    [panel setCanChooseFiles:NO];
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSURL*  theDoc = [[panel URLs] objectAtIndex:0];
            NSMutableString *target =[[NSMutableString alloc]initWithCapacity:0];
            [target appendString:[theDoc path]];
            NSString *flag = [NSString stringWithFormat:@"/the Flash_%zd.txt",(NSInteger)[[NSDate date] timeIntervalSince1970]];
            [target appendString:flag];
            NSData *data = [self toJSONData:self.data];
            [data writeToFile:target atomically:YES];
        }
    }];
}

- (BOOL)filterClass:(NSString *)name {
    if (!name) {
        return NO;
    }
    if(self.whitelist.count) {
        if([self commonFilter:self.whitelist name:name]) {
            return NO;
        }
        return YES;
    }
    NSArray *ignoreClass = self.ignores[@"class"];
    return [self commonFilter:ignoreClass name:name];
}

- (BOOL)commonFilter:(NSArray *)ignoreClass name:(NSString *)name {
    BOOL ret = NO;
    for (NSString *str in ignoreClass) {
        if ([str hasSuffix:@"*"]) {
            NSString *pattern = [str substringToIndex:str.length-1];
            if (![name isEqualToString:pattern]&&[name hasPrefix:pattern]) {
                ret = YES;
                break;
            }
        } else if ([str hasPrefix:@"*"]) {
            NSString *pattern = [str substringFromIndex:1];
            if (![name isEqualToString:pattern]&&[name hasSuffix:pattern]) {
                ret = YES;
                break;
            }
        }
        else {
            if([str isEqualToString:name]) {
                ret = YES;
                break;
            }
        }
    }
    return ret;
}

- (BOOL)filterMethod:(NSString *)name {
    if (!name) {
        return NO;
    }
    NSArray *ignoreClass = self.ignores[@"method"];
    return [self commonFilter:ignoreClass name:name];
}

- (void)loadIgnores {
    self.ignores = [NSDictionary dictionaryWithContentsOfURL:self.ignoreFileURL];
}

- (void)loadWitelist {
    self.whitelist = [NSArray arrayWithContentsOfURL:self.whitelistFileURL];
}

- (NSString *)safeSubString:(NSString *)line from:(NSInteger)index {
    if (index >= line.length) {
        NSLog(@"error line >>>>>%@", line);
    }
    return [line substringFromIndex:index];
}

- (NSString *)safeSubString:(NSString *)line to:(NSInteger)index {
    if (index >= line.length) {
        NSLog(@"error line >>>>>%@", line);
    }
    return [line substringToIndex:index];
}

- (void)analyStep2 {
    if (!_appFileURL || ![[NSFileManager defaultManager] fileExistsAtPath:[_appFileURL path] isDirectory:nil])
    {
        NSAlert *alert = [[NSAlert alloc]init];
        alert.messageText = @"没有找到 *.app";
        [alert addButtonWithTitle:@"是的"];
        [alert beginSheetModalForWindow:[NSApplication sharedApplication].windows[0] completionHandler:^(NSModalResponse returnCode) {
            
        }];
        return;
    }
    NSString *path = [self.appFileURL path];
    
    NSArray* theArguments = [NSArray arrayWithObjects: @"/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/otool", @"-V", @"-s", @"__DATA", @"__objc_selrefs" ,path,nil];
    NSString *content = [self shell:theArguments];
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    NSMutableArray *usedMethods = [NSMutableArray array];
    for (NSString *line in lines) {
        NSRange range = [line rangeOfString:@"__objc_methname:"];
        if (range.location != NSNotFound) {
            NSString *method = [self safeSubString:line from:NSMaxRange(range)];
            [usedMethods addObject:method];
        }
    }
    if(stastic_2) {
        self.data[@"使用的方法"] = usedMethods;
    }
    NSMutableDictionary *unuseds = [NSMutableDictionary dictionary];
    NSMutableDictionary *tempAll = [NSMutableDictionary dictionaryWithDictionary:_allFuncs];
    for (NSString *key in tempAll.allKeys) {
        NSArray *arr = tempAll[key];
        for (NSString *method in arr) {
            BOOL use = NO;
            for (NSString *method1 in usedMethods) {
                if ([method isEqualToString:method1]) {
                    use = YES;
                    break;
                }
            }
            if (!use) {
                NSMutableArray *arr = unuseds[key];
                if (!arr) {
                    arr = [NSMutableArray array];
                    unuseds[key] = arr;
                }
                [arr addObject:method];
            }
        }
    }
    self.unuseds = unuseds;
    if(stastic_3) {
        self.data[@"可能未使用的方法"] = unuseds;
    }
}

- (NSData *)toJSONData:(id)theData
{
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:theData options:NSJSONWritingPrettyPrinted error:nil];
    
    if ([jsonData length]&&error== nil){
        return jsonData;
    }else{
        return nil;
    }
}

- (NSString *)shell:(NSArray *)theArguments {
    NSTask* scriptTask = [[NSTask alloc] init];
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [scriptTask setStandardOutput: pipe];
    [scriptTask setStandardError: pipe];
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    [scriptTask setLaunchPath: [theArguments objectAtIndex:0]];
    [scriptTask setArguments: [theArguments subarrayWithRange: NSMakeRange (1,([theArguments count] - 1))]];
    [scriptTask launch];
    NSData *data;
    data = [file readDataToEndOfFile];
    NSString *string;
    string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    return string;
}

- (void)removeGetAndSet {
    
}

@end
