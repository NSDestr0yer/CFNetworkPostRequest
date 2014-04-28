//
//  AppDelegate.m
//  PostRequest
//
//  Created by Collin B Stuart on 2014-04-28.
//  Copyright (c) 2014 CollinBStuart. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

void LogData(CFDataRef responseData)
{
    CFIndex dataLength = CFDataGetLength(responseData);
    UInt8 *bytes = (UInt8 *)malloc(dataLength);
    CFDataGetBytes(responseData, CFRangeMake(0, CFDataGetLength(responseData)), bytes);
    CFStringRef responseString = CFStringCreateWithBytes(kCFAllocatorDefault, bytes, dataLength, kCFStringEncodingUTF8, TRUE);
    CFShow(responseString);
    CFRelease(responseString);
    free(bytes);
}

static void ReadStreamCallBack(CFReadStreamRef readStream, CFStreamEventType type, void *clientCallBackInfo)
{
    CFDataRef passedInData = (CFDataRef)(clientCallBackInfo);
    CFShow(CFSTR("Passed In Data:"));
    LogData(passedInData);
    
    //append data as we receive it
    CFMutableDataRef responseBytes = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CFIndex numberOfBytesRead = 0;
    do
    {
        UInt8 buf[1024];
        numberOfBytesRead = CFReadStreamRead(readStream, buf, sizeof(buf));
        if (numberOfBytesRead > 0)
        {
            CFDataAppendBytes(responseBytes, buf, numberOfBytesRead);
        }
    } while (numberOfBytesRead > 0);
    
    //once all data is appended, package it all together - create a response from the response headers, and add the data received.
    //note: just having the data received is not enough, you need to finish the response by retrieving the response headers here...
    CFHTTPMessageRef response = (CFHTTPMessageRef)CFReadStreamCopyProperty(readStream, kCFStreamPropertyHTTPResponseHeader);
    
    if (responseBytes)
    {
        if (response)
        {
            CFHTTPMessageSetBody(response, responseBytes);
        }
        CFRelease(responseBytes);
    }
    
    
    //close and cleanup
    CFReadStreamClose(readStream);
    CFReadStreamUnscheduleFromRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFRelease(readStream);
    
    //just keep the response body and release requests
    CFDataRef responseBodyData = CFHTTPMessageCopyBody(response);
    if (response)
    {
        CFRelease(response);
    }
    
    //get the response as a string
    if (responseBodyData)
    {
        CFShow(CFSTR("\nResponse Data:"));
        LogData(responseBodyData);
        CFRelease(responseBodyData);
    }
}

void *RetainSocketStreamHandle(void *info)
{
    CFRetain(info);
    return info;
}

void ReleaseSocketStreamHandle(void *info)
{
    if (info)
    {
        CFRelease(info);
    }
}

void PostRequest()
{
    // Create the POST request payload.
    CFStringRef payloadString = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("{\"test-data-key\" : \"test-data-value\"}"));
    CFDataRef payloadData = CFStringCreateExternalRepresentation(kCFAllocatorDefault, payloadString, kCFStringEncodingUTF8, 0);
    CFRelease(payloadString);
    
    //create request
    CFURLRef theURL = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("http://httpbin.org/post"), NULL); //http://httpbin.org/post returns post data
    CFHTTPMessageRef request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, CFSTR("POST"), theURL, kCFHTTPVersion1_1);
    CFHTTPMessageSetBody(request, payloadData);
    
    //add some headers
    CFStringRef hostString = CFURLCopyHostName(theURL);
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("HOST"), hostString);
    CFRelease(hostString);
    CFRelease(theURL);
    
    if (payloadData)
    {
        CFStringRef lengthString = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%ld"), CFDataGetLength(payloadData));
        CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Content-Length"), lengthString);
        CFRelease(lengthString);
    }
    
    
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Content-Type"), CFSTR("charset=utf-8"));
    
    //create read stream for response
    CFReadStreamRef requestStream = CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, request);
    CFRelease(request);
    
    //set up on separate runloop (with own thread) to avoid blocking the UI
    CFReadStreamScheduleWithRunLoop(requestStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFOptionFlags optionFlags = (kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered);
    CFStreamClientContext clientContext = {0, (void *)payloadData, RetainSocketStreamHandle, ReleaseSocketStreamHandle, NULL};
    CFReadStreamSetClient(requestStream, optionFlags, ReadStreamCallBack, &clientContext);
    
    //start request
    CFReadStreamOpen(requestStream);
    
    if (payloadData)
    {
        CFRelease(payloadData);
    }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    PostRequest();
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
