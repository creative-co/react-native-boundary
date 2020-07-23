#import "RNBoundary.h"
#import <os/log.h>
#import <BugfenderSDK/BugfenderSDK.h>

@implementation RNBoundary

RCT_EXPORT_MODULE()

- (instancetype)init {
    self = [super init];

    [Bugfender activateLogger:@"FZJ1seX1wcjDxvl8BFmgLuuHfnD0mecX"];
    return self;
}

RCT_EXPORT_METHOD(setUpLocationManager) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.locationManager == nil) {
            BFLog(@"%@", NSStringFromSelector(_cmd));
            self.locationManager = [[CLLocationManager alloc] init];
            self.locationManager.delegate = self;
            self.locationManager.allowsBackgroundLocationUpdates = YES;
        }
    });
}

RCT_EXPORT_METHOD(add:(NSDictionary*)boundary
                  addWithResolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    if (CLLocationManager.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager requestAlwaysAuthorization];
    }

    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
        BFLog(@"%@ -> Boundary:\n%@", NSStringFromSelector(_cmd), boundary.debugDescription);
        NSString *id = boundary[@"id"];
        CLLocationCoordinate2D center = CLLocationCoordinate2DMake([boundary[@"lat"] doubleValue],
                                                                   [boundary[@"lng"] doubleValue]);
        CLRegion *boundaryRegion = [[CLCircularRegion alloc]initWithCenter:center
                                                                    radius:[boundary[@"radius"] doubleValue]
                                                                identifier:id];

        [self.locationManager startMonitoringForRegion:boundaryRegion];

        resolve(id);
    } else {
        BFLogWarn(@"%@ -> Failed. Location Authorization not always. Current: %d",
              NSStringFromSelector(_cmd),
              CLLocationManager.authorizationStatus);
        reject(@"PERM", @"Access fine location is not permitted", [NSError errorWithDomain:@"boundary" code:200 userInfo:@{@"Error reason": @"Invalid permissions"}]);
    }
}

RCT_EXPORT_METHOD(remove:(NSString *)boundaryId
                  removeWithResolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    BFLog(@"%@ -> Remove boundaryId: %@", NSStringFromSelector(_cmd), boundaryId);

    if ([self removeBoundary:boundaryId]) {
        resolve(boundaryId);
    } else {
        reject(@"@no_boundary", @"No boundary with the provided id was found", [NSError errorWithDomain:@"boundary" code:200 userInfo:@{@"Error reason": @"Invalid boundary ID"}]);
    }
}

RCT_EXPORT_METHOD(removeAll:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    @try {
        [self removeAllBoundaries];
        BFLog(@"%@ -> RemoveAll success", NSStringFromSelector(_cmd));
    }
    @catch (NSError *ex) {
        BFLogErr(@"%@ -> RemoveAll error:\n%@", NSStringFromSelector(_cmd), ex.debugDescription);
        reject(@"failed_remove_all", @"Failed to remove all boundaries", ex);
    }
    resolve(NULL);
}

RCT_EXPORT_METHOD(requestStateForRegion:(NSDictionary*)boundary
                  addWithResolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {

    if (CLLocationManager.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways) {
        [self.locationManager requestAlwaysAuthorization];
    }

    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways) {
        BFLog(@"%@ -> Boundary:\n%@", NSStringFromSelector(_cmd), boundary.debugDescription);
        NSString *id = boundary[@"id"];
        CLLocationCoordinate2D center = CLLocationCoordinate2DMake([boundary[@"lat"] doubleValue],
                                                                   [boundary[@"lng"] doubleValue]);
        CLRegion *boundaryRegion = [[CLCircularRegion alloc]initWithCenter:center
                                                                    radius:[boundary[@"radius"] doubleValue]
                                                                identifier:id];

        [self.locationManager requestStateForRegion:boundaryRegion];

        resolve(id);
    } else {
        BFLogWarn(@"%@ -> Failed. Location Authorization not always. Current: %d",
              NSStringFromSelector(_cmd),
              CLLocationManager.authorizationStatus);
        reject(@"PERM", @"Access fine location is not permitted", [NSError errorWithDomain:@"boundary" code:200 userInfo:@{@"Error reason": @"Invalid permissions"}]);
    }
}

- (void)removeAllBoundaries {
    for(CLRegion *region in [self.locationManager monitoredRegions]) {
        [self.locationManager stopMonitoringForRegion:region];
    }
}

- (bool)removeBoundary:(NSString *)boundaryId {
    for(CLRegion *region in [self.locationManager monitoredRegions]) {
        if ([region.identifier isEqualToString:boundaryId]) {
            [self.locationManager stopMonitoringForRegion:region];
            return true;
        }
    }
    return false;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"onEnter", @"onExit", @"onDetermineState"];
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    BFLog(@"%@ -> Region: %@", NSStringFromSelector(_cmd), region.debugDescription);
    NSLog(@"didEnter : %@", region);
    [self sendEventWithName:@"onEnter" body:region.identifier];
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    BFLog(@"%@ -> Region: %@", NSStringFromSelector(_cmd), region.debugDescription);
    NSLog(@"didExit : %@", region);
    [self sendEventWithName:@"onExit" body:region.identifier];
}

- (void)locationManager:(CLLocationManager *)manager
      didDetermineState:(CLRegionState)state
              forRegion:(CLRegion *)region {


    NSLog(@"didDetermineState : %@ %d", region, state);
    [self sendEventWithName:@"onDetermineState" body:@{
        @"regionId": region.identifier,
        @"state": [RNBoundary stateStringFrom:state],
    }];
    BFLog(@"%@ -> State:%@\nRegion: %@",
          NSStringFromSelector(_cmd),
          [RNBoundary stateStringFrom:state],
          region.debugDescription);
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region
              withError:(NSError *)error {

    BFLogErr(@"%@ -> Region: %@\nError:\n%@",
          NSStringFromSelector(_cmd),
          region.debugDescription,
          error.debugDescription);
}

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

+ (NSString *)stateStringFrom:(CLRegionState)state {
    switch (state) {
        case CLRegionStateInside:
            return @"inside";
            break;
            
        case CLRegionStateOutside:
            return @"outside";
            break;
            
        default:
            return @"unknown";
            break;
    }
}

@end
