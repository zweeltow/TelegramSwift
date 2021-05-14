#ifndef OngoingCallContext_h
#define OngoingCallContext_h

#import <AppKit/AppKit.h>

@interface OngoingCallConnectionDescriptionWebrtc : NSObject

@property (nonatomic, readonly) int64_t connectionId;
@property (nonatomic, strong, readonly) NSString * _Nonnull ip;
@property (nonatomic, strong, readonly) NSString * _Nonnull ipv6;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSData * _Nonnull peerTag;

- (instancetype _Nonnull)initWithConnectionId:(int64_t)connectionId ip:(NSString * _Nonnull)ip ipv6:(NSString * _Nonnull)ipv6 port:(int32_t)port peerTag:(NSData * _Nonnull)peerTag;

@end

typedef NS_ENUM(int32_t, OngoingCallStateWebrtc) {
    OngoingCallStateInitializingWebrtc,
    OngoingCallStateConnectedWebrtc,
    OngoingCallStateFailedWebrtc,
    OngoingCallStateReconnectingWebrtc
};

typedef NS_ENUM(int32_t, OngoingCallVideoStateWebrtc) {
    OngoingCallVideoStatePossibleWebrtc,
    OngoingCallVideoStateOutgoingRequestedWebrtc,
    OngoingCallVideoStateIncomingRequestedWebrtc,
    OngoingCallVideoStateActiveWebrtc
};


typedef NS_ENUM(int32_t, OngoingCallRemoteVideoStateWebrtc) {
    OngoingCallRemoteVideoStateInactiveWebrtc,
    OngoingCallRemoteVideoStateActiveWebrtc
};

typedef NS_ENUM(int32_t, OngoingCallNetworkTypeWebrtc) {
    OngoingCallNetworkTypeWifiWebrtc,
};

typedef NS_ENUM(int32_t, OngoingCallDataSavingWebrtc) {
    OngoingCallDataSavingNeverWebrtc,
    OngoingCallDataSavingCellularWebrtc,
    OngoingCallDataSavingAlwaysWebrtc
};

@protocol OngoingCallThreadLocalContextQueueWebrtc <NSObject>

- (void)dispatch:(void (^ _Nonnull)())f;
- (bool)isCurrent;

@end

@interface VoipProxyServerWebrtc : NSObject

@property (nonatomic, strong, readonly) NSString * _Nonnull host;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSString * _Nullable username;
@property (nonatomic, strong, readonly) NSString * _Nullable password;

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password;

@end

@interface VoipRtcServerWebrtc : NSObject

@property (nonatomic, strong, readonly) NSString * _Nonnull host;
@property (nonatomic, readonly) int32_t port;
@property (nonatomic, strong, readonly) NSString * _Nullable username;
@property (nonatomic, strong, readonly) NSString * _Nullable password;
@property (nonatomic, readonly) bool isTurn;

- (instancetype _Nonnull)initWithHost:(NSString * _Nonnull)host port:(int32_t)port username:(NSString * _Nullable)username password:(NSString * _Nullable)password isTurn:(bool)isTurn;

@end

@interface OngoingCallThreadLocalContextVideoCapturer : NSObject
    
- (instancetype _Nonnull)init;
    
- (void)switchVideoCamera;
- (void)setIsVideoEnabled:(bool)isVideoEnabled;
    
- (void)makeOutgoingVideoView:(void (^_Nonnull)(NSView * _Nullable))completion;
    
@end


@interface OngoingCallThreadLocalContextWebrtc : NSObject

+ (void)setupLoggingFunction:(void (* _Nullable)(NSString * _Nullable))loggingFunction;
+ (void)applyServerConfig:(NSString * _Nullable)data;
+ (int32_t)maxLayer;
+ (NSString * _Nonnull)version;

@property (nonatomic, copy) void (^ _Nullable stateChanged)(OngoingCallStateWebrtc, OngoingCallVideoStateWebrtc, OngoingCallRemoteVideoStateWebrtc);
@property (nonatomic, copy) void (^ _Nullable signalBarsChanged)(int32_t);

- (instancetype _Nonnull)initWithQueue:(id<OngoingCallThreadLocalContextQueueWebrtc> _Nonnull)queue proxy:(VoipProxyServerWebrtc * _Nullable)proxy rtcServers:(NSArray<VoipRtcServerWebrtc *> * _Nonnull)rtcServers networkType:(OngoingCallNetworkTypeWebrtc)networkType dataSaving:(OngoingCallDataSavingWebrtc)dataSaving derivedState:(NSData * _Nonnull)derivedState key:(NSData * _Nonnull)key isOutgoing:(bool)isOutgoing primaryConnection:(OngoingCallConnectionDescriptionWebrtc * _Nonnull)primaryConnection alternativeConnections:(NSArray<OngoingCallConnectionDescriptionWebrtc *> * _Nonnull)alternativeConnections maxLayer:(int32_t)maxLayer allowP2P:(BOOL)allowP2P logPath:(NSString * _Nonnull)logPath sendSignalingData:(void (^ _Nonnull)(NSData * _Nonnull))sendSignalingData videoCapturer:(OngoingCallThreadLocalContextVideoCapturer * _Nullable)videoCapturer;
    
- (void)stop:(void (^_Nullable)(NSString * _Nullable debugLog, int64_t bytesSentWifi, int64_t bytesReceivedWifi, int64_t bytesSentMobile, int64_t bytesReceivedMobile))completion;

- (bool)needRate;

- (NSString * _Nullable)debugInfo;
- (NSString * _Nullable)version;
- (NSData * _Nonnull)getDerivedState;

- (void)setIsMuted:(bool)isMuted;
- (void)setVideoEnabled:(bool)videoEnabled;
- (void)switchVideoCamera;
- (void)setNetworkType:(OngoingCallNetworkTypeWebrtc)networkType;
- (void)makeIncomingVideoView:(void (^_Nonnull)(NSView * _Nullable))completion;
- (void)makeOutgoingVideoView:(void (^_Nonnull)(NSView * _Nullable))completion;
- (void)addSignalingData:(NSData * _Nonnull)data;

@end

#endif
