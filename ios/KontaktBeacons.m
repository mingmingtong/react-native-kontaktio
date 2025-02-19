#import "KontaktBeacons.h"

#if __has_include("RCTConvert.h")
  #import "RCTConvert.h"
#else
  #import <React/RCTConvert.h>
#endif

#import <KontaktSDK/KontaktSDK.h>

@interface KontaktBeacons() <KTKBeaconManagerDelegate,
    KTKDevicesManagerDelegate,KTKEddystoneManagerDelegate>

@property (strong, nonatomic) KTKBeaconManager *beaconManager;
@property (strong, nonatomic) KTKDevicesManager *devicesManager;
@property (strong, nonatomic) KTKEddystoneManager *eddystoneManager;

@property (assign, nonatomic) BOOL dropEmptyRanges;
@property (assign, nonatomic) NSTimeInterval discoveryInterval;
@property (assign, nonatomic) BOOL connectNearbyBeacons;
@property (assign, nonatomic) NSTimeInterval invalidationAge;  // Default: 10


@end


@implementation KontaktBeacons
{
    bool hasListeners;
}

RCT_EXPORT_MODULE()


#pragma mark Initialization

- (instancetype)init
{
    if (self = [super init]) {

        [Kontakt removeCaches];
        [Kontakt setAPIKey:@"default-kontaktio-api-key"];

        // init of beaconManager has to happen here.

        // BeaconManager for monitoring and ranging
        self.beaconManager = [[KTKBeaconManager alloc] initWithDelegate:self];

        // DevicesManager for kontaktio specific fields like uniqueId
        self.devicesManager = [[KTKDevicesManager alloc] initWithDelegate:self];

        self.eddystoneManager = [[KTKEddystoneManager alloc] initWithDelegate:self];
        // Default values
        self.dropEmptyRanges = YES;
        self.connectNearbyBeacons = NO;
    }

    return self;
}

#pragma mark

- (NSArray<NSString *> *)supportedEvents
{
    return @[
        @"authorizationStatusDidChange",
        @"didStartMonitoringForRegion",
        @"monitoringDidFailForRegion",
        @"didEnterRegion",
        @"didDetermineState",
        @"didExitRegion",
        @"didRangeBeacons",
        @"rangingDidFailForRegion",
        @"didDiscoverDevices",
        @"discoveryDidFail",
        @"didDiscoverEddystones",
        @"didFailToStartDiscoverEddystones",
        @"didUpdateEddystone"
    ];
}

- (NSDictionary *)constantsToExport
{
    return @{ @"DEFAULT_API_KEY": @"default-kontaktio-api-key" };
}


// Will be called when this module's first listener is added.
-(void)startObserving {
    hasListeners = YES;
    // Set up any upstream listeners or background tasks as necessary
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
    hasListeners = NO;
    // Remove upstream listeners, stop unnecessary background tasks
}


// ---------
// HELPER METHODS
// ---------

-(KTKBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                  uuid: (NSString *) uuid
                                 major: (NSInteger) major
                                 minor:(NSInteger) minor
{
    NSUUID *beaconUUID = [[NSUUID alloc] initWithUUIDString:uuid];

    unsigned short mj = (unsigned short) major;
    unsigned short mi = (unsigned short) minor;

    KTKBeaconRegion *beaconRegion = [[KTKBeaconRegion alloc] initWithProximityUUID:beaconUUID major:mj
                                                                           minor:mi
                                                                      identifier:identifier];

    beaconRegion.notifyEntryStateOnDisplay = YES;

    return beaconRegion;
}

-(KTKBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                  uuid: (NSString *) uuid
                                 major: (NSInteger) major
{
    NSUUID *beaconUUID = [[NSUUID alloc] initWithUUIDString:uuid];

    unsigned short mj = (unsigned short) major;

    KTKBeaconRegion *beaconRegion = [[KTKBeaconRegion alloc] initWithProximityUUID:beaconUUID
                                                                           major:mj
                                                                      identifier:identifier];

    beaconRegion.notifyEntryStateOnDisplay = YES;

    return beaconRegion;
}

-(KTKBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                   uuid: (NSString *) uuid
{
    NSUUID *proximityUUID = [[NSUUID alloc] initWithUUIDString:uuid];

    KTKBeaconRegion *beaconRegion = [[KTKBeaconRegion alloc] initWithProximityUUID:proximityUUID
                                                                        identifier:identifier];
    beaconRegion.notifyEntryStateOnDisplay = YES;

    return beaconRegion;
}


-(KTKBeaconRegion *)convertDictToBeaconRegion:(NSDictionary *)dict {
    if (dict[@"minor"] == nil) {
        if (dict[@"major"] == nil) {
            return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                       uuid:[RCTConvert NSString:dict[@"uuid"]]];
        } else {
            return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                       uuid:[RCTConvert NSString:dict[@"uuid"]]
                                      major:[RCTConvert NSInteger:dict[@"major"]]];
        }
    } else {
        return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                   uuid:[RCTConvert NSString:dict[@"uuid"]]
                                  major:[RCTConvert NSInteger:dict[@"major"]]
                                  minor:[RCTConvert NSInteger:dict[@"minor"]]];
    }
}

-(KTKEddystoneRegion *)convertDictToEddystoneRegion:(NSDictionary *)dict {
    if (dict[@"namespaceID"] != nil) {
        if (dict[@"instanceID"] == nil) {
            return [[KTKEddystoneRegion alloc]  initWithNamespaceID:[RCTConvert NSString:dict[@"namespaceID"]]];
        } else {
            return [[KTKEddystoneRegion alloc]  initWithNamespaceID:[RCTConvert NSString:dict[@"namespaceID"]]
                                                         instanceID:[RCTConvert NSString:dict[@"instanceID"]]];
        }
    }
    if (dict[@"URL"] != nil){
        return [[KTKEddystoneRegion alloc]  initWithURL:[NSURL URLWithString:[RCTConvert NSString:dict[@"URL"]]]];
    }
    if (dict[@"URLDomain"] != nil){
        return [[KTKEddystoneRegion alloc]  initWithURLDomain:[RCTConvert NSString:dict[@"URLDomain"]]];
    }
    return nil;
}

-(NSString *)stringForProximity:(CLProximity)proximity {
    switch (proximity) {
        case CLProximityUnknown:    return @"unknown";
        case CLProximityFar:        return @"far";
        case CLProximityNear:       return @"near";
        case CLProximityImmediate:  return @"immediate";
        default:                    return @"";
    }
}

// TODO: Test it properly
-(NSNumber *)numberForTxPowerLevel:(KTKDeviceTransmissionPower)transmissionPower {
    switch (transmissionPower) {
        case KTKDeviceTransmissionPowerInvalid:    return @-1;
        case KTKDeviceTransmissionPower0:        return @0;
        case KTKDeviceTransmissionPower1:       return @1;
        case KTKDeviceTransmissionPower2:       return @2;
        case KTKDeviceTransmissionPower3:       return @3;
        case KTKDeviceTransmissionPower4:       return @4;
        case KTKDeviceTransmissionPower5:       return @5;
        case KTKDeviceTransmissionPower6:       return @6;
        case KTKDeviceTransmissionPower7:       return @7;
        default:                    return @-1;
    }
}

-(NSString *)stringForModel:(KTKDeviceModel)model {
    switch(model) {
        case KTKDeviceModelInvalid: return @"Invalid";
        case KTKDeviceModelUnknown: return @"Unknown";
        case KTKDeviceModelSmartBeacon: return @"SmartBeacon";
        case KTKDeviceModelUSBBeacon: return @"USBBeacon";
        case KTKDeviceModelSensorBeacon: return @"SensorBeacon";
        case KTKDeviceModelCloudBeacon: return @"CloudBeacon";
        case KTKDeviceModelCardBeacon: return @"CardBeacon";
        case KTKDeviceModelProBeacon: return @"ProBeacon";
        default:
            return @"Invalid";
    }
}

-(NSMutableDictionary *)errorInfoTextForException:(NSException *)exception {

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setValue:exception.name forKey:@"ExceptionName"];
    [info setValue:exception.reason forKey:@"ExceptionReason"];
    [info setValue:exception.callStackReturnAddresses forKey:@"ExceptionCallStackReturnAddresses"];
    [info setValue:exception.callStackSymbols forKey:@"ExceptionCallStackSymbols"];
    [info setValue:exception.userInfo forKey:@"ExceptionUserInfo"];

    return info;
}

-(NSString *)nameForAuthorizationStatus:(CLAuthorizationStatus)authorizationStatus
{
    switch (authorizationStatus) {
        case kCLAuthorizationStatusAuthorizedAlways:    return @"authorizedAlways";
        case kCLAuthorizationStatusAuthorizedWhenInUse: return @"authorizedWhenInUse";
        case kCLAuthorizationStatusDenied:              return @"denied";
        case kCLAuthorizationStatusNotDetermined:       return @"notDetermined";
        case kCLAuthorizationStatusRestricted:          return @"restricted";
    }
}

-(NSMutableDictionary *)parseRegion:(KTKEddystoneRegion *)region {
    NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
    beaconRegion[@"identifier"] = region.namespaceID;
    beaconRegion[@"instanceID"] =region.instanceID;
    beaconRegion[@"URL"] =region.URL;
    beaconRegion[@"URLDomain"] =region.URLDomain;
    return beaconRegion;
}
-(NSMutableDictionary *) parseEddystone:(KTKEddystone *)eddystone {
    NSMutableDictionary *beaconDict = [[NSMutableDictionary alloc] init];
    beaconDict[@"accuracy"] = @(eddystone.accuracy);
    beaconDict[@"proximity"] = @(eddystone.proximity);
    beaconDict[@"identifier"] = [eddystone.identifier UUIDString];
    beaconDict[@"namespace"] = [eddystone.eddystoneUID namespaceID];
    beaconDict[@"instanceId"] = [eddystone.eddystoneUID instanceID];
    beaconDict[@"url"] = [[eddystone.eddystoneURL url] absoluteString];
    if (eddystone.RSSI != nil) beaconDict[@"rssi"] = eddystone.RSSI;
    if (@(eddystone.updatedAt) != nil) beaconDict[@"updatedAt"] = @(eddystone.updatedAt);
    return beaconDict;
}

// ---------
// EXPOSED METHODS
// ---------

RCT_EXPORT_METHOD(init:(NSString *)apiKey
                 init_resolver:(RCTPromiseResolveBlock)resolve
                 init_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if (apiKey != nil) {
            [Kontakt removeCaches];
            [Kontakt setAPIKey:[RCTConvert NSString:apiKey]];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"init", @"Could not init beacon manager", error);
    }
}

RCT_EXPORT_METHOD(configure:(NSDictionary *)dict
                  configure_resolver:(RCTPromiseResolveBlock)resolve
                  configure_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if (dict[@"dropEmptyRanges"] != nil) {
            self.dropEmptyRanges = [RCTConvert BOOL:dict[@"dropEmptyRanges"]];
        }
        if (dict[@"connectNearbyBeacons"] != nil) {
            self.connectNearbyBeacons = [RCTConvert BOOL:dict[@"connectNearbyBeacons"]];
        }
        if (dict[@"invalidationAge"] != nil) {
            self.invalidationAge = [RCTConvert NSTimeInterval:dict[@"invalidationAge"]];
            self.devicesManager.invalidationAge = self.invalidationAge;
        }
        // TODO: add other stuff to configure?!

        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"configure", @"Could not configure beacon manager", error);
    }
}

// EDDYSTONE

RCT_EXPORT_METHOD(startEddystoneDiscovery:(NSDictionary *)dict
                  startEddystoneDiscovery_resolver:(RCTPromiseResolveBlock)resolve
                  startEddystoneDiscovery_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if (dict == nil) {
            [self.eddystoneManager startEddystoneDiscoveryInRegion:nil];
        } else {
             [self.eddystoneManager startEddystoneDiscoveryInRegion:[self convertDictToEddystoneRegion:dict]];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"startEddystoneDiscovery", @"Could not start beacon discovery", error);
    }
}


RCT_EXPORT_METHOD(stopEddystoneDiscoveryInRegion:(NSDictionary *)dict
                  stopEddystoneDiscoveryInRegion_resolver:(RCTPromiseResolveBlock)resolve
                  stopEddystoneDiscoveryInRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.eddystoneManager stopEddystoneDiscoveryInRegion:[self convertDictToEddystoneRegion:dict]];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"stopEddystoneDiscoveryInRegion", @"Could not stopRangingBeaconsInRegion", error);
    }
}

RCT_REMAP_METHOD(stopEddystoneDiscoveryInAllRegions,
                 stopEddystoneDiscoveryInAllRegions_resolver:(RCTPromiseResolveBlock)resolve
                 stopEddystoneDiscoveryInAllRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.eddystoneManager stopEddystoneDiscoveryInAllRegions];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"stopRangingBeaconsInAllRegions", @"Could not stopRangingBeaconsInAllRegions", error);
    }
}

// DISCOVERY

RCT_EXPORT_METHOD(startDiscovery:(NSDictionary *)dict
                  startDiscovery_resolver:(RCTPromiseResolveBlock)resolve
                  startDiscovery_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if (dict == nil || dict[@"interval"] == nil) {
            [self.devicesManager startDevicesDiscovery];
        } else {
            self.discoveryInterval = [RCTConvert NSTimeInterval:dict[@"interval"]];
            [self.devicesManager startDevicesDiscoveryWithInterval:self.discoveryInterval];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"startDiscovery", @"Could not start beacon discovery", error);
    }
}


RCT_REMAP_METHOD(stopDiscovery,
                  stopDiscovery_resolver:(RCTPromiseResolveBlock)resolve
                  stopDiscovery_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.devicesManager stopDevicesDiscovery];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"stopDiscovery", @"Could not stop beacon discovery", error);
    }
}

RCT_REMAP_METHOD(restartDiscovery,
                 restartDiscovery_resolver:(RCTPromiseResolveBlock)resolve
                 restartDiscovery_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.devicesManager restartDeviceDiscoveryWithCompletion:^(NSError *error) {
            if (error != nil) {
                [NSException raise:@"Cannot restart beacon discovery" format:@"error in restartDeviceDiscoveryWithCompletion"];
            }
        }];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"restartDiscovery", @"Could not restart beacon discovery", error);
    }
}

// is discovering (TODO: test)
RCT_REMAP_METHOD(isDiscovering,
                 isDiscovering_resolver:(RCTPromiseResolveBlock)resolve
                 isDiscovering_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        BOOL isDiscovering = [self.devicesManager isDiscovering];
        resolve(@(isDiscovering));
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"isDiscovering", @"Could not check discovery status", error);
    }
}


// RANGING

RCT_EXPORT_METHOD(startRangingBeaconsInRegion:(NSDictionary *)dict
                  startRangingBeaconsInRegion_resolver:(RCTPromiseResolveBlock)resolve
                  startRangingBeaconsInRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        switch ([KTKBeaconManager locationAuthorizationStatus]) {
            case kCLAuthorizationStatusNotDetermined:
                [self.beaconManager requestLocationAlwaysAuthorization];
                break;
            case kCLAuthorizationStatusAuthorizedWhenInUse:
            case kCLAuthorizationStatusAuthorizedAlways:
                // Good :)
                break;
            default:
                [NSException raise:@"unouthorizedException" format:@"Should ask for location authorization."];
                break;
        }
        if ([KTKBeaconManager isRangingAvailable]) {
            [self.beaconManager startRangingBeaconsInRegion:[self convertDictToBeaconRegion:dict]];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"startRangingBeaconsInRegion", @"Could not startRangingBeaconsInRegion", error);
    }
}

RCT_EXPORT_METHOD(stopRangingBeaconsInRegion:(NSDictionary *)dict
                  stopRangingBeaconsInRegion_resolver:(RCTPromiseResolveBlock)resolve
                  stopRangingBeaconsInRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.beaconManager stopRangingBeaconsInRegion:[self convertDictToBeaconRegion:dict]];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"stopRangingBeaconsInRegion", @"Could not stopRangingBeaconsInRegion", error);
    }
}

RCT_REMAP_METHOD(stopRangingBeaconsInAllRegions,
                 stopRangingBeaconsInAllRegions_resolver:(RCTPromiseResolveBlock)resolve
                 stopRangingBeaconsInAllRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.beaconManager stopRangingBeaconsInAllRegions];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"stopRangingBeaconsInAllRegions", @"Could not stopRangingBeaconsInAllRegions", error);
    }
}

RCT_REMAP_METHOD(getRangedRegions,
                 getRangedRegions_resolver:(RCTPromiseResolveBlock)resolve
                 getRangedRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        NSSet<__kindof KTKBeaconRegion*>* regions = [self.beaconManager rangedRegions];

        NSMutableArray *regionArray = [[NSMutableArray alloc] init];

        for (KTKBeaconRegion *region in regions) {
            NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
            beaconRegion[@"identifier"] = region.identifier;
            beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
            if (region.major != nil) beaconRegion[@"major"] = region.major;
            if (region.minor != nil) beaconRegion[@"minor"] = region.minor;

            [regionArray addObject:beaconRegion];
        }
        resolve(regionArray);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"getRangedRegions", @"Could not getRangedRegions", error);
    }
}

// MONITORING

RCT_EXPORT_METHOD(startMonitoringForRegion:(NSDictionary *)dict
                 startMonitoringForRegion_resolver:(RCTPromiseResolveBlock)resolve
                 startMonitoringForRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if ([KTKBeaconManager isMonitoringAvailable]) {
            [self.beaconManager startMonitoringForRegion:[self convertDictToBeaconRegion:dict]];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"startMonitoringForRegion", @"Could not startMonitoringForRegion", error);
    }
}

RCT_EXPORT_METHOD(stopMonitoringForRegion:(NSDictionary *)dict
                  stopMonitoringForRegion_resolver:(RCTPromiseResolveBlock)resolve
                  stopMonitoringForRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.beaconManager stopMonitoringForRegion:[self convertDictToBeaconRegion:dict]];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"stopMonitoringForRegion", @"Could not stopMonitoringForRegion", error);
    }
}

RCT_REMAP_METHOD(stopMonitoringForAllRegions,
                 stopMonitoringForAllRegions_resolver:(RCTPromiseResolveBlock)resolve
                 stopMonitoringForAllRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        [self.beaconManager stopMonitoringForAllRegions];
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"stopMonitoringForAllRegions", @"Could not stopMonitoringForAllRegions", error);
    }
}

RCT_REMAP_METHOD(getMonitoredRegions,
                 getMonitoredRegions_resolver:(RCTPromiseResolveBlock)resolve
                 getMonitoredRegions_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        NSSet<__kindof KTKBeaconRegion*>* regions = [self.beaconManager monitoredRegions];

        NSMutableArray *regionArray = [[NSMutableArray alloc] init];

        for (KTKBeaconRegion *region in regions) {
            NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
            beaconRegion[@"identifier"] = region.identifier;
            beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
            if (region.major != nil) beaconRegion[@"major"] = region.major;
            if (region.minor != nil) beaconRegion[@"minor"] = region.minor;

            [regionArray addObject:beaconRegion];
        }
        resolve(regionArray);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"getMonitoredRegions", @"Could not getMonitoredRegions", error);
    }
}

RCT_REMAP_METHOD(getAuthorizationStatus,
                 getAuthorizationStatus_resolver:(RCTPromiseResolveBlock)resolve
                 getAuthorizationStatus_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        CLAuthorizationStatus status = [KTKBeaconManager locationAuthorizationStatus];
        resolve([self nameForAuthorizationStatus:status]);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"getAuthorizationStatus", @"Could not get the current authorization status", error);
    }
}

RCT_REMAP_METHOD(requestAlwaysAuthorization,
                 requestAlwaysAuthorization_resolver:(RCTPromiseResolveBlock)resolve
                 requestAlwaysAuthorization_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if ([self.beaconManager respondsToSelector:@selector(requestLocationAlwaysAuthorization)]) {
            [self.beaconManager requestLocationAlwaysAuthorization];
        } else {
            [NSException raise:@"Cannot request LocationAlwaysAuthorization" format:@"requestAlwaysAuthorization does not respond to selector"];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"requestAlwaysAuthorization", @"Could not requestAlwaysAuthorization", error);
    }
}

RCT_REMAP_METHOD(requestWhenInUseAuthorization,
                 requestWhenInUseAuthorization_resolver:(RCTPromiseResolveBlock)resolve
                 requestWhenInUseAuthorization_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
        if ([self.beaconManager respondsToSelector:@selector(requestLocationWhenInUseAuthorization)]) {
            [self.beaconManager requestLocationWhenInUseAuthorization];
        } else {
            [NSException raise:@"Cannot request LocationWhenInUseAuthorization" format:@"requestLocationWhenInUseAuthorization does not respond to selector"];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"requestWhenInUseAuthorization", @"Could not requestWhenInUseAuthorization", error);
    }
}

RCT_EXPORT_METHOD(requestStateForRegion:(NSDictionary *)dict
                 requestStateForRegion_resolver:(RCTPromiseResolveBlock)resolve
                 requestStateForRegion_rejecter:(RCTPromiseRejectBlock)reject)
{
    @try {
         NSLog(@"requestStateForRegion!!! %@", [self convertDictToBeaconRegion:dict]);
        if ([KTKBeaconManager isMonitoringAvailable]) {
            [self.beaconManager requestStateForRegion:[self convertDictToBeaconRegion:dict]];
        }
        resolve(nil);
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"com.mingmingtong.kontakt" code:0 userInfo:[self errorInfoTextForException:exception]];
        reject(@"requestStateForRegion", @"Could not requestStateForRegion", error);
    }
}

// ---------
// LISTENERS
// ---------


- (void)beaconManager:(KTKBeaconManager *)manager didChangeLocationAuthorizationStatus:(CLAuthorizationStatus)status {
    NSString *statusName = [self nameForAuthorizationStatus:status];
    if (hasListeners) {
        [self sendEventWithName:@"authorizationStatusDidChange" body:@{@"status": statusName}];
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager didStartMonitoringForRegion:(__kindof KTKBeaconRegion *)region {
    // Do something when monitoring for a particular
    // region is successfully initiated

    NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
    beaconRegion[@"identifier"] = region.identifier;
    beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
    if (region.major != nil) beaconRegion[@"major"] = region.major;
    if (region.minor != nil) beaconRegion[@"minor"] = region.minor;

    if (hasListeners) {
        [self sendEventWithName:@"didStartMonitoringForRegion" body:@{@"region": beaconRegion}];
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager monitoringDidFailForRegion:(__kindof KTKBeaconRegion *)region withError:(NSError *)error {
    // Handle monitoring failing to start for your region

    NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
    beaconRegion[@"identifier"] = region.identifier;
    beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
    if (region.major != nil) beaconRegion[@"major"] = region.major;
    if (region.minor != nil) beaconRegion[@"minor"] = region.minor;

    if (hasListeners) {
        [self sendEventWithName:@"monitoringDidFailForRegion" body:@{@"region": beaconRegion, @"error": error.localizedDescription}];
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager didEnterRegion:(__kindof KTKBeaconRegion *)region {
    // Decide what to do when a user enters a range of your region; usually used
    // for triggering a local notification and/or starting a beacon ranging

    NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
    beaconRegion[@"identifier"] = region.identifier;
    beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
    if (region.major != nil) beaconRegion[@"major"] = region.major;
    if (region.minor != nil) beaconRegion[@"minor"] = region.minor;

    if (hasListeners) {
        [self sendEventWithName:@"didEnterRegion" body:@{@"region": beaconRegion}];
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager didExitRegion:(__kindof KTKBeaconRegion *)region {
    // Decide what to do when a user exits a range of your region; usually used
    // for triggering a local notification and stoping a beacon ranging

    NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
    beaconRegion[@"identifier"] = region.identifier;
    beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
    if (region.major != nil) beaconRegion[@"major"] = region.major;
    if (region.minor != nil) beaconRegion[@"minor"] = region.minor;

    if (hasListeners) {
        [self sendEventWithName:@"didExitRegion" body:@{@"region": beaconRegion}];
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager didRangeBeacons:(NSArray<CLBeacon *> *)beacons inRegion:(__kindof KTKBeaconRegion *)region {

    if (self.dropEmptyRanges && beacons.count == 0) {
        // No beacons ranged
        return;
    }

    NSMutableArray *beaconArray = [[NSMutableArray alloc] init];

    for (CLBeacon *beacon in beacons) {
        [beaconArray addObject:@{
                                 @"uuid": [beacon.proximityUUID UUIDString],
                                 @"major": beacon.major,
                                 @"minor": beacon.minor,

                                 @"rssi": [NSNumber numberWithLong:beacon.rssi],
                                 @"proximity": [self stringForProximity: beacon.proximity],
                                 @"accuracy": [NSNumber numberWithDouble: beacon.accuracy]
                                 }];
    }

    NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
    beaconRegion[@"identifier"] = region.identifier;
    beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
    if (region.major != nil) beaconRegion[@"major"] = region.major;
    if (region.minor != nil) beaconRegion[@"minor"] = region.minor;

    NSDictionary *event = @{
                            @"region": beaconRegion,
                            @"beacons": beaconArray
                            };

    if (hasListeners) {
        [self sendEventWithName:@"didRangeBeacons" body:event];
    }
//    [self.bridge.eventDispatcher sendDeviceEventWithName:@"beaconsDidRange" body:event];
}

- (void)beaconManager:(KTKBeaconManager *)manager rangingBeaconsDidFailForRegion:(__kindof KTKBeaconRegion *)region withError:(NSError *)error {
    // Handle ranging failing to start for your region

    NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
    beaconRegion[@"identifier"] = region.identifier;
    beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
    if (region.major != nil) beaconRegion[@"major"] = region.major;
    if (region.minor != nil) beaconRegion[@"minor"] = region.minor;

    if (hasListeners) {
        [self sendEventWithName:@"rangingDidFailForRegion" body:@{@"region": beaconRegion, @"error": error.localizedDescription}];
    }
}

- (void)devicesManager:(KTKDevicesManager *)manager didDiscoverDevices:(NSArray<KTKNearbyDevice *> *)devices {

    if (self.dropEmptyRanges && devices.count == 0) {
        return;
    }

    NSMutableArray *deviceArray = [[NSMutableArray alloc] init];
    NSString *errorMessage = @"NO_ERROR";

    for (KTKNearbyDevice *device in devices) {

        // Investigate for future version
        if (self.connectNearbyBeacons) {

            @try {
                // Connect to nearby devices is necessary in iOS to get major, minor and UUID
                KTKDeviceConnection *connection = [[KTKDeviceConnection alloc] initWithNearbyDevice:device];

                // Does not work with firmware 3.1: Read configuration was cancelled (Legacy Firmware)
                // Beacons with 4.1 firmware (e.g. d0JF) throw: Request failed: forbidden (403)
                // After entering correct API key in configuration I get: Request failed: internal server error (500)
                [connection readConfigurationWithCompletion:^(KTKDeviceConfiguration* configuration, NSError* error) {
                    //                NSLog(@"in read configuration: beacon with uniqueId %@, error: %@", device.uniqueID, error.localizedDescription);
                    if (error == nil) {
                        NSLog(@"in read CONFIGuration uniqueId: %@, uniqueId from config: %@, uuid: %@, minor: %@", device.uniqueID, configuration.uniqueID, [configuration.proximityUUID UUIDString], configuration.minor);
                    } else {
                        NSLog(@"in read configuration: beacon with uniqueId %@, error: %@", device.uniqueID, error.localizedDescription);
                        // [NSException raise:@"Error in readConfigurationWithCompletion" format:@"%@", error.localizedDescription];
                    }
                }];
            } @catch (NSException *exception) {
                errorMessage = @"Error while trying to establish beacon connection";
            }
        }

        NSMutableDictionary *beaconDict = [[NSMutableDictionary alloc] init];
        if (device.name != nil) beaconDict[@"name"] = device.name;
        if (device.uniqueID != nil) beaconDict[@"uniqueId"] = device.uniqueID;
        if (device.firmwareVersion != nil) beaconDict[@"firmwareVersion"] = device.firmwareVersion;
        if (device.batteryLevel != nil) beaconDict[@"batteryLevel"] = [NSNumber numberWithLong:device.batteryLevel];
        if (device.batteryPowered != nil) beaconDict[@"batteryPowered"] =@(device.batteryPowered);
        if (device.transmissionPower != nil) beaconDict[@"transmissionPower"] = [self numberForTxPowerLevel:device.transmissionPower];
        if (@(device.hasConfigurationProfile) != nil) beaconDict[@"hasConfigurationProfile"] = @(device.hasConfigurationProfile);
        if (@(device.shuffled) != nil) beaconDict[@"shuffled"] = @(device.shuffled);
        if (@(device.locked) != nil) beaconDict[@"locked"] = @(device.locked);
        if (device.model != nil) beaconDict[@"model"] = [self stringForModel:device.model];
        if (device.peripheral.name != nil) beaconDict[@"peripheral"] = device.peripheral.name;
        if (device.RSSI != nil) beaconDict[@"rssi"] = device.RSSI;
        if (@(device.updatedAt) != nil) beaconDict[@"updatedAt"] = @(device.updatedAt);

        [deviceArray addObject:beaconDict];
    }

    NSDictionary *event = @{
                            @"beacons": deviceArray,
                            @"error": errorMessage,
                            };

    if (hasListeners) {
        [self sendEventWithName:@"didDiscoverDevices" body:event];
    }
}

- (void)devicesManagerDidFailToStartDiscovery:(KTKDevicesManager *)manager withError:(NSError *)error {
    if (hasListeners) {
        [self sendEventWithName:@"discoveryDidFail" body:@{ @"error": error.localizedDescription }];
    }
}

- (void)eddystoneManager:(KTKEddystoneManager *)manager
   didDiscoverEddystones:(NSSet *)eddystones
                inRegion:(__kindof KTKEddystoneRegion *_Nullable)region {
    if (self.dropEmptyRanges && eddystones.count == 0) {
        return;
    }

    NSMutableArray *deviceArray = [[NSMutableArray alloc] init];

    NSMutableDictionary *beaconRegion = [self parseRegion:region];

    for (KTKEddystone *eddystone in eddystones) {
        NSMutableDictionary *beaconDict = [self parseEddystone:eddystone];
        [deviceArray addObject:beaconDict];
    }
    NSDictionary *event = @{
                            @"region": beaconRegion,
                            @"eddystones": deviceArray
                            };

    if (hasListeners) {
        [self sendEventWithName:@"didDiscoverEddystones" body:event];
    }
}

- (void)eddystoneManagerDidFailToStartDiscovery:(KTKEddystoneManager *)manager
                                      withError:(NSError *_Nullable)error {
    if (hasListeners) {
        [self sendEventWithName:@"didFailToStartDiscoverEddystones" body:@{ @"error": error.localizedDescription }];
    }
}

- (void)eddystoneManager:(KTKEddystoneManager *)manager
      didUpdateEddystone:(KTKEddystone *)eddystone
               withFrame:(KTKEddystoneFrameType)frameType {
    NSDictionary *event = @{
                            @"eddystone": [self parseEddystone:eddystone]
                            };

    if (hasListeners) {
        [self sendEventWithName:@"didUpdateEddystone" body:event];
    }
}

- (void)beaconManager:(KTKBeaconManager *)manager didDetermineState:(CLRegionState)state forRegion:(__kindof KTKBeaconRegion *)region {
    NSMutableDictionary *beaconRegion = [[NSMutableDictionary alloc] init];
    beaconRegion[@"identifier"] = region.identifier;
    beaconRegion[@"uuid"] = [region.proximityUUID UUIDString];
    if (region.major != nil) beaconRegion[@"major"] = region.major;
    if (region.minor != nil) beaconRegion[@"minor"] = region.minor;
    if (hasListeners) {
        [self sendEventWithName:@"didDetermineState" body:@{@"region": beaconRegion, @"state": [self convertToString:state]}];
    }
}

// this function was added because I needed a way to convert the CLRegionState enum to a string
- (NSString*) convertToString:(CLRegionState) whichState {
    NSString *result = nil;
    switch(whichState) {
        case 0:
            result = @"unknown";
            break;
        case 1:
            result = @"inside";
            break;
        case 2:
            result = @"outside";
            break;
        default:
            result = @"unknown";
    }
    return result;
}

@end
