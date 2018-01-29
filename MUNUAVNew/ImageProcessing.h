//
//  ImageProcessing.h
//  uavmun
//
//  Created by  sy2036 on 2017-10-18.
//  Copyright © 2017 vclab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@protocol ImageProcessingDelegate <NSObject>

@optional

- (void)imageProcessdSuccessWithTargetCoordiante:(CLLocationCoordinate2D)targetCoordiante andTargetAltitude:(double)targetAltitude andXRotateAngle:(double)xRotateAngle;

@end

@interface ImageProcessing : NSObject

//@property (nonatomic, strong) UIImage *originalImage;
//@property (nonatomic, strong) NSData *imageData;

@property (nonatomic, weak) id<ImageProcessingDelegate> delegate;
- (bool)processImageWithCameraImage:(UIImage *)tagetImage andCurrentCoordinate:(CLLocationCoordinate2D)currentCoordinate andAltitude:(double)altitude;

@end
