/*: Playground - noun: a place where people can play
 
 In this playground I attempt to recreate the famously known cellular automaton: Conway's Game of Life.
 We'll be using SpriteKit versus Metal here as it won't require heavy graphics usage like Apple's own Metal Demo that does the same thing.
 In an attempt to here what life is like, every cell is assigned a unique frequency that it plays when alive.
 */

import SpriteKit
import Cocoa
import PlaygroundSupport
import AVFoundation
import Foundation

/*:
  Audio Synthesizer class taken from: https://gist.github.com/michaeldorner/746c659476429a86a9970faaa6f95ec4
 */

class FMSynthesizer {
  
  // The maximum number of audio buffers in flight. Setting to two allows one
  // buffer to be played while the next is being written.
  var kInFlightAudioBuffers: Int = 2;
  
  // The number of audio samples per buffer. A lower value reduces latency for
  // changes but requires more processing but increases the risk of being unable
  // to fill the buffers in time. A setting of 1024 represents about 23ms of
  // samples.
  let kSamplesPerBuffer: AVAudioFrameCount = 1024;
  
  // The audio engine manages the sound system.
  let audioEngine: AVAudioEngine = AVAudioEngine();
  
  // The player node schedules the playback of the audio buffers.
  let playerNode: AVAudioPlayerNode = AVAudioPlayerNode();
  
  // Use standard non-interleaved PCM audio.
  let audioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 1);
  
  // A circular queue of audio buffers.
  var audioBuffers: [AVAudioPCMBuffer] = [AVAudioPCMBuffer]();
  
  // The index of the next buffer to fill.
  var bufferIndex: Int = 0;
  
  // The dispatch queue to render audio samples.
  let audioQueue: DispatchQueue = DispatchQueue(label: "FMSynthesizerQueue", attributes: []);
  
  // A semaphore to gate the number of buffers processed.
  let audioSemaphore: DispatchSemaphore;
  
  public init() {
    // init the semaphore
    audioSemaphore = DispatchSemaphore(value: kInFlightAudioBuffers);
    
    // Create a pool of audio buffers.
    audioBuffers = [AVAudioPCMBuffer](repeating: AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(kSamplesPerBuffer)), count: 2);
    
    // Attach and connect the player node.
    audioEngine.attach(playerNode);
    audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: audioFormat);
    
    do {
      try audioEngine.start();
      
    } catch {
      print("AudioEngine didn't start");
    }
    
    NotificationCenter.default.addObserver(self, selector: #selector(FMSynthesizer.audioEngineConfigurationChange(_:)), name: NSNotification.Name.AVAudioEngineConfigurationChange, object: audioEngine);
  }
  
  func play(_ carrierFrequency: Float32, modulatorFrequency: Float32, modulatorAmplitude: Float32) {
    let unitVelocity = Float32(2.0 * M_PI / audioFormat.sampleRate);
    let carrierVelocity = carrierFrequency * unitVelocity;
    let modulatorVelocity = modulatorFrequency * unitVelocity;
    audioQueue.async {
      var sampleTime: Float32 = 0;
      while true {
        // Wait for a buffer to become available.
        self.audioSemaphore.wait(timeout: DispatchTime.distantFuture);
        
        // Fill the buffer with new samples.
        let audioBuffer = self.audioBuffers[self.bufferIndex]
        let leftChannel = audioBuffer.floatChannelData?[0];
        let rightChannel = audioBuffer.floatChannelData?[1];
        for sampleIndex in 0 ..< Int(self.kSamplesPerBuffer) {
          let sample = sin(carrierVelocity * sampleTime + modulatorAmplitude * sin(modulatorVelocity * sampleTime));
          leftChannel?[sampleIndex] = sample;
          rightChannel?[sampleIndex] = sample;
          sampleTime = sampleTime + 1.0;
        }
        audioBuffer.frameLength = self.kSamplesPerBuffer;
        
        // Schedule the buffer for playback and release it for reuse after
        // playback has finished.
        self.playerNode.scheduleBuffer(audioBuffer) {
          self.audioSemaphore.signal();
          return;
        }
        
        self.bufferIndex = (self.bufferIndex + 1) % self.audioBuffers.count;
      }
    }
    
    playerNode.pan = 0.8;
    playerNode.play();
  }
  
  func pause() {
    playerNode.stop();
  }
  
  @objc  func audioEngineConfigurationChange(_ notification: Notification) -> Void {
    NSLog("Audio engine configuration change: \(notification)");
  }
}

/*:
  SpriteKit time.
 */

// Basic dimensions for our scene
let sceneFrame = CGRect(x: 0, y: 0, width: 500, height: 500)// Divisible by 2,5,10 and 100! Yay!(?)

/*: Custom Cell SKShapeNode Subclass */
var livingCells = 1;// Used to tack end of game

class Cell: SKShapeNode {
  var numberOfLiveNeighbours = 0// Tracks the number of live neighbours for this cell
  var frequency: Float32 = 0;
  let synthesizer: FMSynthesizer = FMSynthesizer.init();
  var isAlive: Bool = false {
    didSet {
      // Only needs to this when it isn't a redundant setting
      if self.isHidden && isAlive {
        livingCells += 1;
        synthesizer.play(frequency, modulatorFrequency: 679.0, modulatorAmplitude: 0.8);

      } else if !self.isHidden && !isAlive {
        livingCells -= 1;
        synthesizer.pause();
      }
      
      self.isHidden = !isAlive// You can't be dead and present! Silly!
    }
  }
}

/*: Game Scene */

class GameScene: SKScene {
  // Basic game variables
  let gridWidth = Int(sceneFrame.size.width);// Grid width.
  let gridHeight = Int(sceneFrame.size.height);// Grid height.
  let numbersOfRows = 8;// Number of cell rows. Warning, incrementing this may cause memory issues since we use for loops.
  let numberOfColumns = 8;// Number of cell columns. Warning, incrementing this may cause memory issues since we use for loops.
  let gridLowerLeftCorner:CGPoint = CGPoint(x: 0, y: 0);
  
  var cells: [[Cell]] = [];// Initialize a 2D Array (Rows, Columns)
  let marginBetweenCells = 2;// Space between each cell
  
  // Used to track generations
  var previousUpdateTime:CFTimeInterval = 0;
  var timeCounter:CFTimeInterval = 0;
  
  // Helper function to calculate each cell's size.
  func calculateCellSize() -> CGSize {
    let tileWidth = gridWidth / numberOfColumns - marginBetweenCells;
    let tileHeight = gridHeight / numbersOfRows - marginBetweenCells;
    
    return CGSize(width: tileWidth, height: tileHeight);
  }
  
  // Helper function to get the position of our cell (CGPoint) based on it's row and column.
  func getCellPosition(row r:Int, column c:Int) -> CGPoint {
    let cellSize = calculateCellSize()
    let x = Int(gridLowerLeftCorner.x) + marginBetweenCells + (c * (Int(cellSize.width) + marginBetweenCells));
    let y = Int(gridLowerLeftCorner.y) + marginBetweenCells + (r * (Int(cellSize.height) + marginBetweenCells));
    
    return CGPoint(x: x, y: y);
  }
  
  
  // Initialize the initial game state
  override func didMove(to view: SKView) {
    self.backgroundColor = #colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1);
    
    let cellSize = calculateCellSize();
    for row in 0..<numbersOfRows {// For each row
      var cellRow:[Cell] = [];// Initialize an array of cells
      
      for column in 0..<numberOfColumns {// For each column
        // Create a cell node
        let cell = Cell(rectOf: cellSize);
        cell.position = getCellPosition(row: row, column: column);
        cell.fillColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1);
        cell.isHidden = true;
        cell.isAlive = (Int(arc4random_uniform(99) + 1) < 50) ? true : false;// Random initial state
        cell.frequency = Float32(row)*Float32(column)*10;
        
        // Add the cell to the scene and to the current row.
        self.addChild(cell);
        cellRow.append(cell);
      }
      
      cells.append(cellRow);
    }
  }
  
  // Helper function to validate a cell, and get it's position given it's column and row.
  func isValidCell(row r:Int, column c:Int) -> Bool {
    return r >= 0 && r < numbersOfRows && c >= 0 && c < numberOfColumns;
  }
  
  func getCellAtPosition(xPos x: Int, yPos y: Int) -> Cell? {
    let r: Int = Int( CGFloat(y - (Int(gridLowerLeftCorner.y) + marginBetweenCells)) / CGFloat(gridHeight) * CGFloat(numbersOfRows));
    let c: Int = Int( CGFloat(x - (Int(gridLowerLeftCorner.x) + marginBetweenCells)) / CGFloat(gridWidth) * CGFloat(numberOfColumns));
    
    if isValidCell(row: r, column: c) {
      return cells[r][c];
      
    } else {
      return nil;
    }
  }
  
  // We perform the game logic within the update function.
  override func update(_ currentTime: CFTimeInterval) {
    // Keep track of a generation here.
    if previousUpdateTime == 0 {
      previousUpdateTime = currentTime;
    }
    
    timeCounter += currentTime - previousUpdateTime// Delta time between the cycles.
    if timeCounter > 1 {// Each generation is a second
      timeCounter = 0;
      nextGeneration();// Update our generation
    }
    
    previousUpdateTime = currentTime;
  }
  
  func nextGeneration() {
    if livingCells > 0 {// Game is going
      countLivingNeighbors();
      updateCells();
    
    } else {// End of game. Restart after delay.
      sleep(2);
      self.didMove(to: self.view!);
    }
  }
  
  // Get each neighbour and check if they're living for each cell.
  func countLivingNeighbors() {
    for row in 0..<numbersOfRows {
      for column in 0..<numberOfColumns {
        var numberOfLiveNeighbours: Int = 0;
        
        for i in (row-1)...(row+1) {
          for j in (column-1)...(column+1) {
            if (!((row == i) && (column == j)) && isValidCell(row: i, column: j)) {// Make sure this cell is a thing.
              if cells[i][j].isAlive {
                numberOfLiveNeighbours += 1;
              }
            }
          }
        }
        
        cells[row][column].numberOfLiveNeighbours = numberOfLiveNeighbours;
      }
    }
  }
  
  // Cycle through every *single* cell and update them based on the 3 laws.
  func updateCells() {
    for row in 0..<numbersOfRows {
      for column in 0..<numberOfColumns {
        let cell: Cell = cells[row][column];
        if cell.numberOfLiveNeighbours == 2 && cell.isAlive {
          cell.isAlive = true;// Fourth rule, it may live if it has 2 (or 3) living neighbours
          
        } else if cell.numberOfLiveNeighbours == 3 {// First rule. If a cell has 3 living neighbours exactly, it lives.
          cell.isAlive = true;
          
          // Second rule, if a cell has less then 2 living neighbours it dies from underpopulation.
        } else if cell.numberOfLiveNeighbours < 2 || cell.numberOfLiveNeighbours > 3 {// Third rule, if it has more then 3, it dies from overpopulation. Pretty neat conway!
          cell.isAlive = false;
        }
        
        // Make it slightly more exciting by giving it a random chance to come back to life (5.9%)
        if (!cell.isAlive) {
        cell.isAlive = (Int(arc4random_uniform(99) + 1) < 5);// Random initial state
        }
      }
    }
  }
}

/*: Playground Scene Setup */

// Create a scene, make it look nice
var scene = GameScene(size: sceneFrame.size);
scene.backgroundColor = #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1);

// Set up the view and show the scene
let view = SKView(frame: sceneFrame);
view.presentScene(scene);
PlaygroundPage.current.liveView = view;
