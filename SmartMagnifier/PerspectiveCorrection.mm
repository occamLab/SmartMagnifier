//
//  PerspectiveCorrection.m
//  SmartMagnifier
//
//  Created by Paul Ruvolo on 1/6/21.
//

#import "PerspectiveCorrection.h"
#import <Foundation/Foundation.h>

#ifdef __cplusplus
#import <opencv2/core.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/calib3d.hpp>
#include <algorithm>
#include <iostream>
#import <opencv2/imgcodecs/ios.h>
#endif

@interface PerspectiveCorrection ()
@end

@implementation PerspectiveCorrection

// Note: cornerPixels are stored in an order based on the 3D coordinate system of the projected plane ([lowx, lowz], [lowx, highz], [highx, lowz], [highx, highz]
// TODO: this might cause images to flip when corrected.  We might need to identify / order points in terms of the screen coordinates (rather than the 3d cooordinates)
+ (UIImage*)perspectiveCorrection:(UIImage *)img : (simd_float3)extent : (const CGPoint [4])cornerPixels : (CGPoint)centerPixel {
    cv::Point2f sourcePoints[4];
    cv::Point2f destPoints[4];
    cv::Mat cvInputImg;
    int bottom = std::min((int)cornerPixels[0].y, cvInputImg.rows);
    int top = std::max((int)cornerPixels[0].y, 0);
    int left = std::max((int)cornerPixels[0].x, 0);
    int right = std::min((int)cornerPixels[0].x, cvInputImg.cols);

    UIImageToMat(img, cvInputImg);
    
    for (int i = 0; i < 4; i++) {
        sourcePoints[i] = cv::Point2f(cornerPixels[i].x, cornerPixels[i].y);
        if (cornerPixels[i].y > bottom) {
            bottom = std::min((int)cornerPixels[i].y, cvInputImg.rows);
        }
        if (cornerPixels[i].y < top) {
            top = std::max((int)cornerPixels[i].y, 0);
        }
        if (cornerPixels[i].x > right) {
            right = std::min((int)cornerPixels[i].x, cvInputImg.cols);
        }
        if (cornerPixels[i].x < left) {
            left = std::max((int)cornerPixels[i].x, 0);
        }
    }
    for (int i = 0; i < 4; i++) {
        sourcePoints[i] = cv::Point2f(cornerPixels[i].x-left, cornerPixels[i].y-top);
    }
    std::cout << top << ", " << bottom << ", " << left << ", " << right << std::endl;
    std::cout << cvInputImg.rows << ", " << cvInputImg.cols << std::endl;
    
    // plane is entirely off screen
    if (top >= cvInputImg.rows || left >= cvInputImg.cols || bottom <= 0 || right <= 0) {
        return img;
    }
    cv::Mat roi(cvInputImg, cv::Range(top, bottom), cv::Range(left, right));
    cv::Mat destCVImg = cvInputImg.clone();

    // set the destination points based on the size of the input image
    // TODO: scale based on aspect ratio of the plane, center the focus pixel and zoom appropriately
    destPoints[0] = cv::Point2f(0,0);
    destPoints[1] = cv::Point2f(0,destCVImg.cols-1);
    destPoints[2] = cv::Point2f(destCVImg.rows-1,0);
    destPoints[3] = cv::Point2f(destCVImg.rows-1,destCVImg.cols-1);
    
    // TODO: this is giving us a transform that positions the entire plane in the image, but only renders the part that is visible.  This results in the visible portion being quite small if you are close up to the plane and the plane is large.  We could do something like make the image higher resolution when this situation occurs (although it might slow down various conversions).  Alternatively we could contract the source points until they fit around the image (this will be complicated geometrically).
    
    // TODO: another approach is to figure out where on the plane the region of interest lies and create the destination points based on that (the destination points will no longer be a rectangle)
    cv::Mat perspectiveTransform = cv::getPerspectiveTransform(sourcePoints, destPoints);

    // grab ROI from image that contains the plane (rectangular bounding box), do the mapping and then throw away the part that is not part of the plane (this last part will take some math... maybe check out source code)
    
    cv::warpPerspective(roi.clone(), destCVImg, perspectiveTransform, cv::Size(destCVImg.rows, destCVImg.cols));
    
    UIImage* transformedImage = MatToUIImage(destCVImg);
    return transformedImage;
}


@end
