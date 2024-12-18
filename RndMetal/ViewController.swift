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
    var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create an image to render (replace with your actual image)
        guard let image = UIImage(named: "test11") else {
            print("Could not create image")
            return
        }
        view.backgroundColor = .cyan
        
        imageView = UIImageView(frame: CGRect(x: 20, y: 100, width: 300, height: 300))
        imageView.contentMode = .scaleAspectFit
        // Create Metal view
        if let metalView = MetalSineWaveView(frame: view.bounds, image: image, imageView: imageView) {
            self.metalView = metalView
            view.addSubview(metalView)
        }
        view.addSubview(imageView)
        imageView.backgroundColor = .red
    }
}
