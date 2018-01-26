//
//  UIImage+Additions.h
//  uavmun
//
//  Created by  sy2036 on 2017-10-19.
//  Copyright © 2017 vclab. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Additions)

- (UIImage *)scaletoSize:(CGSize)size;

- (UIImage*)getSubImage:(CGRect)rect;

@end
