#import "FPStaticServer.h"

@implementation RNStaticServer

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE(StaticServer);

- (instancetype)init {
    if((self = [super init])) {

        [GCDWebServer self];
        _webServer = [[GCDWebServer alloc] init];
    }
    return self;
}

- (void)dealloc {

    if(_webServer.isRunning == YES) {
        [_webServer stop];
    }
    _webServer = nil;

}

- (dispatch_queue_t)methodQueue
{
    return dispatch_queue_create("com.futurepress.staticserver", DISPATCH_QUEUE_SERIAL);
}


RCT_EXPORT_METHOD(start: (NSString *)port
                  root:(NSString *)optroot
                  localOnly:(BOOL *)localhost_only
                  keepAlive:(BOOL *)keep_alive
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    NSString * root;

    if( [optroot isEqualToString:@"DocumentDir"] ){
        root = [NSString stringWithFormat:@"%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0] ];
    } else if( [optroot isEqualToString:@"BundleDir"] ){
        root = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] bundlePath] ];
    } else if([optroot hasPrefix:@"/"]) {
        root = optroot;
    } else {
        root = [NSString stringWithFormat:@"%@/%@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0], optroot ];
    }

    if(root && [root length] > 0) {
        self.www_root = root;
    }

    if(port && [port length] > 0) {
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        f.numberStyle = NSNumberFormatterDecimalStyle;
        self.port = [f numberFromString:port];
    } else {
        self.port = [NSNumber numberWithInt:-1];
    }

    self.keep_alive = keep_alive;

    self.localhost_only = localhost_only;

    if(_webServer.isRunning != NO) {
        NSLog(@"StaticServer already running at %@", self.url);
        resolve(self.url);
        return;
    }

    //[_webServer addGETHandlerForBasePath:@"/" directoryPath:self.www_root indexFilename:@"index.html" cacheAge:3600 allowRangeRequests:YES];
    NSString *basePath = @"/";
    NSString *directoryPath = self.www_root;
    NSString *indexFilename = @"index.html";
    NSUInteger cacheAge = 0;
    BOOL allowRangeRequests = YES;
    [_webServer addHandlerWithMatchBlock:^GCDWebServerRequest*(NSString* requestMethod, NSURL* requestURL, NSDictionary<NSString*, NSString*>* requestHeaders, NSString* urlPath, NSDictionary<NSString*, NSString*>* urlQuery) {
        if (![requestMethod isEqualToString:@"GET"]) {
          return nil;
        }
        if (![urlPath hasPrefix:basePath]) {
          return nil;
        }
        return [[GCDWebServerRequest alloc] initWithMethod:requestMethod url:requestURL headers:requestHeaders path:urlPath query:urlQuery];
      }
      processBlock:^GCDWebServerResponse*(GCDWebServerRequest* request) {
        GCDWebServerResponse* response = nil;
        NSString* filePath = [directoryPath stringByAppendingPathComponent:GCDWebServerNormalizePath([request.path substringFromIndex:basePath.length])];
        NSString* fileType = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:NULL] fileType];
        if (fileType) {
          if ([fileType isEqualToString:NSFileTypeDirectory]) {
            if (indexFilename) {
              NSString* indexPath = [filePath stringByAppendingPathComponent:indexFilename];
              NSString* indexType = [[[NSFileManager defaultManager] attributesOfItemAtPath:indexPath error:NULL] fileType];
              if ([indexType isEqualToString:NSFileTypeRegular]) {
                response = [GCDWebServerFileResponse responseWithFile:indexPath];
              }
            } else {
              response = [GCDWebServerResponse responseWithStatusCode:kGCDWebServerHTTPStatusCode_NotFound];
            }
          } else if ([fileType isEqualToString:NSFileTypeRegular]) {
            if (allowRangeRequests) {
              response = [GCDWebServerFileResponse responseWithFile:filePath byteRange:request.byteRange];
              [response setValue:@"bytes" forAdditionalHeader:@"Accept-Ranges"];
            } else {
              response = [GCDWebServerFileResponse responseWithFile:filePath];
            }
          }
        }
        if (response) {
          response.cacheControlMaxAge = cacheAge;
          [response setValue:@"GET" forAdditionalHeader:@"Access-Control-Request-Method"];
          [response setValue:@"OriginX-Requested-With, Content-Type, Accept, Cache-Control, Range,Access-Control-Allow-Origin"  forAdditionalHeader:@"Access-Control-Request-Headers"];
          [response setValue: @"*" forAdditionalHeader:@"Access-Control-Allow-Origin"];
        } else {
          response = [GCDWebServerResponse responseWithStatusCode:kGCDWebServerHTTPStatusCode_NotFound];
        }
        return response;
      }];

    // Note: It must be __block variable to allow onStartFailure() block below
    // to access its current, rather than its initial value.
    __block NSError *error;

    /**
     * Rejects the start promise with details from "error" object, if that
     * exists, otherwise rejects with the fallback "StaticServer could not start"
     * message.
     *
     * BEWARE: Once this block is executed, you should ensure yourself
     * the parent function returns, or at least does not attempt to resolve or
     * reject the start promise again.
     */
    void (^onStartFailure)(NSString*) = ^(NSString *fallbackMessage){
        if (error) {
            NSString *errorDescription = [NSString stringWithFormat:@"%@ / %@",
                error.localizedDescription,
                error.localizedFailureReason];
            reject(error.domain, errorDescription, error);
        } else reject(@"server_error", fallbackMessage, nil);
    };

    NSMutableDictionary* options = [NSMutableDictionary dictionary];

    NSLog(@"Started StaticServer on port %@", self.port);

    if (![self.port isEqualToNumber:[NSNumber numberWithInt:-1]]) {
        [options setObject:self.port forKey:GCDWebServerOption_Port];
    } else {
        [options setObject:[NSNumber numberWithInteger:8080] forKey:GCDWebServerOption_Port];
    }

    if (self.localhost_only == YES) {
        [options setObject:@(YES) forKey:GCDWebServerOption_BindToLocalhost];
    }

    if (self.keep_alive == YES) {
        [options setObject:@(NO) forKey:GCDWebServerOption_AutomaticallySuspendInBackground];
        [options setObject:@2.0 forKey:GCDWebServerOption_ConnectedStateCoalescingInterval];
    }


    if([_webServer startWithOptions:options error:&error]) {
        NSNumber *listenPort = [NSNumber numberWithUnsignedInteger:_webServer.port];
        self.port = listenPort;

        if(_webServer.serverURL == NULL) {
            onStartFailure(@"StaticServer could not start (.serverURL is NULL)");
        } else {
            self.url = [NSString stringWithFormat: @"%@://%@:%@", [_webServer.serverURL scheme], [_webServer.serverURL host], [_webServer.serverURL port]];
            NSLog(@"Started StaticServer at URL %@", self.url);
            resolve(self.url);
        }
    } else {
        NSLog(@"Error starting StaticServer: %@", error);
        onStartFailure(@"StaticServer could not start (.start() returned NO)");
    }
}

RCT_EXPORT_METHOD(stop) {
    if(_webServer.isRunning == YES) {

        [_webServer stop];

        NSLog(@"StaticServer stopped");
    }
}

RCT_EXPORT_METHOD(origin:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    if(_webServer.isRunning == YES) {
        resolve(self.url);
    } else {
        resolve(@"");
    }
}

RCT_EXPORT_METHOD(isRunning:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
    bool isRunning = _webServer != nil &&_webServer.isRunning == YES;
    resolve(@(isRunning));
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeStaticServerSpecJSI>(params);
}
#endif

@end
