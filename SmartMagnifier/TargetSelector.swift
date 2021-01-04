//
//  TargetSelector.swift
//  SmartMagnifier
//
//  Created by occamlab on 12/24/20.
//

import Foundation
import UIKit
import ARKit

class TargetSelector : UIViewController, UIScrollViewDelegate {
    var arFrame : ARFrame!
    var coreImage: CIImage!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // need to rotate this by 90 degrees
        coreImage = CIImage(cvPixelBuffer: arFrame.capturedImage).oriented(.right)
        imageView.image = UIImage(ciImage: coreImage)
        
        scrollView.delegate = self
        scrollView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height*0.8)
        scrollView.backgroundColor = UIColor(red: 90, green: 90, blue: 90, alpha: 0.90)
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.flashScrollIndicators()

        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 10.0
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress))
        scrollView.addGestureRecognizer(longPressGesture)
    }
    
    @objc func longPress(recognizer:UILongPressGestureRecognizer){
        switch recognizer.state {
        case .ended:
            print("ended", recognizer.location(in: imageView))
        default: break
        }
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

