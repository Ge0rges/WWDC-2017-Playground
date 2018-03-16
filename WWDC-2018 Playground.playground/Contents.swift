/*: Playground - noun: a place where people can play
 
 In this playground I give semi-static life last year's WWDC famous background.
 */

import SpriteKit
import GameplayKit
import PlaygroundSupport

// Basic dimensions for our scene
let sceneFrame = CGRect(x: 0, y: 0, width: 500, height: 500)

class GameScene: SKScene {
  
  let numberOfPeople: Int = 11;// The number of people in the crowd. The  playground is a memory hog, max 30.
  var peopleNodes: [SKSpriteNode] = [];// Holds all the sprites
  var peopleAgents: [GKAgent2D] = [];// Holds all the agents
  var didSetup = false;// Only need to do setup once.
  
  private var lastUpdateTime : TimeInterval = 0
  
  override func didMove(to view: SKView) {
    self.lastUpdateTime = 0
    
    // Create a node for each person
    if !didSetup {
      didSetup = true;
      
      // Create all the people nodes
      for _ in 0..<numberOfPeople {
        let personNode = SKSpriteNode.init(imageNamed: "Person \(arc4random_uniform(11))");// Pick randomly from one of the 11 textures
        //let personNode = SKSpriteNode.init(color: #colorLiteral(red: 0.8078431487, green: 0.02745098062, blue: 0.3333333433, alpha: 1), size: CGSize.init(width: 10, height: 10));// Faster when testing
        
        // Add everything
        self.peopleNodes.append(personNode);
        self.addChild(personNode);
        
        // Random spawn
        let xPos = CGFloat(arc4random()).truncatingRemainder(dividingBy: self.view!.frame.size.height);
        let yPos = CGFloat(arc4random()).truncatingRemainder(dividingBy: self.view!.frame.size.width)
        personNode.position = CGPoint.init(x: xPos, y: yPos);
        
        // Create the agents with a wander goal and slight seek goal
        let agent = GKAgent2D.init()
        agent.maxSpeed = 25;
        agent.maxAcceleration = 25;
        agent.position = vector2(Float(xPos), Float(yPos));// Random spawn
        
        // Wander Goal
        let wanderGoal = GKGoal.init(toWander: 25);
        agent.behavior = GKBehavior.init(goal: wanderGoal, weight: 60);
        
        self.peopleAgents.append(agent);
      }
      
      
      // Add an avoid goal to avoid other people (once all people are created)
      for agent in self.peopleAgents {
        self.peopleAgents.remove(at: self.peopleAgents.index(of: agent)!);
        let avoidGoal = GKGoal.init(toAvoid: self.peopleAgents, maxPredictionTime: 100);
        let cohereGoal = GKGoal.init(toCohereWith: self.peopleAgents, maxDistance: 10, maxAngle: Float(Double.pi/2));
        agent.behavior?.setWeight(60, for: avoidGoal);
        agent.behavior?.setWeight(60, for: cohereGoal);
        
        self.peopleAgents.append(agent);
      }
    }
  }
  
  override func update(_ currentTime: TimeInterval) {
    // Called before each frame is rendered
    
    // Initialize _lastUpdateTime if it has not already been
    if (self.lastUpdateTime == 0) {
      self.lastUpdateTime = currentTime
    }
    
    // Calculate time since last update
    let dt = currentTime - self.lastUpdateTime
    
    // Update entities
    for agent in self.peopleAgents {
      agent.update(deltaTime: dt)
    }
    
    self.lastUpdateTime = currentTime
  }
  
  override func didEvaluateActions() {
    for index in 0..<numberOfPeople {// PeopleAgents.count = numberOfPeople but will be the last thing to be setup. No need to check indexes.
      let personNode = self.peopleNodes[index];
      let agent = self.peopleAgents[index];
      
      personNode.position = CGPoint(x: CGFloat(agent.position.x), y: CGFloat(agent.position.y));
      personNode.zPosition = CGFloat(agent.rotation);
      personNode.zRotation = CGFloat(agent.rotation);
    }
  }
}

/*: Playground Scene Setup */

// Create a scene, make it look nice
var scene = GameScene(size: sceneFrame.size);
scene.backgroundColor = #colorLiteral(red: 0.9136353135, green: 0.9137886167, blue: 0.9136152267, alpha: 1);

// Set up the view and show the scene
let view = SKView(frame: sceneFrame);
view.presentScene(scene);
PlaygroundPage.current.liveView = view;
