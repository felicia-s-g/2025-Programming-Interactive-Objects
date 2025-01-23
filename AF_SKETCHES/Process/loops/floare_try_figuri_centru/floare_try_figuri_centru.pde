import processing.serial.*;

final int TOTAL_WIDTH = 32;
final int TOTAL_HEIGHT = 32;
final int BAUD_RATE = 921600;

// Global Variables
Serial serial;
byte[] buffer;

PImage sourceImage; // Stores the 32x32 image to serve as the final state of the animation.
Particle[] particles; // An array of Particle objects representing individual pixels.

void setup() {
  size(32, 32);
  frameRate(80);

  // Load and resize the source image
  sourceImage = loadImage("try_2.png");
  sourceImage.resize(TOTAL_WIDTH, TOTAL_HEIGHT);

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2]; // For 16-bit color output
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT]; // One particle per pixel

  // Initialize particles (all starting from the center of the screen)
  int index = 0;
  
  for (int y = 0; y < TOTAL_HEIGHT; y++) { // loops over rows
    for (int x = 0; x < TOTAL_WIDTH; x++) { // loops over columns
      // Set the particle's starting position to the center of the screen
      int startX = width / 2;
      int startY = height / 2;
      
      // Get the target pixel color from the image
      color targetColor = sourceImage.get(x, y);
      
      // Creates a new Particle object and stores it in the particles array
      particles[index++] = new Particle(startX, startY, x, y, targetColor);
    }
  }

  // Initialize serial communication
  try {
    String portName = "/dev/tty.usbserial-02B62278"; // Adjust the port name as needed
    serial = new Serial(this, portName, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0); // Clears screen

  // Update and display particles
  for (Particle p : particles) { // Iterates over all particles
    p.update();   // Moves each particle closer to its target position
    p.display();  // Draws each particle on the canvas
  }

  // Send the current state to the serial port
  sendToSerial();
}

// Particle class for individual pixel behavior
class Particle {
  float x, y;        // Current position
  int targetX, targetY; // Target position
  color targetColor; // Target color

  // Initializes a particle with its starting position, target position, and color
  Particle(int startX, int startY, int targetX, int targetY, color targetColor) {
    x = startX;
    y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
    this.targetColor = targetColor;
  }

  void update() { // Update particle position
    // Move the particle 1% closer to the target using linear interpolation
    x += (targetX - x) * 0.1; 
    y += (targetY - y) * 0.1;
  }

  void display() { // Draw the particle
    fill(targetColor); // Always use the particle's target color
    noStroke();
    rect(round(x * (width / TOTAL_WIDTH)), round(y * (height / TOTAL_HEIGHT)), // Draws the pixel
         1, 1);
  }
}

// Send pixel data to the serial port
void sendToSerial() {
  if (serial != null) {
    loadPixels();
    int idx = 0;
    for (int y = 0; y < TOTAL_HEIGHT; y++) { // Loops through every pixel
      for (int x = 0; x < TOTAL_WIDTH; x++) {
        color c = get(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT));
        int rgb16 = packRGB16((int) red(c), (int) green(c), (int) blue(c)); // Retrieves its color
        buffer[idx++] = (byte) ((rgb16 >> 8) & 0xFF);
        buffer[idx++] = (byte) (rgb16 & 0xFF); // Converts the color to a 16-bit format
      }
    }
    serial.write('*'); // Start frame marker
    serial.write(buffer); // Send pixel data
  }
}

// Convert RGB to 16-bit color
int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}
