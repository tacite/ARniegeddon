/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import SpriteKit
import GameplayKit
import ARKit

class GameScene: SKScene {

  
  var isWorldSetUp = false
  var sight: SKSpriteNode!
  var sceneView: ARSKView {
    return view as! ARSKView
  }
  let gameSize = CGSize(width: 2, height: 2)
  var hasBugspray = false {
    didSet {
      let sightImageName = hasBugspray ? "bugspraySight" : "sight"
      sight.texture = SKTexture(imageNamed: sightImageName)
    }
  }

  private func setUpWorld() {
    guard let currentFrame = sceneView.session.currentFrame,
      // 1
      let scene = SKScene(fileNamed: "Level1")
      else { return }
    
    for node in scene.children {
      if let node = node as? SKSpriteNode {
        var translation = matrix_identity_float4x4
        // 2
        let positionX = node.position.x / scene.size.width
        let positionY = node.position.y / scene.size.height
        translation.columns.3.x =
          Float(positionX * gameSize.width)
        translation.columns.3.z =
          -Float(positionY * gameSize.height)
        translation.columns.3.y = Float(drand48() - 0.5)
        let transform = currentFrame.camera.transform * translation
        let anchor = Anchor(transform: transform)
        if let name = node.name, let type = NodeType(rawValue: name) {
          anchor.type = type
          sceneView.session.add(anchor: anchor)
          if anchor.type == NodeType.firebug {
            self.addBugSpray(to: currentFrame)
          }
        }
      }
    }
    isWorldSetUp = true
  }
  
  override func update(_ currentTime: TimeInterval) {
    if !isWorldSetUp {
      setUpWorld()
    }
    guard let currentFrame = sceneView.session.currentFrame,
      let lightEstimate = currentFrame.lightEstimate else {
        return
    }
    
    let neutralIntensity: CGFloat = 1000
    let ambientIntensity = min(lightEstimate.ambientIntensity,
                               neutralIntensity)
    let blendFactor = 1 - ambientIntensity / neutralIntensity
    
    for node in children {
      if let bug = node as? SKSpriteNode {
        bug.color = .black
        bug.colorBlendFactor = blendFactor
      }
    }
    for anchor in currentFrame.anchors {
      guard let node = sceneView.node(for: anchor), node.name == NodeType.bugspray.rawValue else { continue }
      let distance = simd_distance(anchor.transform.columns.3, currentFrame.camera.transform.columns.3)
      if distance < 0.1 {
        remove(bugspray: anchor)
        self.hasBugspray = true
        break
      }
    }
  }

  override func didMove(to view: SKView) {
    self.sight = SKSpriteNode(imageNamed: "sight")
    self.addChild(self.sight)
    srand48(Int(Date.timeIntervalSinceReferenceDate))
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    let location = self.sight.position
    let hitNodes = self.nodes(at: location)
    
    var hitBug: SKNode?
    
    for node in hitNodes {
      if node.name == NodeType.bug.rawValue ||
        (node.name == NodeType.firebug.rawValue && hasBugspray) {
        hitBug = node
        break
      }
    }
    run(Sounds.fire)
    if let hitBug = hitBug, let anchor = sceneView.anchor(for: hitBug) {
      let action = SKAction.run {
        self.sceneView.session.remove(anchor: anchor)
      }
      let group = SKAction.group([Sounds.hit, action])
      let sequence = [SKAction.wait(forDuration: 0.3), group]
      hitBug.run(SKAction.sequence(sequence))
    }
    self.hasBugspray = false
  }
  
  private func addBugSpray(to currentFrame: ARFrame) {
    var translation = matrix_identity_float4x4
    translation.columns.3.x = Float(drand48()*2 - 1)
    translation.columns.3.z = -Float(drand48()*2 - 1)
    translation.columns.3.y = Float(drand48() - 0.5)
    let transform = currentFrame.camera.transform * translation
    let anchor = Anchor(transform: transform)
    anchor.type = .bugspray
    sceneView.session.add(anchor: anchor)
  }
  
  private func remove(bugspray anchor: ARAnchor) {
    run(Sounds.bugspray)
    sceneView.session.remove(anchor: anchor)
  }
  
/*
  private var label : SKLabelNode?
  private var spinnyNode : SKShapeNode?
  
  override func didMove(to view: SKView) {
    
    // Get label node from scene and store it for use later
    self.label = self.childNode(withName: "//helloLabel") as? SKLabelNode
    if let label = self.label {
      label.alpha = 0.0
      label.run(SKAction.fadeIn(withDuration: 2.0))
    }
    
    // Create shape node to use during mouse interaction
    let w = (self.size.width + self.size.height) * 0.05
    self.spinnyNode = SKShapeNode.init(rectOf: CGSize.init(width: w, height: w), cornerRadius: w * 0.3)
    
    if let spinnyNode = self.spinnyNode {
      spinnyNode.lineWidth = 2.5
      
      spinnyNode.run(SKAction.repeatForever(SKAction.rotate(byAngle: CGFloat(Double.pi), duration: 1)))
      spinnyNode.run(SKAction.sequence([SKAction.wait(forDuration: 0.5),
                                        SKAction.fadeOut(withDuration: 0.5),
                                        SKAction.removeFromParent()]))
    }
  }
  
  
  func touchDown(atPoint pos : CGPoint) {
    if let n = self.spinnyNode?.copy() as! SKShapeNode? {
      n.position = pos
      n.strokeColor = SKColor.green
      self.addChild(n)
    }
  }
  
  func touchMoved(toPoint pos : CGPoint) {
    if let n = self.spinnyNode?.copy() as! SKShapeNode? {
      n.position = pos
      n.strokeColor = SKColor.blue
      self.addChild(n)
    }
  }
  
  func touchUp(atPoint pos : CGPoint) {
    if let n = self.spinnyNode?.copy() as! SKShapeNode? {
      n.position = pos
      n.strokeColor = SKColor.red
      self.addChild(n)
    }
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    if let label = self.label {
      label.run(SKAction.init(named: "Pulse")!, withKey: "fadeInOut")
    }
    
    for t in touches { self.touchDown(atPoint: t.location(in: self)) }
  }
  
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    for t in touches { self.touchUp(atPoint: t.location(in: self)) }
  }
  
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    for t in touches { self.touchUp(atPoint: t.location(in: self)) }
  }
  
  
  override func update(_ currentTime: TimeInterval) {
    // Called before each frame is rendered
  } */
}
