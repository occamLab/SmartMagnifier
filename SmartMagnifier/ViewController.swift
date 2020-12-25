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
        print("Got a new frame")
    }
    
    @IBAction func selectMagnifierTarget(_ sender: UIButton) {
        guard let capturedFrame = sceneView.session.currentFrame else {
            // display some sort of popover
            return
        }
        if let vc = self.storyboard?.instantiateViewController(withIdentifier:"targetselector") as? TargetSelector {
            vc.arFrame = capturedFrame
            vc.modalTransitionStyle = .crossDissolve;
            vc.modalPresentationStyle = .overCurrentContext
            self.present(vc, animated: true, completion: nil)
        }
    }
}
