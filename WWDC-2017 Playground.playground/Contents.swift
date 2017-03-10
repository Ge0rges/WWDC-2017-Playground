/*: Playground - noun: a place where people can play
 
 In this playground I attempt to recreate the famously known cellular automaton: Conway's Game of Life.
 We'll be using SpriteKit versus Metal here as it won't require heavy graphics usage like Apple's own Metal Demo that does the same thing.
 
 PS: It was very hard not to litter this with ; at the end of each statement. Vive Objective-C!
 */

import SpriteKit
import Cocoa
import PlaygroundSupport

// Basic dimensions for our scene
let sceneFrame = CGRect(x: 0, y: 0, width: 500, height: 500)// Divisible by 2,5,10 and 100! Yay!(?)

/*: Custom Cell SKShapeNode Subclass */
class Cell: SKShapeNode {
  var numberOfLiveNeighbours = 0// Tracks the number of live neighbours for this cell
  var isAlive: Bool = false {
    didSet {
      self.isHidden = !isAlive// You can't be dead and present! Silly!
    }
  }
}

/*: Game Scene */

class GameScene: SKScene {
  // Basic game variables
  let gridWidth = Int(sceneFrame.size.width)// Grid width.
  let gridHeight = Int(sceneFrame.size.height)// Grid height.
  let numbersOfRows = 8// Number of cell rows. Warning, incrementing this may cause memory issues since we use for loops.
  let numberOfColumns = 8// Number of cell columns. Warning, incrementing this may cause memory issues since we use for loops.
  let gridLowerLeftCorner:CGPoint = CGPoint(x: 0, y: 0)
  
  var cells: [[Cell]] = []// Initialize a 2D Array (Rows, Columns)
  let marginBetweenCells = 10// Space between each cell
  
  // Used to track generations
  var previousUpdateTime:CFTimeInterval = 0
  var timeCounter:CFTimeInterval = 0
  
  // Helper function to calculate each cell's size.
  func calculateCellSize() -> CGSize {
    let tileWidth = gridWidth / numberOfColumns - marginBetweenCells
    let tileHeight = gridHeight / numbersOfRows - marginBetweenCells
    
    return CGSize(width: tileWidth, height: tileHeight)
  }
  
  // Helper function to get the position of our cell (CGPoint) based on it's row and column.
  func getCellPosition(row r:Int, column c:Int) -> CGPoint {
    let cellSize = calculateCellSize()
    let x = Int(gridLowerLeftCorner.x) + marginBetweenCells + (c * (Int(cellSize.width) + marginBetweenCells))
    let y = Int(gridLowerLeftCorner.y) + marginBetweenCells + (r * (Int(cellSize.height) + marginBetweenCells))
    
    return CGPoint(x: x, y: y)
  }
  
  
  // Initialize the initial game state
  override func didMove(to view: SKView) {
    self.backgroundColor = #colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1)
    
    let cellSize = calculateCellSize()
    for row in 0..<numbersOfRows {// For each row
      var cellRow:[Cell] = []// Initialize an array of cells
      
      for column in 0..<numberOfColumns {// For each column
        // Create a cell node
        let cell = Cell(rectOf: cellSize)
        cell.position = getCellPosition(row: row, column: column)
        cell.fillColor = #colorLiteral(red: 0.3411764801, green: 0.6235294342, blue: 0.1686274558, alpha: 1)
        cell.isAlive = (Int(arc4random_uniform(99) + 1) < 50) ? true : false;// Random initial state
        
        // Add the cell to the scene and to the current row.
        self.addChild(cell)
        cellRow.append(cell)
      }
      
      cells.append(cellRow)
    }
  }
  
  // Helper function to validate a cell, and get it's position given it's column and row.
  func isValidCell(row r:Int, column c:Int) -> Bool {
    return r >= 0 && r < numbersOfRows && c >= 0 && c < numberOfColumns
  }
  
  func getCellAtPosition(xPos x: Int, yPos y: Int) -> Cell? {
    let r: Int = Int( CGFloat(y - (Int(gridLowerLeftCorner.y) + marginBetweenCells)) / CGFloat(gridHeight) * CGFloat(numbersOfRows))
    let c: Int = Int( CGFloat(x - (Int(gridLowerLeftCorner.x) + marginBetweenCells)) / CGFloat(gridWidth) * CGFloat(numberOfColumns))
    
    if isValidCell(row: r, column: c) {
      return cells[r][c]
      
    } else {
      return nil
    }
  }
  
  // We perform the game logic within the update function.
  override func update(_ currentTime: CFTimeInterval) {
    // Keep track of a generation here.
    if previousUpdateTime == 0 {
      previousUpdateTime = currentTime
    }
    
    timeCounter += currentTime - previousUpdateTime// Delta time between the cycles.
    if timeCounter > 1 {// Each generation is a second
      timeCounter = 0
      nextGeneration()// Update our generation
    }
    
    previousUpdateTime = currentTime
  }
  
  func nextGeneration() {
    countLivingNeighbors()
    updateCells()
  }
  
  // Get each neighbour and check if they're living for each cell.
  func countLivingNeighbors() {
    for row in 0..<numbersOfRows {
      for column in 0..<numberOfColumns {
        var numberOfLiveNeighbours: Int = 0
        
        for i in (row-1)...(row+1) {
          for j in (column-1)...(column+1) {
            if (!((row == i) && (column == j)) && isValidCell(row: i, column: j)) {// Make sure this cell is a thing.
              if cells[i][j].isAlive {
                numberOfLiveNeighbours += 1
              }
            }
          }
        }
        
        cells[row][column].numberOfLiveNeighbours = numberOfLiveNeighbours
      }
    }
  }
  
  // Cycle through every *single* cell and update them based on the 3 laws.
  func updateCells() {
    for row in 0..<numbersOfRows {
      for column in 0..<numberOfColumns {
        let cell: Cell = cells[row][column]
        if cell.numberOfLiveNeighbours == 2 && cell.isAlive {
          cell.isAlive = true;// Fourth rule, it may live if it has 2 (or 3) living neighbours
          
        } else if cell.numberOfLiveNeighbours == 3 {// First rule. If a cell has 3 living neighbours exactly, it lives.
          cell.isAlive = true
          
          // Second rule, if a cell has less then 2 living neighbours it dies from underpopulation.
        } else if cell.numberOfLiveNeighbours < 2 || cell.numberOfLiveNeighbours > 3 {// Third rule, if it has more then 3, it dies from overpopulation. Pretty neat conway!
          cell.isAlive = false
        }
        
        // Make it slightly more exciting by giving it a random chance to come back to life (1.9%)
        if (!cell.isAlive) {
        cell.isAlive = (Int(arc4random_uniform(99) + 1) < 1);// Random initial state
        }
      }
    }
  }
}

/*: Playground Scene Setup */

// Create a scene, make it look nice
var scene = GameScene(size: sceneFrame.size)
scene.backgroundColor = #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1);

// Set up the view and show the scene
let view = SKView(frame: sceneFrame)
view.presentScene(scene)
PlaygroundPage.current.liveView = view