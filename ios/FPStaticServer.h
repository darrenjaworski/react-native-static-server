#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>

// GCDWebServer: https://github.com/swisspol/GCDWebServer
#import "GCDWebServer.h"
#import "GCDWebServerFunctions.h"
#import "GCDWebServerFileResponse.h"
#import "GCDWebServerHTTPStatusCodes.h"

#ifdef RCT_NEW_ARCH_ENABLED
  #import <NativeStaticServerSpec/NativeStaticServerSpec.h>
  @interface NativeStaticServer() <NativeStaticServerSpec> {
    GCDWebServer* _webServer;
  }
    @property(nonatomic, retain) NSString *localPath;
    @property(nonatomic, retain) NSString *url;

    @property (nonatomic, retain) NSString* www_root;
    @property (nonatomic, retain) NSNumber* port;
    @property (assign) BOOL localhost_only;
    @property (assign) BOOL keep_alive;
  @end
#else
  @interface RNStaticServer : NSObject <RCTBridgeModule> {
    GCDWebServer* _webServer;
  }
    @property(nonatomic, retain) NSString *localPath;
    @property(nonatomic, retain) NSString *url;

    @property (nonatomic, retain) NSString* www_root;
    @property (nonatomic, retain) NSNumber* port;
    @property (assign) BOOL localhost_only;
    @property (assign) BOOL keep_alive;
  @end
#endif
