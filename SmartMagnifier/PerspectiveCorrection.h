//
//  PerspectiveCorrection.h
//  SmartMagnifier
//
//  Created by Paul Ruvolo on 1/6/21.
//

#ifndef PerspectiveCorrection_h
#define PerspectiveCorrection_h

#include <UIKit/UIKit.h>
#include <simd/simd.h>
#import <Foundation/Foundation.h>


@interface PerspectiveCorrection : NSObject

+ (UIImage*)perspectiveCorrection:(UIImage *)img : (simd_float3)extent : (const CGPoint [4])cornerPixels : (CGPoint)centerPixel;

@end
    
#endif /* PerspectiveCorrection_h */
