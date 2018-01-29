//
//  ImageProcessing.m
//  uavmun
//
//  Created by  sy2036 on 2017-10-18.
//  Copyright � 2017 vclab. All rights reserved.
//

#import "ImageProcessing.h"
#import "OpenCVConversion.h"


#include<iostream>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/features2d/features2d.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#import <opencv2/stitching.hpp>
#import <opencv2/imgcodecs/ios.h>
//#import <opencv2/opencv.hpp>
#include <math.h>

using namespace std;
using namespace cv;

void find_feature_matches (
                           const Mat& img_1, const Mat& img_2,
                           vector<KeyPoint>& keypoints_1,
                           vector<KeyPoint>& keypoints_2,
                           vector< DMatch >& good_matches);

void pose_estimation_2d2d (
                           const vector<KeyPoint>& keypoints_1,
                           const vector<KeyPoint>& keypoints_2,
                           vector< DMatch >& matches,
                           Mat& R, Mat& t);

const Mat K = ( Mat_<double> ( 3,3 ) << 517.306408, 0, 318.643040, 0, 516.469215, 255.313989, 0, 0, 1 );

const double scaleReal = 0.2;

const double EARTH_RADIUS = 6377830;

bool isRotationMatrix(Mat &R);

Vec3f rotationMatrixToEulerAngles(Mat &R);

@interface ImageProcessing () {
    double scale;
    UIImage *tempImage;
}

//  Default is 0;
@property (nonatomic, assign) int currentCalculateTimes;

@end

@implementation ImageProcessing

- (id)init {
    self = [super init];
    self.currentCalculateTimes = 0;
    scale = 0.f;
    return self;
}

//- (void)setOriginalImage:(UIImage *)originalImage {
//    _originalImage = originalImage;
//    NSLog(@"%f", _originalImage.size.width);
//}
//
//- (void)setImageData:(NSData *)imageData {
//    _imageData = imageData;
//    UIImage *oImage = [[UIImage alloc] initWithData:_imageData];
//    NSLog(@"%f", oImage.size.width);
//}

- (bool)processImageWithCameraImage:(UIImage *)tagetImage andCurrentCoordinate:(CLLocationCoordinate2D)currentCoordinate andAltitude:(double)altitude {
    NSLog(@"------");
    CLLocationCoordinate2D targetCoordinate = currentCoordinate;
    double targetAltitude = altitude;
    
    NSData *imData = [[NSUserDefaults standardUserDefaults] objectForKey:@"originalImage"];
    
    UIImage *oImage = [[UIImage alloc] initWithData:imData];
    cv::Mat matTargetImage = [OpenCVConversion cvMatFromUIImage:tagetImage];
    cv::Mat matOriginalImage = [OpenCVConversion cvMatFromUIImage:oImage];
    NSLog(@"Target: %d", matTargetImage.rows);
    NSLog(@"Original: %d", matOriginalImage.rows);
    
//    const Mat ref_image=imread ( "/home/hao/UAV_Homing/color2/1.png", CV_LOAD_IMAGE_COLOR );
//    const Mat curr_image1 = imread ( "/home/hao/UAV_Homing/color2/2.png", CV_LOAD_IMAGE_COLOR );
    vector< KeyPoint > keypoints_1, keypoints_2;
    
    vector< DMatch > matches12;
    find_feature_matches ( matOriginalImage, matTargetImage, keypoints_1, keypoints_2, matches12);
    
    Mat R12,t12;
    pose_estimation_2d2d ( keypoints_1, keypoints_2, matches12, R12, t12);
    
    Vec3f RPYangle= rotationMatrixToEulerAngles(R12);
    
    Point3d moveDistance (t12.at<double> (1,0), t12.at<double> (2,0), t12.at<double> (3,0) );
    if (0 == _currentCalculateTimes) {
        // 如果第一次运行，则位移；
        // ToDo:
        targetAltitude += scaleReal;
        self.currentCalculateTimes++;
    } else if (1 == _currentCalculateTimes) {
        //  计算单位
        //scaleReal=0.2;
        //修改altitude（+/—0.2m）,经纬度不变，回传给controller
        double scaleDis = moveDistance.z;
        scale = scaleReal/scaleDis;
    } else {
        //  更新Target Coordinate and Altitude;
        
        
        ///////////   double diff=2*asin(sqrt(pow(sin((lat1*M_PI/180.0-lat2*M_PI/180.0)/2),2)+cos(lat1*M_PI/180.0)*cos(lat2*M_PI/180.0)*pow(sin((lon1*M_PI/180.0-lon2*M_PI/180.0)/2),2)));
        //new GPS:
        //latNew= latOld + (moveDistance.x)*scale/EARTH_RADIUS*180.0/M_PI;
        //lonNew= lonOld + (2*asin(sin((moveDistance.y)*scale/(2*EARTH_RADIUS))/cos(latOld*M_PI/180.0)))*180.0/M_PI;
        //altNew= altOld + (moveDistance.z)*scale;
        
        
        targetCoordinate.latitude = currentCoordinate.latitude + (moveDistance.x)*scale/EARTH_RADIUS*180.0/M_PI;
        targetCoordinate.longitude = currentCoordinate.longitude + (2*asin(sin((moveDistance.y)*scale/(2*EARTH_RADIUS))/cos(currentCoordinate.latitude*M_PI/180.0)))*180.0/M_PI;
        targetAltitude = targetAltitude + (moveDistance.z)*scale;
        if((pow(moveDistance.x/scale,2)+pow(moveDistance.y/scale,2)+pow(moveDistance.z/scale,2))<0.05) {
           return NO;
        }
    }
    
    cout<<"RPYangle is "<<RPYangle<<endl;
    cout<<"R12 is "<<R12<<endl;
    cout<<"t12 is "<<t12<<endl;
    
    if ([self.delegate respondsToSelector:@selector(imageProcessdSuccessWithTargetCoordiante:andTargetAltitude:andXRotateAngle:)]) {
        [self.delegate imageProcessdSuccessWithTargetCoordiante:targetCoordinate andTargetAltitude:targetAltitude andXRotateAngle:RPYangle[2]];
    }
    
    return YES;
}

//- (void)imageProcess {
//
//    const Mat ref_image=imread ( "/home/hao/UAV_Homing/color2/1.png", CV_LOAD_IMAGE_COLOR );
//    const Mat curr_image1 = imread ( "/home/hao/UAV_Homing/color2/2.png", CV_LOAD_IMAGE_COLOR );
//    vector< KeyPoint > keypoints_1, keypoints_2;
//
//    vector< DMatch > matches12;
//    find_feature_matches ( ref_image, curr_image1, keypoints_1, keypoints_2, matches12);
//
//    Mat R12,t12;
//    pose_estimation_2d2d ( keypoints_1, keypoints_2, matches12, R12, t12);
//
//    Vec3f RPYangle= rotationMatrixToEulerAngles(R12);
//    cout<<"RPYangle is "<<RPYangle<<endl;
//    cout<<"R12 is "<<R12<<endl;
//    cout<<"t12 is "<<t12<<endl;
//
//    self.delegate;
//
//    return 0;
//}

// Checks if a matrix is a valid rotation matrix.
bool isRotationMatrix(Mat &R)
{
    Mat Rt;
    transpose(R, Rt);
    Mat shouldBeIdentity = Rt * R;
    Mat I = Mat::eye(3,3, shouldBeIdentity.type());
     
    return  norm(I, shouldBeIdentity) < 1e-6;
     
}
 
// Calculates rotation matrix to euler angles
// The result is the same as MATLAB except the order
// of the euler angles ( x and z are swapped ).
Vec3f rotationMatrixToEulerAngles(Mat &R)
{
 
    assert(isRotationMatrix(R));
     
    float sy = sqrt(R.at<double>(0,0) * R.at<double>(0,0) +  R.at<double>(1,0) * R.at<double>(1,0) );
 
    bool singular = sy < 1e-6; // If
 
    float x, y, z;
    if (!singular)
    {
        x = atan2(R.at<double>(2,1) , R.at<double>(2,2));
        y = atan2(-R.at<double>(2,0), sy);
        z = atan2(R.at<double>(1,0), R.at<double>(0,0));
    }
    else
    {
        x = atan2(-R.at<double>(1,2), R.at<double>(1,1));
        y = atan2(-R.at<double>(2,0), sy);
        z = 0;
    }
    return Vec3f(x*180/M_PI, y*180/M_PI, z*180/M_PI);
     
     
     
}

void find_feature_matches ( const Mat& img_1, const Mat& img_2,
                           vector<KeyPoint>& keypoints_1,
                           vector<KeyPoint>& keypoints_2,
                           vector< DMatch >& good_matches)
{
    Mat descriptors_1, descriptors_2;
    Ptr<FeatureDetector> detector = ORB::create(800,1.2,4);
    Ptr<DescriptorExtractor> descriptor = ORB::create(800,1.2,4);
    
    detector->detect ( img_1,keypoints_1 );
    detector->detect ( img_2,keypoints_2 );
    
    descriptor->compute ( img_1, keypoints_1, descriptors_1 );
    descriptor->compute ( img_2, keypoints_2, descriptors_2 );
    vector< DMatch > matches;
    
//    cv::FlannBasedMatcher matcher ( new cv::flann::LshIndexParams ( 5,10,2 ));
    BFMatcher matcher;
    matcher.match ( descriptors_1, descriptors_2, matches );
    
    double min_dis = std::min_element (
                                       matches.begin(), matches.end(),
                                       [] ( const cv::DMatch& m1, const cv::DMatch& m2 )
                                       {
                                           return m1.distance < m2.distance;
                                       } )->distance;
    
    for ( DMatch &m:matches)
    {
        if (m.distance < max<double> ( min_dis*2.0, 30 ) )
        {
            good_matches.push_back ( m );
        }
    }
}

void pose_estimation_2d2d (
                           const vector<KeyPoint>& keypoints_1,
                           const vector<KeyPoint>& keypoints_2,
                           vector< DMatch >& matches,
                           Mat& R, Mat& t)
{
    
    vector<Point2f> points1,points2;
    
    for ( DMatch m:matches)
    {
        points1.push_back(keypoints_1[m.queryIdx].pt);
        points2.push_back(keypoints_2[m.trainIdx].pt);
    }
    
    Mat essential_matrix, mask;
    essential_matrix= findEssentialMat ( points1, points2, K, RANSAC, 0.999, 1.0, mask);
    recoverPose ( essential_matrix, points1, points2, K, R, t, mask);
}

@end
