//
//  TargetSelector.swift
//  SmartMagnifier
//
//  Created by occamlab on 12/24/20.
//

import Foundation
import UIKit
import ARKit

class TargetSelector : UIViewController {
    var arFrame : ARFrame!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // need to rotate this by 90 degrees
        imageView.image = UIImage(pixelBuffer: arFrame.capturedImage)
    }
}

