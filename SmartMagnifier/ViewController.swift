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

        for anchor in didUpdate.anchors {
            if anchor.identifier == magnificationPlane.identifier {
                currentPlaneAnchor = anchor as? ARPlaneAnchor
            }
        }
        guard let updatedMagnificationPlane = currentPlaneAnchor else {
            return
        }
        let c = updatedMagnificationPlane.center
        let e = updatedMagnificationPlane.extent
        
        // TODO: perhaps we can go faster if we avoid this conversion
        let img = UIImage(pixelBuffer: didUpdate.capturedImage)
        let cornerPixels = projectPlaneCoordinate(camera: didUpdate.camera, planeTransform: updatedMagnificationPlane.transform, xBounds: [c.x - e.x/2, c.x + e.x/2], y: c.y, zBounds: [c.z - e.z/2, c.z + e.z/2])
        let centerPixel = projectPlaneCoordinate(camera: didUpdate.camera, planeTransform: updatedMagnificationPlane.transform, xBounds: [c.x], y: c.y, zBounds: [c.z])

        let transformedImg = PerspectiveCorrection.perspectiveCorrection(img, e, cornerPixels, centerPixel[0])

        // TODO: plane can merge with another plane, so might want to track that event happening
        magnifiedImage.image = transformedImg
    }
    
    func projectPlaneCoordinate(camera: ARCamera, planeTransform: simd_float4x4, xBounds: [Float], y:Float, zBounds: [Float])->[CGPoint] {
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
        var pixelCoords : [CGPoint] = []
        for corner in corners {
            let cameraCoordinates = camera.transform.inverse * corner
            let cameraCoordinatesCorrected = simd_float3(cameraCoordinates.x, -cameraCoordinates.y, -cameraCoordinates.z)
            let homogeneousPixelCoordinates = camera.intrinsics * cameraCoordinatesCorrected
            let pixelCoord = CGPoint(x: CGFloat(homogeneousPixelCoordinates.x / homogeneousPixelCoordinates.z), y: CGFloat(homogeneousPixelCoordinates.y / homogeneousPixelCoordinates.z))
            pixelCoords.append(pixelCoord)
        }
        return pixelCoords
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
