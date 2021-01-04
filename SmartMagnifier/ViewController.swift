//
//  ViewController.swift
//  SmartMagnifier
//
//  Created by occamlab on 12/24/20.
//

import UIKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    @IBOutlet var sceneView: ARSCNView!
    
    var configuration: ARWorldTrackingConfiguration!

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
    }
    
    @IBAction func selectMagnifierTarget(_ sender: UIButton) {
        guard let capturedFrame = sceneView.session.currentFrame else {
            // display some sort of popover
            return
        }
        if let vc = self.storyboard?.instantiateViewController(withIdentifier:"targetselector") as? TargetSelector {
            let containerController = UINavigationController(rootViewController: vc)
            vc.arFrame = capturedFrame
            vc.modalTransitionStyle = .crossDissolve;
            vc.modalPresentationStyle = .overCurrentContext
            self.present(containerController, animated: true, completion: nil)
        }
    }
}
