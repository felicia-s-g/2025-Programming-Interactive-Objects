import processing.serial.*;

// Colors
color color1 = color(207, 41, 69);   // #CF2945 (Red/Pink)
color color2 = color(218, 139, 21);  // #DA8B15 (Orange)
color color3 = color(56, 150, 35);   // #389623 (Green)

// Serial connection
Serial serial;

final int TOTAL_WIDTH  = 32;       // Matrix width (32x32)
final int TOTAL_HEIGHT = 32;       // Matrix height (32x32)
byte[] buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 3];  // For RGB pixel data

// Variables for tree animation
float treeX = TOTAL_WIDTH / 2;  // Starting at the center
float treeY = TOTAL_HEIGHT - 1; // At the bottom of the canvas
float angle = -PI / 2;          // Initial angle for the tree
float length = 8;               // Starting branch length
int maxDepth = 6;               // Maximum depth of the tree
float time = 0;                 // Time for animation

void setup() {
  size(32, 32);  // Scaled-up canvas for visualization (32x32 in real size)
  frameRate(30);   // Frame rate for animation
  noFill();
  smooth();
  noStroke();
  background(0);   // Solid black background
  
  // Initialize the serial port for communication with the matrix
  try {
    final String PORT_NAME = "/dev/tty.usbserial-02B62278"; // Replace with your actual port name
    serial = new Serial(this, PORT_NAME, 921600);
    println("Serial port initialized: " + PORT_NAME);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0);  // Refresh background
  
  // Increase time to simulate tree growth
  time += 0.1;
  length = 8 + sin(time) * 4;  // Oscillating branch length
  
  drawTree(treeX, treeY, angle, length, maxDepth);
  
  sendCanvasToSerial();
}

// Function to draw a fractal tree
void drawTree(float x, float y, float angle, float length, int depth) {
  if (depth == 0) return;  // Stop recursion when depth reaches 0
  
  // Calculate the end point of the branch
  float branchX = x + cos(angle) * length;
  float branchY = y + sin(angle) * length;
  
  // Draw the branch
  strokeWeight(2);
  if (depth % 2 == 0) {
    stroke(color1);  // Red/pink branches for even depth
  } else {
    stroke(color2);  // Orange branches for odd depth
  }
  line(x, y, branchX, branchY);
  
  // Recursively draw the next branches
  float newLength = length * 0.7;  // Shrink the branch size
  float branchAngle1 = angle - radians(25);  // Angle for left branch
  float branchAngle2 = angle + radians(25);  // Angle for right branch
  
  // Recursively draw left and right branches
  drawTree(branchX, branchY, branchAngle1, newLength, depth - 1);
  drawTree(branchX, branchY, branchAngle2, newLength, depth - 1);
  
  // Add leaves (green) at the last level of recursion
  if (depth == 1) {
    noStroke();
    fill(color3);
    ellipse(branchX, branchY, 3, 3);  // Small leaves as green circles
  }
}

// Function to send the pixel data to the matrix
void sendCanvasToSerial() {
  // Loop through the 32x32 canvas and prepare pixel data for the serial output
  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      color c = get(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT));  // Get pixel color

      int idx = (y * TOTAL_WIDTH + x) * 3;
      buffer[idx] = (byte) red(c);   // Red component
      buffer[idx + 1] = (byte) green(c); // Green component
      buffer[idx + 2] = (byte) blue(c);  // Blue component
    }
  }

  // Send the pixel data to the serial port
  if (serial != null) {
    serial.write('*');  // Indicate the start of the frame
    serial.write(buffer);  // Send the pixel buffer
  }
}
