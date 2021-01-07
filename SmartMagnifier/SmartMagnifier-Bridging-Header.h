//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <simd/simd.h>

@interface PerspectiveCorrection : NSObject

+ (UIImage*)perspectiveCorrection:(UIImage *)img : (simd_float3)extent : (const CGPoint [4])cornerPixels : (CGPoint)centerPixel;

@end
