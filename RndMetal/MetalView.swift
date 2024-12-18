//
//  MetalView.swift
//  RndMetal
//
//  Created by Vishwas Prakash on 17/12/24.
//

import Metal
import MetalKit
import UIKit

struct VertexInfo{
    var position: SIMD2<Float>
    var textureCoordinate: SIMD2<Float>
}

class MetalSineWaveView: UIView {
    // Metal rendering properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var vertexBuffer: MTLBuffer
    private var animationBuffer: MTLBuffer
    private var sourceTexture: MTLTexture?
    private var vertexInfo: [VertexInfo] = []
    var outputTexture: MTLTexture?
    var imgView: UIImageView
    
    // Animation properties
    private var displayLink: CADisplayLink?
    private var time: Float = 0.0
    
    // Image to render
    private let image: UIImage
    
    // Metalayer for rendering
    private var metalLayer: CAMetalLayer!
    
    init?(frame: CGRect, image: UIImage, imageView: UIImageView) {
        // Create Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Cannot create Metal device")
            return nil
        }
        
        self.device = device
        self.image = image
        
        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Cannot create command queue")
            return nil
        }
        self.commandQueue = commandQueue
        

        // x, y, u, v
        vertexInfo = [
            VertexInfo(position: SIMD2(-1.0, -1.0), textureCoordinate: SIMD2(0.0, 1.0)),
            VertexInfo(position: SIMD2(1.0, -1.0), textureCoordinate: SIMD2(1.0, 1.0)),
            VertexInfo(position: SIMD2(-1.0, 1.0), textureCoordinate: SIMD2(0.0, 0.0)),
            VertexInfo(position: SIMD2(1.0, 1.0), textureCoordinate: SIMD2(1.0, 0.0))
        ]
        
        // Create vertex buffer
        guard let vertexBuffer = device.makeBuffer(
            bytes: vertexInfo,
            length: MemoryLayout<VertexInfo>.stride * vertexInfo.count,
            options: []
        ) else {
            print("Cannot create vertex buffer")
            return nil
        }
        
        self.vertexBuffer = vertexBuffer
        
        // Create animation time buffer
        guard let animationBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: []) else {
            print("Cannot create animation buffer")
            return nil
        }
        
        self.animationBuffer = animationBuffer

        // Call super after all initializations
        imgView = imageView
        super.init(frame: frame)
        self.backgroundColor = .cyan

        createRenderPipeline()
        // Setup Metal layer
        setupMetalLayer()
        
        // Load image texture
        loadTexture()
        createOutputTexture()
        // Setup animation
        setupDisplayLink()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMetalLayer() {
        metalLayer = CAMetalLayer()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = false
        metalLayer.frame = bounds
        layer.addSublayer(metalLayer)
    }
    
    private func loadTexture() {
        guard let cgImage = image.cgImage else {
            print("Cannot convert UIImage to CGImage")
            return
        }
        
        let textureLoader = MTKTextureLoader(device: device)
        
        do {
            sourceTexture = try textureLoader.newTexture(
                cgImage: cgImage,
                options: [:]
            )
        } catch {
            print("Error loading texture: \(error)")
        }
    }
    
    
    private func createRenderPipeline() -> MTLRenderPipelineState? {
        // Create shader functions
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertexShaderWithSineWave"),
              let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
            print("Cannot create shader functions")
            return nil
        }
        
        // Create render pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<VertexInfo>.stride
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        // Create render pipeline state
        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error creating render pipeline state: \(error)")
            return nil
        }
    }
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(step))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    @objc private func step(displayLink: CADisplayLink) {
        // Update time for animation
        time += Float(displayLink.duration)
        
        // Update time buffer
        let timePtr = animationBuffer.contents().bindMemory(to: Float.self, capacity: 1)
        timePtr.pointee = time
        
        // Trigger rendering
        render()
    }
    
    private func render() {

        guard let drawable = metalLayer.nextDrawable() else {
            print("Failed to get next drawable from metalLayer")
            return
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command buffer")
            return
        }

        guard let sourceTexture = sourceTexture else {
            print("Source texture is nil")
            return
        }

        guard let outputTexture = outputTexture else {
            print("Output texture is nil")
            return
        }


           // Create render pass descriptor targeting our output texture instead of the drawable
           let renderPassDescriptor = MTLRenderPassDescriptor()
           renderPassDescriptor.colorAttachments[0].texture = outputTexture
           renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
           renderPassDescriptor.colorAttachments[0].loadAction = .clear
           renderPassDescriptor.colorAttachments[0].storeAction = .store
           
           guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
               return
           }
           
           // Your existing render code here
           renderEncoder.setRenderPipelineState(pipelineState)
           renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
           renderEncoder.setVertexBuffer(animationBuffer, offset: 0, index: 1)
           renderEncoder.setFragmentTexture(sourceTexture, index: 0)
           renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
           renderEncoder.endEncoding()
           
           // Add a blit encoder to copy the result to the drawable
           if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
               let region = MTLRegionMake2D(0, 0, outputTexture.width, outputTexture.height)
               blitEncoder.copy(
                   from: outputTexture,
                   sourceSlice: 0,
                   sourceLevel: 0,
                   sourceOrigin: MTLOriginMake(0, 0, 0),
                   sourceSize: MTLSizeMake(outputTexture.width, outputTexture.height, 1),
                   to: drawable.texture,
                   destinationSlice: 0,
                   destinationLevel: 0,
                   destinationOrigin: MTLOriginMake(0, 0, 0)
               )
               blitEncoder.endEncoding()
           }
           
           // Add completion handler to know when drawing is done
           commandBuffer.addCompletedHandler { [weak self] _ in
               // The outputTexture now contains the final rendered image
               // You can use it here for any post-processing or saving
               self?.handleTextureCompletion()
           }
           
           commandBuffer.present(drawable)
           commandBuffer.commit()
       }
    
    private func createRenderPassDescriptor(drawable: CAMetalDrawable) -> MTLRenderPassDescriptor {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        return renderPassDescriptor
    }
    
    private func handleTextureCompletion() {
        // Here you can use the outputTexture for whatever you need
        // For example, you could save it to an image:
        guard let outputTexture = outputTexture else { return }
        
        // Example: Create CIImage from texture
//        let ciImage = CIImage(mtlTexture: outputTexture, options: [:])
        DispatchQueue.main.async {
            self.imgView.image =  self.textureToUIImage(texture: outputTexture)
        }
        // You can now use this texture/image for further processing
    }
    
    private func createOutputTexture() {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(bounds.width),
            height: Int(bounds.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead] // Allow both rendering to and reading from texture
        outputTexture = device.makeTexture(descriptor: textureDescriptor)
    }
    
    func textureToUIImage(texture: MTLTexture) -> UIImage? {
        // Define the size of the texture
        let width = texture.width
        let height = texture.height

        // Create a raw buffer to hold the texture data
        let byteCount = width * height * 4 // RGBA format (4 bytes per pixel)
        var pixelData = [UInt8](repeating: 0, count: byteCount)
        let region = MTLRegionMake2D(0, 0, width, height)

        // Copy texture data into the buffer
        texture.getBytes(&pixelData,
                         bytesPerRow: width * 4,
                         from: region,
                         mipmapLevel: 0)

        // Create a CGImage from the raw buffer
        let bitmapContext = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let cgImage = bitmapContext?.makeImage() else { return nil }

        // Convert the CGImage to a UIImage
        return UIImage(cgImage: cgImage)
    }
}
