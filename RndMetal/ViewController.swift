//
//  ViewController.swift
//  RndMetal
//
//  Created by Vishwas Prakash on 10/09/24.
//
import UIKit
import Metal
import MetalKit

struct Uniforms {
    var time: Float
}

class ViewController: UIViewController {
    private var metalView: MetalSineWaveView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create an image to render (replace with your actual image)
        guard let image = UIImage(named: "test11") else {
            print("Could not create image")
            return
        }
        view.backgroundColor = .cyan
        // Create Metal view
        if let metalView = MetalSineWaveView(frame: view.bounds, image: image) {
            self.metalView = metalView
            view.addSubview(metalView)
        }
    }
}
