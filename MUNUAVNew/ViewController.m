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
#define PHOTO_NUMBER 1
#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;

@interface ViewController ()<DJICameraDelegate, DJIPlaybackDelegate, DJISDKManagerDelegate, DJIFlightControllerDelegate, DJIVideoFeedListener, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ImageProcessingDelegate>{
    BOOL isFirstTime;
}

@property (nonatomic, assign) __block int selectedPhotoNumber;
@property (strong, nonatomic) UIAlertView* downloadProgressAlert;
@property (strong, nonatomic) UIAlertView* uploadMissionProgressAlert;
@property (strong, nonatomic) NSMutableArray* imageArray;
@property (atomic) CLLocationCoordinate2D aircraftLocation;
@property (atomic) double aircraftAltitude;
@property (atomic) DJIGPSSignalLevel gpsSignalLevel;
@property (atomic) double aircraftYaw;
@property (nonatomic) ImageProcessing *imageProcess;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.title = @"UAV Homing";
    self.aircraftLocation = kCLLocationCoordinate2DInvalid;
    self.aircraftAltitude = 11.0f;
    [[VideoPreviewer instance] setView:self.fpvPreviewView];
    [self registerApp];
    self.imageProcess = [[ImageProcessing alloc] init];
    self.imageProcess.delegate = self;
    isFirstTime = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    DJICamera *camera = [self fetchCamera];
    if (camera && camera.delegate == self) {
        [camera setDelegate:nil];
    }
    //    [self cleanVideoPreview];
    
    //    captureMissionTimer = nil;
}

- (void)registerApp {
    //Please enter the App Key in the info.plist file to register the App.
    [DJISDKManager registerAppWithDelegate:self];
}

#pragma mark DJISDKManagerDelegate Methods
- (void)productConnected:(DJIBaseProduct *)product {
    if (product) {
        DJICamera* camera = [self fetchCamera];
        if (camera != nil) {
            camera.delegate = self;
            [camera.playbackManager setDelegate:self];
        }
    }
    
    DJIFlightController *flightController = [self fetchFlightController];
    if (flightController) {
        [flightController setDelegate:self];
    }
}

- (void)appRegisteredWithError:(NSError *)error {
    NSString* message = @"Register App Successfully!";
    if (error) {
        message = @"Register App Failed! Please enter your App Key and check the network.";
    } else {
        NSLog(@"registerAppSuccess");
        
#if ENTER_DEBUG_MODE
        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"10.81.0.208"];
#else
        [DJISDKManager startConnectionToProduct];
#endif
        [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
        [[VideoPreviewer instance] start];
    }
    
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
}

#pragma mark - DJIVideoFeedListener
-(void)videoFeed:(DJIVideoFeed *)videoFeed didUpdateVideoData:(NSData *)videoData {
    [[VideoPreviewer instance] push:(uint8_t *)videoData.bytes length:(int)videoData.length];
}

#pragma mark - DJIPlaybackDelegate
- (void)playbackManager:(DJIPlaybackManager *)playbackManager didUpdatePlaybackState:(DJICameraPlaybackState *)playbackState {
    self.selectedPhotoNumber = playbackState.selectedFileCount;
}

#pragma mark - DJIFlightControllerDelegate Method
- (void)flightController:(DJIFlightController *_Nonnull)fc didUpdateState:(DJIFlightControllerState *_Nonnull)state {
    self.aircraftLocation = CLLocationCoordinate2DMake(state.aircraftLocation.coordinate.latitude, state.aircraftLocation.coordinate.longitude);
//    if (isFirstTime) {
//        isFirstTime = NO;
        [_latVLabel setText:[NSString stringWithFormat:@"%2f", state.aircraftLocation.coordinate.latitude]];
        [_lngVLabel setText:[NSString stringWithFormat:@"%2f", state.aircraftLocation.coordinate.longitude]];
        [_altiVLabel setText:[NSString stringWithFormat:@"%2f", state.aircraftLocation.altitude]];
//    }
    
    if (state.altitude >= 30) {
        [[self missionOperator] stopMissionWithCompletion:nil];
    }
//    self.gpsSignalLevel = state.GPSSignalLevel;
//    self.aircraftAltitude = state.altitude;
    self.aircraftYaw = state.attitude.yaw;
}

#pragma mark Custom Methods
- (void)cleanVideoPreview {
    [[VideoPreviewer instance] setView:nil];
    [[DJISDKManager videoFeeder].primaryVideoFeed removeListener:self];
    
    if (self.fpvPreviewView != nil) {
        [self.fpvPreviewView removeFromSuperview];
        self.fpvPreviewView = nil;
    }
}

- (DJIFlightController*)fetchFlightController {
    if (![DJISDKManager product]) {
        return nil;
    }
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).flightController;
    }
    return nil;
}

- (DJICamera*)fetchCamera {
    if (![DJISDKManager product]) {
        return nil;
    }
    return [DJISDKManager product].camera;
}

- (DJIGimbal*)fetchGimbal {
    if (![DJISDKManager product]) {
        return nil;
    }
    return [DJISDKManager product].gimbal;
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}


- (void)rotateDrone:(NSTimer *)timer {
    NSDictionary *dict = [timer userInfo];
    float yawAngle = [[dict objectForKey:@"YawAngle"] floatValue];
    
    DJIFlightController *flightController = [self fetchFlightController];
    
    DJIVirtualStickFlightControlData vsFlightCtrlData;
    vsFlightCtrlData.pitch = 0;
    vsFlightCtrlData.roll = 0;
    vsFlightCtrlData.verticalThrottle = 0;
    vsFlightCtrlData.yaw = yawAngle;
    
    flightController.isVirtualStickAdvancedModeEnabled = YES;
    
    [flightController sendVirtualStickFlightControlData:vsFlightCtrlData withCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Send FlightControl Data Failed %@", error.description);
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

- (void)executeRotateGimbal {
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

#pragma mark - Rotate Drone With Waypoint Mission Methods

- (DJIWaypointMissionOperator *)missionOperator {
    return [[DJISDKManager missionControl] waypointMissionOperator];
}

- (void)rotateDroneWithWaypointMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    //    if (CLLocationCoordinate2DIsValid(self.aircraftLocation) && self.gpsSignalLevel != DJIGPSSignalLevel0 && self.gpsSignalLevel != DJIGPSSignalLevel1) {
    //        [self uploadWaypointMission];
    //    }
    //    else {
    //        [self showAlertViewWithTitle:@"GPS signal weak" withMessage:@"Rotate drone failed"];
    //    }
    [self uploadWaypointMissionWithCoordinate:targetCoordinate andTargetAltitude:targetAltitude];
}

- (void)initializeMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    
    DJIMutableWaypointMission *mission = [[DJIMutableWaypointMission alloc] init];
    mission.maxFlightSpeed = 2.0;
    mission.autoFlightSpeed = 1.0;

    DJIWaypoint *wp1 = [[DJIWaypoint alloc] initWithCoordinate:targetCoordinate];
    wp1.altitude = 15.f;
    DJIWaypointAction *action1 = [[DJIWaypointAction alloc] initWithActionType:DJIWaypointActionTypeStay param:6000];
    [wp1 addAction:action1];
    DJIWaypoint *wp2 = [[DJIWaypoint alloc] initWithCoordinate:targetCoordinate];
    DJIWaypointAction *action2 = [[DJIWaypointAction alloc] initWithActionType:DJIWaypointActionTypeRotateGimbalPitch param:0];
    wp2.altitude = targetAltitude;
    [wp2 addAction:action2];
    [mission addWaypoint:wp1];
    [mission addWaypoint:wp2]
    ;
    [mission setFinishedAction:DJIWaypointMissionFinishedNoAction]; //Change the default action of Go Home to None
    
    [[self missionOperator] loadMission:mission];
    
    weakSelf(target);
    
    [[self missionOperator] addListenerToUploadEvent:self withQueue:dispatch_get_main_queue() andBlock:^(DJIWaypointMissionUploadEvent * _Nonnull event) {
        
        weakReturn(target);
        if (event.currentState == DJIWaypointMissionStateUploading) {
            
            NSString *message = [NSString stringWithFormat:@"Uploaded Waypoint Index: %ld, Total Waypoints: %ld" ,event.progress.uploadedWaypointIndex + 1, event.progress.totalWaypointCount];
            
            if (target.uploadMissionProgressAlert == nil) {
                target.uploadMissionProgressAlert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
                [target.uploadMissionProgressAlert show];
            } else {
                [target.uploadMissionProgressAlert setMessage:message];
            }
        } else if (event.currentState == DJIWaypointMissionStateReadyToExecute){
            
            [target.uploadMissionProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
            target.uploadMissionProgressAlert = nil;
            
//            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Upload Mission Finished" message:nil preferredStyle:UIAlertControllerStyleAlert];
//            UIAlertAction *startMissionAction = [UIAlertAction actionWithTitle:@"Start Mission" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [target startWaypointMission];
//            }];
//            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:nil];
//            [alert addAction:cancelAction];
//            [alert addAction:startMissionAction];
//            [target presentViewController:alert animated:YES completion:nil];
        }
    }];
    
    [[self missionOperator] addListenerToFinished:self withQueue:dispatch_get_main_queue() andBlock:^(NSError * _Nullable error) {
        weakReturn(target);
        if (error) {
            [target showAlertViewWithTitle:@"Mission Execution Failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
        } else {
//            [target showAlertViewWithTitle:@"Mission Execution Finished" withMessage:nil];
            [_statusLabel setText:@"Mission Execution Finished"];
            //                飞行完成后，回传新的坐标和高度值，以及图片。
            [self imageProcessAlgorithm];
//            [_imageProcess processImageWithCameraImage:[self imageWithView:_fpvPreviewView] andCurrentCoordinate:_aircraftLocation andAltitude:_aircraftAltitude];
        }
    }];
}

- (void)uploadWaypointMissionWithCoordinate:(CLLocationCoordinate2D)targetCoordinate andTargetAltitude:(double)targetAltitude {
    [self initializeMissionWithCoordinate:targetCoordinate andTargetAltitude:targetAltitude];
    weakSelf(target);
    [[self missionOperator] uploadMissionWithCompletion:^(NSError * _Nullable error) {
        weakReturn(target);
        if (error) {
            NSLog(@"%@", [NSString stringWithFormat:@"Upload Mission Failed: %@", [NSString stringWithFormat:@"%@", error.description]]);
            [_statusLabel setText:[NSString stringWithFormat:@"Upload Mission Failed: %@", [NSString stringWithFormat:@"%@", error.description]]];
        } else {
            NSLog(@"Upload Mission Finished");
            [_statusLabel setText:@"Upload Mission Finished"];
        }
    }];
}

- (void)startWaypointMission {
    weakSelf(target);
    //Start Mission
    [[self missionOperator] startMissionWithCompletion:^(NSError * _Nullable error) {
        weakReturn(target);
        if (error) {
//            [target showAlertViewWithTitle:@"Start Mission Failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
            [_statusLabel setText:@"Start Mission Failed"];
        } else {
//            [target showAlertViewWithTitle:@"Start Mission Success" withMessage:nil];
            [_statusLabel setText:@"Start Mission Success"];
        }
    }];
}

#pragma mark - Select the lastest photos for Panorama
- (void)selectPhotosForPlaybackMode {
    weakSelf(target);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        weakReturn(target);
        DJICamera *camera = [target fetchCamera];
        [camera.playbackManager enterMultiplePreviewMode];
        sleep(1);
        [camera.playbackManager enterMultipleEditMode];
        sleep(1);
        
        while (target.selectedPhotoNumber != PHOTO_NUMBER) {
            [camera.playbackManager selectAllFilesInPage];
            sleep(1);
            
            if(target.selectedPhotoNumber > PHOTO_NUMBER){
                for(int unselectFileIndex = 0; target.selectedPhotoNumber != PHOTO_NUMBER; unselectFileIndex++){
                    [camera.playbackManager toggleFileSelectionAtIndex:unselectFileIndex];
                    sleep(1);
                }
                break;
            }
            else if(target.selectedPhotoNumber < PHOTO_NUMBER) {
                [camera.playbackManager goToPreviousMultiplePreviewPage];
                sleep(1);
            }
        }
        [target downloadPhotosForPlaybackMode];
    });
}

#pragma mark - Download the selected photos
- (void)downloadPhotosForPlaybackMode {
    __block int finishedFileCount = 0;
    __block NSMutableData* downloadedFileData;
    __block long totalFileSize;
    __block NSString* targetFileName;
    
    self.imageArray=[NSMutableArray new];
    
    DJICamera *camera = [self fetchCamera];
    if (camera == nil) return;
    
    weakSelf(target);
    [camera.playbackManager downloadSelectedFilesWithPreparation:^(NSString * _Nullable fileName, DJIDownloadFileType fileType, NSUInteger fileSize, BOOL * _Nonnull skip) {
        
        totalFileSize=(long)fileSize;
        downloadedFileData=[NSMutableData new];
        targetFileName=fileName;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            weakReturn(target);
            [target showDownloadProgressAlert];
            [target.downloadProgressAlert setTitle:[NSString stringWithFormat:@"Download (%d/%d)", finishedFileCount + 1, PHOTO_NUMBER]];
            [target.downloadProgressAlert setMessage:[NSString stringWithFormat:@"FileName:%@ FileSize:%0.1fKB Downloaded:0.0KB", fileName, fileSize / 1024.0]];
        });
        
    } process:^(NSData * _Nullable data, NSError * _Nullable error) {
        
        weakReturn(target);
        [downloadedFileData appendData:data];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [target.downloadProgressAlert setMessage:[NSString stringWithFormat:@"FileName:%@ FileSize:%0.1fKB Downloaded:%0.1fKB", targetFileName, totalFileSize / 1024.0, downloadedFileData.length / 1024.0]];
        });
        
    } fileCompletion:^{
        weakReturn(target);
        finishedFileCount++;
        
        UIImage *downloadPhoto=[UIImage imageWithData:downloadedFileData];
        [target.imageArray addObject:downloadPhoto];
        
    } overallCompletion:^(NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
            target.downloadProgressAlert = nil;
            
            if (error) {
                [self showAlertViewWithTitle:@"Download failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
            } else {
                [self showAlertViewWithTitle:[NSString stringWithFormat:@"Download (%d/%d)", finishedFileCount, PHOTO_NUMBER] withMessage:@"download finished"];
            }
            
            DJICamera *camera = [target fetchCamera];
            [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [self showAlertViewWithTitle:@"Set CameraMode to ShootPhoto Failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
                }
            }];
        });
    }];
}

- (void)loadMediaListsForMediaDownloadMode {
    DJICamera *camera = [self fetchCamera];
    [self showDownloadProgressAlert];
    [self.downloadProgressAlert setTitle:[NSString stringWithFormat:@"Refreshing file list. "]];
    [self.downloadProgressAlert setMessage:[NSString stringWithFormat:@"Loading..."]];
    
    weakSelf(target);
    [camera.mediaManager refreshFileListWithCompletion:^(NSError * _Nullable error) {
        weakReturn(target);
        if (error) {
            [target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
            target.downloadProgressAlert = nil;
            NSLog(@"Refresh file list failed: %@", error.description);
        }
        else {
            [target downloadPhotosForMediaDownloadMode];
        }
    }];
}

- (void)downloadPhotosForMediaDownloadMode {
    __block int finishedFileCount = 0;
    
    self.imageArray=[NSMutableArray new];
    
    DJICamera *camera = [self fetchCamera];
    NSArray<DJIMediaFile *> *files = [camera.mediaManager fileListSnapshot];
    if (files.count < PHOTO_NUMBER) {
        [self.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
        self.downloadProgressAlert = nil;
        [self showAlertViewWithTitle:@"Download failed" withMessage:[NSString stringWithFormat:@"Not enough photos are taken. "]];
        return;
    }
    
    [camera.mediaManager.taskScheduler resumeWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            [self.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
            self.downloadProgressAlert = nil;
            [self showAlertViewWithTitle:@"Download failed" withMessage:[NSString stringWithFormat:@"Resume file task scheduler failed. "]];
        }
    }];
    
    [self.downloadProgressAlert setTitle:[NSString stringWithFormat:@"Downloading..."]];
    [self.downloadProgressAlert setMessage:[NSString stringWithFormat:@"Download (%d/%d)", 0, PHOTO_NUMBER]];
    
    weakSelf(target);
    for (int i = (int)files.count - PHOTO_NUMBER; i < files.count; i++) {
        DJIMediaFile *file = files[i];
        
        DJIFetchMediaTask *task = [DJIFetchMediaTask taskWithFile:file content:DJIFetchMediaTaskContentPreview andCompletion:^(DJIMediaFile * _Nonnull file, DJIFetchMediaTaskContent content, NSError * _Nullable error) {
            weakReturn(target);
            if (error) {
                [target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
                target.downloadProgressAlert = nil;
                [self showAlertViewWithTitle:@"Download failed" withMessage:[NSString stringWithFormat:@"Download file %@ failed. ", file.fileName]];
            } else {
                [target.imageArray addObject:file.preview];
                finishedFileCount++;
                [target.downloadProgressAlert setMessage:[NSString stringWithFormat:@"Download (%d/%d)", finishedFileCount, PHOTO_NUMBER]];
                
                if (finishedFileCount == PHOTO_NUMBER) {
                    [target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
                    target.downloadProgressAlert = nil;
                    [self showAlertViewWithTitle:@"Download Complete" withMessage:[NSString stringWithFormat:@"%d files have been downloaded. ", PHOTO_NUMBER]];
                    [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
                        if (error) {
                            [self showAlertViewWithTitle:@"Set CameraMode to ShootPhoto Failed" withMessage:[NSString stringWithFormat:@"%@", error.description]];
                        }
                    }];
                }
            }
        }];
        [camera.mediaManager.taskScheduler moveTaskToEnd:task];
    }
}

- (void)showDownloadProgressAlert {
    if (self.downloadProgressAlert == nil) {
        self.downloadProgressAlert = [[UIAlertView alloc] initWithTitle:@"" message:@"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
        [self.downloadProgressAlert show];
    }
}

#pragma mark
#pragma mark - ImageProcessDelegate
- (void)imageProcessdSuccessWithTargetCoordiante:(CLLocationCoordinate2D)targetCoordiante andTargetAltitude:(double)targetAltitude andXRotateAngle:(double)xRotateAngle {
//    [self showAlertViewWithTitle:@"Image Processed!" withMessage:@"123"];
    [_statusLabel setText:@"Image Processed!"];
    [_calcVLabel setText:[NSString stringWithFormat:@"Calculate Location: Lat:%2f, Lng:%2f, Alt:%2f", targetCoordiante.latitude, targetCoordiante.longitude, targetAltitude]];
    [self storeGPSLocationInfoToFileWithLat:targetCoordiante.latitude andLng:targetCoordiante.longitude andAlt:targetAltitude];
    [self rotateDroneWithWaypointMissionWithCoordinate:targetCoordiante andTargetAltitude:targetAltitude];
}


#pragma mark -
#pragma mark UIImagePickerControllerDelegate methods
#pragma mark 取到了原图和飞机图
//完成选择图片
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    //加载图片
    NSData *imageData = UIImagePNGRepresentation(image);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:imageData forKey:@"originalImage"];
    NSLog(@"%f", image.size.width);
    [_captureImage setImage:image];
    //选择框消失
        [_captureImage setImage:image];
    [picker dismissViewControllerAnimated:YES completion:nil];
}
//取消选择图片
-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark --
#pragma Process Image
- (void)imageProcessAlgorithm {
    NSLog(@"aaaaa");
    [[self missionOperator] stopMissionWithCompletion:nil];
//    [self rotateDroneWithWaypointMissionWithCoordinate:_aircraftLocation andTargetAltitude:_aircraftAltitude];
    [[VideoPreviewer instance] snapshotPreview:^(UIImage *snapImage){
        NSLog(@"%f", snapImage.size.width);
        NSLog(@"%f", snapImage.size.height);
        UIImage *currentImage = snapImage;
        UIImageWriteToSavedPhotosAlbum(snapImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
        [_imageProcess processImageWithCameraImage:currentImage andCurrentCoordinate:_aircraftLocation andAltitude:_aircraftAltitude];
    }];
   
//    [self rotateDroneWithWaypointMissionWithCoordinate:_aircraftLocation andTargetAltitude:_aircraftAltitude];
}

- (void)selectPhotoFromAblum {
    UIImagePickerController *picker = [[UIImagePickerController alloc]init];
    //设置图片源(相簿)
    picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    //设置代理
    picker.delegate = self;
    //设置可以编辑
    picker.allowsEditing = YES;
    //打开拾取器界面
    [self presentViewController:picker animated:YES completion:nil];
}

- (UIImage *)imageWithView:(UIView *)view {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size,   view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSString *msg = nil ;
    if(error != NULL){
        msg = @"保存图片失败" ;
    }else{
        msg = @"保存图片成功" ;
    }
}

#pragma mark --
#pragma mark Buttons Click
- (IBAction)photoCaptureBtn:(id)sender {
    [self selectPhotoFromAblum];
}

- (IBAction)wayMissionBtn:(id)sender {
    [self imageProcessAlgorithm];
//    [self rotateDroneWithWaypointMissionWithCoordinate:self.aircraftLocation andTargetAltitude:self.aircraftAltitude];
}

- (IBAction)rotateGimBtn:(id)sender {
    //    [self rotateGimbal];
    [[self missionOperator] stopMissionWithCompletion:nil];
}

- (IBAction)captureAPhoto:(id)sender {
    [[VideoPreviewer instance] snapshotPreview:^(UIImage *snapImage){
        NSLog(@"%f", snapImage.size.width);
        NSLog(@"%f", snapImage.size.height);
        UIImageWriteToSavedPhotosAlbum(snapImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
        _captureImage.image = snapImage;
        
        [self storeGPSLocationInfoToFileWithLat:[_latVLabel.text doubleValue] andLng:[_lngVLabel.text doubleValue] andAlt:[_altiVLabel.text doubleValue]];
    }];
}

- (IBAction)startAlgorithmBtn:(id)sender {
    [self imageProcessAlgorithm];
}

- (void)storeGPSLocationInfoToFileWithLat:(double)lat andLng:(double)lng andAlt:(double)alt {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    
    NSString *fileName = @"Location.log"; // 注意不是NSData!
    NSString *logFilePath = [documentDirectory stringByAppendingPathComponent:fileName];
    NSString *storedStr = [NSString stringWithContentsOfFile:logFilePath encoding:NSUTF8StringEncoding error:nil];
    if (storedStr == nil) {
        storedStr = @"";
    }
    NSString *locationStr = [storedStr stringByAppendingString:[NSString stringWithFormat:@"\nLat:%f, Lng:%f, Alt:%f", lat, lng, alt]];
    [locationStr writeToFile:logFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end


