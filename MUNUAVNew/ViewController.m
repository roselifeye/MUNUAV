//
//  ViewController.m
//  MUNUAVNew
//
//  Created by  sy2036 on 2018-01-21.
//  Copyright © 2018 vclab. All rights reserved.
//

#import "ViewController.h"
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>

#import "ImageProcessing.h"
#import "UIImage+Additions.h"

#define ENTER_DEBUG_MODE 0
#define ROTATE_ANGLE 45
#define PHOTO_NUMBER 8
#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;

@interface ViewController ()<DJICameraDelegate, DJISDKManagerDelegate, DJIFlightControllerDelegate, DJIVideoFeedListener, UIImagePickerControllerDelegate>{
    
}

@property (atomic) CLLocationCoordinate2D aircraftLocation;
@property (atomic) double aircraftAltitude;
@property (atomic) double aircraftYaw;
@property (atomic) DJIGPSSignalLevel gpsSignalLevel;

@property (assign, nonatomic) BOOL isRecording;

@end

@implementation ViewController
- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.title = @"MUNUAV Demo";
    self.aircraftLocation = kCLLocationCoordinate2DInvalid;
    [[VideoPreviewer instance] setView:self.fpvPreviewView];
    [self registerApp];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    DJICamera *camera = [self fetchCamera];
    if (camera && camera.delegate == self) {
        [camera setDelegate:nil];
    }
    [self resetVideoPreview];
    
//    captureMissionTimer = nil;
}

- (void)registerApp {
    //Please enter the App Key in the info.plist file to register the App.
    [DJISDKManager registerAppWithDelegate:self];
}

#pragma mark DJISDKManagerDelegate Methods
- (void)appRegisteredWithError:(NSError *)error {
    NSString* message = @"Register App Successfully!";
    if (error)
        message = @"Register App Failed! Please enter your App Key and check the network.";
    else {
        NSLog(@"registerAppSuccess");
        
#if ENTER_DEBUG_MODE
        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"10.81.0.208"];
#else
        [DJISDKManager startConnectionToProduct];
#endif
        [self setupVideoPreviewer];
        
    }
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
}

- (void)productConnected:(DJIBaseProduct *)product {
    if (product) {
        DJICamera* camera = [self fetchCamera];
        if (camera != nil) {
            camera.delegate = self;
            [camera.playbackManager setDelegate:self];
        }
    }
    
//    DJIFlightController *flightController = [self fetchFlightController];
//    if (flightController) {
//        [flightController setDelegate:self];
//    }
}

#pragma mark - DJIVideoFeedListener
- (void)videoFeed:(DJIVideoFeed *)videoFeed didUpdateVideoData:(NSData *)videoData {
    [[VideoPreviewer instance] push:(uint8_t *)videoData.bytes length:(int)videoData.length];
}

#pragma mark - DJICameraDelegate
- (void)camera:(DJICamera*)camera didUpdateSystemState:(DJICameraSystemState*)systemState {
    self.isRecording = systemState.isRecording;
}

#pragma mark - DJIFlightControllerDelegate Method
- (void)flightController:(DJIFlightController *_Nonnull)fc didUpdateState:(DJIFlightControllerState *_Nonnull)state {
    self.aircraftLocation = CLLocationCoordinate2DMake(state.aircraftLocation.coordinate.latitude, state.aircraftLocation.coordinate.longitude);
    self.gpsSignalLevel = state.GPSSignalLevel;
    self.aircraftAltitude = state.altitude;
    self.aircraftYaw = state.attitude.yaw;
}

#pragma mark --
#pragma mark Custom Methods
- (void)setupVideoPreviewer {
//    DJIBaseProduct *product = [DJISDKManager product];
    //    if ([product.model isEqual:DJIAircraftModelNameA3] ||
    //        [product.model isEqual:DJIAircraftModelNameN3] ||
    //        [product.model isEqual:DJIAircraftModelNameMatrice600] ||
    //        [product.model isEqual:DJIAircraftModelNameMatrice600Pro]) {
    //        [[DJISDKManager videoFeeder].secondaryVideoFeed addListener:self withQueue:nil];
    //
    //    } else {
    [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
    //    }
    [[VideoPreviewer instance] start];
}

- (void)resetVideoPreview {
    [[VideoPreviewer instance] unSetView];
//    DJIBaseProduct *product = [DJISDKManager product];
//    if ([product.model isEqual:DJIAircraftModelNameA3] ||
//        [product.model isEqual:DJIAircraftModelNameN3] ||
//        [product.model isEqual:DJIAircraftModelNameMatrice600] ||
//        [product.model isEqual:DJIAircraftModelNameMatrice600Pro]){
//        [[DJISDKManager videoFeeder].secondaryVideoFeed removeListener:self];
//    }else{
        [[DJISDKManager videoFeeder].primaryVideoFeed removeListener:self];
//    }
}

- (DJICamera*)fetchCamera {
    if (![DJISDKManager product])
        return nil;
    return [DJISDKManager product].camera;
}

- (DJIFlightController*)fetchFlightController {
    if (![DJISDKManager product])
        return nil;
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]])
        return ((DJIAircraft*)[DJISDKManager product]).flightController;
    return nil;
}

- (DJIGimbal*) fetchGimbal {
    if (![DJISDKManager product]) {
        return nil;
    }
    return [DJISDKManager product].gimbal;
}

#pragma mark - Rotate Drone With Waypoint Mission Methods
- (DJIWaypointMissionOperator *)missionOperator {
    return [[DJISDKManager missionControl] waypointMissionOperator];
}

- (void)rotateDroneWithWaypointMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    //    if (CLLocationCoordinate2DIsValid(self.aircraftLocation) && self.gpsSignalLevel != DJIGPSSignalLevel0 && self.gpsSignalLevel != DJIGPSSignalLevel1) {
    //        [self uploadWaypointMissionWithCoordinate:targetCoordinate andTargetAltitude:targetAltitude];
    //    }
    //    else {
    //        [self showAlertViewWithTitle:@"GPS signal weak" withMessage:@"Rotate drone failed"];
    //    }
    [self uploadWaypointMissionWithCoordinate:targetCoordinate andTargetAltitude:targetAltitude];
}

- (void)uploadWaypointMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    
    [self initializeMissionWithCoordinate:targetCoordinate andTargetAltitude:targetAltitude];
    
    weakSelf(target);
    
    [[self missionOperator] uploadMissionWithCompletion:^(NSError * _Nullable error) {
        
        weakReturn(target);
        
        if (error) {
            //            NSLog(@"ccccc%@", [NSString stringWithFormat:@"Upload Mission Failed: %@", [NSString stringWithFormat:@"%@", error.description]]);
            NSString* uploadError = [NSString stringWithFormat:@"Upload Mission failed:%@", error.description];
            [self showAlertViewWithTitle:@"" withMessage:uploadError];
        }else
        {
            //            NSLog(@"Upload Mission Finished");
            [self showAlertViewWithTitle:@"" withMessage:@"Upload Mission Finished"];
        }
    }];
}

- (void)initializeMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    DJIMutableWaypointMission *mission = [[DJIMutableWaypointMission alloc] init];
    mission.maxFlightSpeed = 15.0;
    mission.autoFlightSpeed = 4.0;
    
    DJIWaypoint *wp1 = [[DJIWaypoint alloc] initWithCoordinate:self.aircraftLocation];
    wp1.altitude = self.aircraftAltitude;
    
    for (int i = 0; i < PHOTO_NUMBER ; i++) {
        
        double rotateAngle = ROTATE_ANGLE*i;
        
        if (rotateAngle > 180) { //Filter the angle between -180 ~ 0, 0 ~ 180
            rotateAngle = rotateAngle - 360;
        }
        
        DJIWaypointAction *action1 = [[DJIWaypointAction alloc] initWithActionType:DJIWaypointActionTypeShootPhoto param:0];
        DJIWaypointAction *action2 = [[DJIWaypointAction alloc] initWithActionType:DJIWaypointActionTypeRotateAircraft param:rotateAngle];
        [wp1 addAction:action1];
        [wp1 addAction:action2];
    }
    
    DJIWaypoint *wp2 = [[DJIWaypoint alloc] initWithCoordinate:self.aircraftLocation];
    wp2.altitude = self.aircraftAltitude + 1;
    
    [mission addWaypoint:wp1];
    [mission addWaypoint:wp2];
    [mission setFinishedAction:DJIWaypointMissionFinishedNoAction]; //Change the default action of Go Home to None //Change the default action of Go Home to None
    
    [[self missionOperator] loadMission:mission];
    
    weakSelf(target);
    
    [[self missionOperator] addListenerToUploadEvent:self withQueue:dispatch_get_main_queue() andBlock:^(DJIWaypointMissionUploadEvent * _Nonnull event) {
        
        weakReturn(target);
        if (event.currentState == DJIWaypointMissionStateUploading) {
            
            NSString *message = [NSString stringWithFormat:@"Uploaded Waypoint Index: %ld, Total Waypoints: %ld" ,event.progress.uploadedWaypointIndex + 1, event.progress.totalWaypointCount];
            
            
        }else if (event.currentState == DJIWaypointMissionStateReadyToExecute){
            
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Upload Mission Finished" message:nil preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *startMissionAction = [UIAlertAction actionWithTitle:@"Start Mission" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [target startWaypointMission];
            }];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:cancelAction];
            [alert addAction:startMissionAction];
            [target presentViewController:alert animated:YES completion:nil];
            
        }
        
    }];
    
    [[self missionOperator] addListenerToFinished:self withQueue:dispatch_get_main_queue() andBlock:^(NSError * _Nullable error) {
        
        weakReturn(target);
        
        if (error) {
            [target showAlertViewWithTitle:@"Mission Execution Failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
        }
        else {
            [target showAlertViewWithTitle:@"Mission Execution Finished" withMessage:nil];
            //  飞行完成后，回传新的坐标和高度值，以及图片。
            //            [self imageProcessAlgorithm];
            //            [_imageProcess processImageWithCameraImage:[self imageWithView:_fpvPreviewView] andCurrentCoordinate:_aircraftLocation andAltitude:_aircraftAltitude];
        }
    }];
}

- (void)startWaypointMission {
    weakSelf(target);
    //Start Mission
    [[self missionOperator] startMissionWithCompletion:^(NSError * _Nullable error) {
        
        weakReturn(target);
        
        if (error) {
            [target showAlertViewWithTitle:@"Start Mission Failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
        }
        else {
            [target showAlertViewWithTitle:@"Start Mission Success" withMessage:nil];
        }
    }];
}

#pragma mark - Rotate Gimbal Methods
- (void)rotateGimbal {
    
    DJICamera *camera = [self fetchCamera];
    weakSelf(target);
    [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
        weakReturn(target);
        if (!error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [target executeRotateGimbal];
            });
        }
    }];
    
}

- (void)executeRotateGimbal
{
    
    DJIGimbal *gimbal = [self fetchGimbal];
    __weak DJICamera *camera = [self fetchCamera];
    
    //Reset Gimbal at the beginning
    [gimbal resetWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"ResetGimbal Failed: %@", [NSString stringWithFormat:@"%@", error.description]);
        }
    }];
    sleep(3);
    
    //rotate the gimbal clockwise
    float yawAngle = 0;
    
    for(int i = 0; i < PHOTO_NUMBER; i++){
        
        [camera setShootPhotoMode:DJICameraShootPhotoModeSingle withCompletion:^(NSError * _Nullable error) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [camera startShootPhotoWithCompletion:nil];
            });
        }];
        
        sleep(2);
        
        NSNumber *pitchRotation = @(0);
        NSNumber *rollRotation = @(0);
        NSNumber *yawRotation = @(yawAngle);
        
        yawAngle += ROTATE_ANGLE;
        if (yawAngle > 180.0) { //Filter the angle between -180 ~ 0, 0 ~ 180
            yawAngle = yawAngle - 360;
        }
        yawRotation = @(yawAngle);
        
        DJIGimbalRotation *rotation = [DJIGimbalRotation gimbalRotationWithPitchValue:pitchRotation
                                                                            rollValue:rollRotation
                                                                             yawValue:yawRotation
                                                                                 time:1
                                                                                 mode:DJIGimbalRotationModeAbsoluteAngle];
        
        [gimbal rotateWithRotation:rotation completion:^(NSError * _Nullable error) {
        }];
        
        sleep(2);
    }
    
    weakSelf(target);
    dispatch_async(dispatch_get_main_queue(), ^{
        weakReturn(target);
        [target showAlertViewWithTitle:@"Capture Photos" withMessage:@"Capture finished"];
    });
    
}

#pragma mark --
#pragma mark Buttons Click
- (IBAction)photoCaptureBtn:(id)sender {
    [self rotateGimbal];
}

- (IBAction)wayMissionBtn:(id)sender {
    [self rotateDroneWithWaypointMissionWithCoordinate:_aircraftLocation andTargetAltitude:_aircraftAltitude];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
