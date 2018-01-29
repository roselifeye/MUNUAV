//
//  ViewController.h
//  MUNUAVNew
//
//  Created by  sy2036 on 2018-01-21.
//  Copyright © 2018 vclab. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (nonatomic, weak) IBOutlet UIView *fpvPreviewView;
@property (nonatomic, weak) IBOutlet UIButton *photoBtn;
@property (nonatomic, weak) IBOutlet UIButton *wayMissionBtn;
@property (nonatomic, weak) IBOutlet UIButton *rotateGimbalBtn;
@property (nonatomic, weak) IBOutlet UIImageView *captureImage;

@property (weak, nonatomic) IBOutlet UILabel *latVLabel;
@property (weak, nonatomic) IBOutlet UILabel *lngVLabel;
@property (weak, nonatomic) IBOutlet UILabel *altiVLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel *calcVLabel;
@end

