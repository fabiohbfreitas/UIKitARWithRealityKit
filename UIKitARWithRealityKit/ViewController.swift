import Foundation
import UIKit
import ARKit
import RealityKit
import OSLog

extension Logger {
    static var arLogger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ARView")
}

class ViewController: UIViewController, ARSessionDelegate {
    lazy private var arView = ARView()
    lazy private var deleteButton = UIButton(type: .roundedRect)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        setupDeleteButton()
    }
    
    // MARK: - DeleteButton
    private func setupDeleteButton() {
        deleteButton.setTitle("Delete All", for: .normal)
        deleteButton.tintColor = .red
        placeDeleteButton()
        deleteButton.addTarget(self, action: #selector(handleTapDelete), for: .touchUpInside)
    }
    
    private func placeDeleteButton() {
        arView.addSubview(deleteButton)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            deleteButton.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            deleteButton.bottomAnchor.constraint(equalTo: arView.bottomAnchor, constant: -40)
        ])
    }
    
    
    @objc private func handleTapDelete() {
        guard !arView.scene.anchors.isEmpty else { return }
        arView.scene.anchors.removeAll()
        Logger.arLogger.info("removed all anchors")
    }
    
    //MARK: - ARView
    private func setupARView() {
        guard ARWorldTrackingConfiguration.isSupported else {
            Logger.arLogger.error("AR is not supported")
            return
        }
        configureARViewSession()
        placeARView()
    }
    
    private func configureARViewSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)
        arView.session.delegate = self
        ARView.viewController = self
    }
    
    private func placeARView() {
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.delegate = self
        self.view.addSubview(arView)
        self.view.addSubview(coachingOverlay)
        arView.translatesAutoresizingMaskIntoConstraints = false
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            arView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            arView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
            arView.heightAnchor.constraint(equalTo: self.view.heightAnchor),
            coachingOverlay.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: arView.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: arView.heightAnchor)
        ])
    }
}

extension ARView {
    func enableTapGesture() {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleARViewTap))
        self.addGestureRecognizer(gestureRecognizer)
    }
    static var viewController: UIViewController?
    
    @objc private func handleARViewTap(recognizer: UITapGestureRecognizer) {
        let loc = recognizer.location(in: self)
        guard let rayResult = self.ray(through: loc) else { return }
        let results = self.scene.raycast(origin: rayResult.origin, direction: rayResult.direction)
        
        if let firstResult = results.first {
            print("tap on object: \(firstResult.entity)")
        } else {
            let results = self.raycast(from: loc, allowing: .estimatedPlane, alignment: .any)
            if let first = results.first {
                var position = simd_make_float3(first.worldTransform.columns.3)
                if self.scene.anchors.first?.findEntity(named: "Earth") != nil {
                    print("already have earth placed")
                    return
                }
                let planetAnchor = AnchorEntity(world: position)
                if let planetModel = try? ModelEntity.load(named: "Earth.usdz") {
                    planetModel.name = "Earth"
                    planetAnchor.addChild(planetModel)
                    let from = Transform(rotation: .init(angle: .pi * 2, axis: [0, 1, 0]))
                    
                    let definition = FromToByAnimation(from: from,
                                                       duration: 20,
                                                       timing: .linear,
                                                       bindTarget: .transform,
                                                       repeatMode: .repeat)
                    
                    if let animate = try? AnimationResource.generate(with: definition) {
                        planetModel.playAnimation(animate)
                    }
                }
                self.scene.addAnchor(planetAnchor)
            }
        }
        
    }
}

extension ViewController: ARCoachingOverlayViewDelegate {
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        arView.scene.findEntity(named: "Earth")?.removeFromParent()
        arView.enableTapGesture()
    }
}
