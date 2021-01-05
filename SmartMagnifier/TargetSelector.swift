//
//  TargetSelector.swift
//  SmartMagnifier
//
//  Created by occamlab on 12/24/20.
//

import Foundation
import UIKit
import ARKit
import ImageCoordinateSpace
import Accelerate

protocol TargetSelectorDelegate {
    func didSelect3DPlanarTarget(anchor: ARPlaneAnchor, tapLocation: simd_float3)
}

class TargetSelector : UIViewController, UIScrollViewDelegate {
    var arFrame : ARFrame!
    var coreImage: CIImage!
    var rawImageTransform: CGAffineTransform!
    var sceneView: ARSCNView!
    var delegate: TargetSelectorDelegate?

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // TODO: in landscape you wouldn't need to change the orientation.  This might have downstream issues when calculating raycasts
        let desiredOrientation = CGImagePropertyOrientation.right
        coreImage = CIImage(cvPixelBuffer: arFrame.capturedImage).oriented(desiredOrientation)
        imageView.image = UIImage(ciImage: coreImage)
        rawImageTransform = coreImage.orientationTransform(for: desiredOrientation)
        
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
            let imageSpace = imageView.contentSpace()
            let imageCoordinate = imageSpace.convert(recognizer.location(in: imageView), from: imageView)
            let arFrameCoordinate = imageCoordinate.applying(rawImageTransform)
            // use negative to make sure the vector points in the direction in front of the camera (which is negative z)
            let rayDirection = -arFrame.camera.intrinsics.inverse * simd_float3(Float(arFrameCoordinate.x), Float(arFrameCoordinate.y), 1.0)
            
            // TODO: not sure why this hack is necessary :(
            let rayDirectionHack = simd_float3(-rayDirection.x, rayDirection.y, rayDirection.z)

            let castOrigin = simd_float3(arFrame.camera.transform.columns.3.x,
                                         arFrame.camera.transform.columns.3.y,
                                         arFrame.camera.transform.columns.3.z)
            let transformedDirectionWithExtraDimension = arFrame.camera.transform * simd_float4(rayDirectionHack.x, rayDirectionHack.y, rayDirectionHack.z, 0)
            let castDirection = simd_float3(transformedDirectionWithExtraDimension.x,
                                            transformedDirectionWithExtraDimension.y,
                                            transformedDirectionWithExtraDimension.z)
            let query = ARRaycastQuery(origin: castOrigin, direction: castDirection, allowing: .existingPlaneGeometry, alignment: .any)
            guard let result = sceneView.session.raycast(query).first,
                  let planeAnchor = result.anchor as? ARPlaneAnchor  else {
                return
            }
            delegate?.didSelect3DPlanarTarget(anchor: planeAnchor, tapLocation: simd_float3(result.worldTransform.columns.3.x, result.worldTransform.columns.3.y, result.worldTransform.columns.3.z))
            dismiss(animated: true)
        default: break
        }
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

