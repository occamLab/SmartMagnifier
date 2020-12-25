//
//  ImageExtensions.swift
//  SmartMagnifier
//
//  Created by occamlab on 12/25/20.
//

import Foundation
import UIKit
import VideoToolbox

extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)

        guard let cgImageUnwrapped = cgImage else {
            return nil
        }

        self.init(cgImage: cgImageUnwrapped)
    }
}
