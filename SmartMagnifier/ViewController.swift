//
//  ViewController.swift
//  SmartMagnifier
//
//  Created by occamlab on 12/24/20.
//

import UIKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, TargetSelectorDelegate {
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var magnifiedImage: UIImageView!
    var createdCorners = false
    var configuration: ARWorldTrackingConfiguration!
    var magnificationPlane: ARPlaneAnchor?
    var magnificationTarget: simd_float3?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        createARSessionConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        sceneView.session.delegate = self
    }
    
    /// Create a new ARSession.
    func createARSessionConfiguration() {
        configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.isAutoFocusEnabled = false
        sceneView.delegate = self
        sceneView.debugOptions = [.showWorldOrigin]
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a custom object to visualize the plane geometry and extent.
        let plane = Plane(anchor: planeAnchor, in: sceneView)
        
        // Add the visualization to the ARKit-managed node so that it tracks
        // changes in the plane anchor as plane estimation continues.
        node.addChildNode(plane)
    }
    
    /// - Tag: UpdateARContent
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? Plane
            else { return }
        
        // Update ARSCNPlaneGeometry to the anchor's new estimated shape.
        if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }

        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.extentNode.simdPosition = planeAnchor.center
        }
        
        // Update the plane's classification and the text position
        if #available(iOS 12.0, *),
            let classificationNode = plane.classificationNode,
            let classificationGeometry = classificationNode.geometry as? SCNText {
            let currentClassification = planeAnchor.classification.description
            if let oldClassification = classificationGeometry.string as? String, oldClassification != currentClassification {
                classificationGeometry.string = currentClassification
                classificationNode.centerAlign()
            }
        }
        
    }
    
    ///Called when there is a change in tracking state.  This is important for both announcing tracking errors to the user and also to triggering some app state transitions.
    ///
    /// - Parameters:
    ///   - session: the AR session associated with the change in tracking state
    ///   - camera: the AR camera associated with the change in tracking state
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("Session Changed State")
    }
    
    func session(_: ARSession, didUpdate: ARFrame) {
        guard let magnificationPlane = magnificationPlane, let magnificationTarget = magnificationTarget else {
            return
        }
        var currentPlaneAnchor: ARPlaneAnchor?
        // search for the plane in the current frame
        // TODO: plane can merge with another plane, so might want to track that event happening
        for anchor in didUpdate.anchors {
            if anchor.identifier == magnificationPlane.identifier {
                currentPlaneAnchor = anchor as? ARPlaneAnchor
            }
        }
        guard let updatedMagnificationPlane = currentPlaneAnchor else {
            return
        }
        let coreImage = CIImage(cvPixelBuffer: didUpdate.capturedImage)
        let c = updatedMagnificationPlane.center
        let e = updatedMagnificationPlane.extent
        
        let (adjustedXBounds, adjustedZBounds) = adjustBounds(camera: didUpdate.camera, coreImage: coreImage, planeTransform: updatedMagnificationPlane.transform, initialXBounds: [c.x - e.x/2, c.x + e.x/2], y: c.y, initialZBounds: [c.z - e.z/2, c.z + e.z/2])
        
        // TODO: this breaks when we use horizontal planes
        let vectors = getCornerVectors(camera: didUpdate.camera, coreImage: coreImage, planeTransform: updatedMagnificationPlane.transform, xBounds: adjustedXBounds, y: c.y, zBounds: adjustedZBounds)

        print(vectors)
        let cornerKeys = vectors.map { getPerspectiveCorrectionKey(v: $0, vs: vectors) }
        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")!
        perspectiveCorrection.setValue(coreImage, forKey: kCIInputImageKey)
        for (cornerKey, ciVector) in zip(cornerKeys, vectors) {
            perspectiveCorrection.setValue(ciVector, forKey: cornerKey)
        }
        let outputImage = perspectiveCorrection.outputImage!.oriented(.right)
        let finalImage = UIImage(ciImage: outputImage)
        // TODO: image extent and destination extent do not intersect (might need to adjust this final UIImage)
        magnifiedImage.image = finalImage
    }

    func adjustBounds(camera: ARCamera, coreImage: CIImage, planeTransform: simd_float4x4, initialXBounds: [Float], y: Float, initialZBounds: [Float])->([Float], [Float]) {
        let vertices = getCornerVectors(camera: camera, coreImage: coreImage, planeTransform: planeTransform, xBounds: initialXBounds, y: y, zBounds: initialZBounds)
        // TODO: try to shrink bounds while maintaining the area of the intersection of the image plane and the vertices (see: https://math.stackexchange.com/questions/141798/two-quadrilaterals-intersection-area-special-case)
        
        // try some different shrinks
        // TODO: this should really be done with some sort of binary search
        let shrinkProportions = [9/10.0, 8/10.0, 7/10.0, 6/10.0, 5/10.0, 2/10.0, 1/10.0]
        let xc = (initialXBounds[0] + initialXBounds[1])/2
        let zc = (initialZBounds[0] + initialZBounds[1])/2
        var bestXBounds = initialXBounds
        var bestZBounds = initialZBounds
        
        // could shrink separately on each coordinate.  We have to figure out some way to maintain aspect ratio though (it's not clear how it is being set now)
        for s in shrinkProportions {
            let proposedXBounds = [(initialXBounds[0] - xc)*Float(s) + xc, (initialXBounds[1] - xc)*Float(s) + xc]
            let proposedZBounds = [(initialZBounds[0] - zc)*Float(s) + zc, (initialZBounds[1] - zc)*Float(s) + zc]

            if checkBoundValidity(camera: camera, coreImage: coreImage, planeTransform: planeTransform, proposedXBounds: proposedXBounds, y: y, proposedZBounds: proposedZBounds, originalVertices: vertices) {
                bestXBounds = proposedXBounds
                bestZBounds = proposedZBounds
                print("shrinking", s)
            }
        }
        
        return (bestXBounds, bestZBounds)
    }
    
    func checkBoundValidity(camera: ARCamera, coreImage: CIImage, planeTransform: simd_float4x4, proposedXBounds: [Float], y: Float, proposedZBounds: [Float], originalVertices: [CIVector])->Bool {
        var badBounds = false
        let proposedVertices = getCornerVectors(camera: camera, coreImage: coreImage, planeTransform: planeTransform, xBounds: proposedXBounds, y: y, zBounds: proposedZBounds)
        for (o, p) in zip(originalVertices, proposedVertices) {
            let pOnScreen = p.x >= coreImage.extent.minX && p.x <= coreImage.extent.maxX && p.y >= coreImage.extent.minY && p.y <= coreImage.extent.maxY
            let oOnScreen  = o.x >= coreImage.extent.minX && o.x <= coreImage.extent.maxX && o.y >= coreImage.extent.minY && o.y <= coreImage.extent.maxY
            if o != p && (pOnScreen || oOnScreen) {
                badBounds = true
            }
        }
        return !badBounds
    }
    
    func getCornerVectors(camera: ARCamera, coreImage: CIImage, planeTransform: simd_float4x4, xBounds: [Float], y:Float, zBounds: [Float])->[CIVector] {
        var corners : [simd_float4] = []
        for x in xBounds {
            for z in zBounds {
                corners.append(planeTransform * simd_float4(x, y, z, 1.0))
            }
        }
        if !createdCorners {
            for corner in corners {
                makeBox(center: corner)
            }
            createdCorners = true
        }
        var vectors : [CIVector] = []
        for corner in corners {
            let cameraCoordinates = camera.transform.inverse * corner
            let cameraCoordinatesCorrected = simd_float3(cameraCoordinates.x, -cameraCoordinates.y, -cameraCoordinates.z)
            let homogeneousPixelCoordinates = camera.intrinsics * cameraCoordinatesCorrected
            let pixelCoord = CGPoint(x: CGFloat(homogeneousPixelCoordinates.x / homogeneousPixelCoordinates.z), y: CGFloat(homogeneousPixelCoordinates.y / homogeneousPixelCoordinates.z))
            vectors.append(pointToVector(pixelCoord, image: coreImage))
        }
        return vectors
    }
    
    func getPerspectiveCorrectionKey(v: CIVector, vs: [CIVector])->String {
        var returnValue = "input"
        let ySorted = (vs.map { $0.y }).sorted()
        let xSorted = (vs.map { $0.x }).sorted()
        if v.y <= ySorted[1] {
            returnValue += "Bottom"
        } else {
            returnValue += "Top"
        }
        if v.x <= xSorted[1] {
            returnValue += "Left"
        } else {
            returnValue += "Right"
        }
        return returnValue
    }
    
    func pointToVector(_ point:CGPoint, image:CIImage) -> CIVector {
        return CIVector(x: point.x, y: image.extent.height - point.y)
    }
    
    func makeBox(center: simd_float4) {
        let box = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0)
        
        let boxNode = SCNNode()
        boxNode.geometry = box
        boxNode.position = SCNVector3(simd_float3(center.x, center.y, center.z))
        sceneView.scene.rootNode.addChildNode(boxNode)
    }
    
    func didSelect3DPlanarTarget(anchor: ARPlaneAnchor, tapLocation: simd_float3) {
        magnificationPlane = anchor
        // TODO: might want to reconsider having this stored.  Perhaps this is just the initial target and not the current target.
        magnificationTarget = tapLocation
        createdCorners = false
        let box = SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0)
        
        let boxNode = SCNNode()
        boxNode.geometry = box
        boxNode.transform = SCNMatrix4(anchor.transform)
        sceneView.scene.rootNode.addChildNode(boxNode)
    }

    @IBAction func selectMagnifierTarget(_ sender: UIButton) {
        guard let capturedFrame = sceneView.session.currentFrame else {
            // display some sort of popover
            return
        }
        if let vc = self.storyboard?.instantiateViewController(withIdentifier:"targetselector") as? TargetSelector {
            let containerController = UINavigationController(rootViewController: vc)
            vc.arFrame = capturedFrame
            vc.delegate = self
            vc.sceneView = sceneView
            vc.modalTransitionStyle = .crossDissolve;
            vc.modalPresentationStyle = .overCurrentContext
            self.present(containerController, animated: true, completion: nil)
        }
    }
}
