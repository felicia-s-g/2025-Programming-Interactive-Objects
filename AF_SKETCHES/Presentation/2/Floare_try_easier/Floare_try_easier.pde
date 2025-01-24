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

  // load and resize the source image
  sourceImage = loadImage("Flower_03_inverted.png");
  sourceImage.resize(TOTAL_WIDTH, TOTAL_HEIGHT);

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2]; // For 16-bit color output
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT]; // One particle per pixel

  // initialize particles (starting from edges or center randomly)
  int index = 0;
  
  for (int y = 0; y < TOTAL_HEIGHT; y++) { // loops over rows
    for (int x = 0; x < TOTAL_WIDTH; x++) { // loops over columns
      
      // random starting positions (center or edges)
      boolean startFromCenter = random(1) < 0.5;  // random(1) generates a random nr between 0 (inclusive) and 1 (exclusive).
      
      // ternary operator to decide a value based on a random condition
      // sets the particle's target position (x, y) to match the pixel's position in the grid >>>>>
      // if true, the value becomes 0, if false the value becomes width -1
      int startX = startFromCenter ? width / 2 : (random(1) < 0.5 ? 0 : width - 1);
      int startY = startFromCenter ? height / 2 : (random(1) < 0.5 ? 0 : height - 1);
      
      // get the target pixel color from the image
      color targetColor = sourceImage.get(x, y);
      
      // creates a new Particle object and stores it in the particles array.
      particles[index++] = new Particle(startX, startY, x, y, targetColor);
    }
  }

  // Initialize serial communication
  try {
    String portName = "/dev/cu.usbserial-02B62278"; // PORT IS HERE
    serial = new Serial(this, portName, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0); // clears screen

  // Update and display particles
  for (Particle p : particles) { // iterates over all particles
    p.update(); // calls update() to move each particle closer to its target position.
    p.display(); // calls display() to draw the particle on the canvas.
  }

  // Send the current state to the serial port
  sendToSerial();
}

// Particle class for individual pixel behavior
  class Particle { // This defines how individual pixels (particles) behave.
  float x, y;        // current position
  int targetX, targetY; // target position
  color targetColor; // target color
  boolean arrived;   // has particle reached target position

  // Initializes a particle with its starting position, target position, and color.
    Particle(int startX, int startY, int targetX, int targetY, color targetColor) {
    x = startX;
    y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
    this.targetColor = targetColor;
    arrived = false;
  }

  void update() { // update particle position
    if (!arrived) { // if the particle hasn’t reached its target, moves it 5% closer to the target
      
      x += (targetX - x) * 0.01; // smooth move
      y += (targetY - y) * 0.01; // uses linear interpolation
      
      // if the particle is close enough to the target, snaps it into place and marks it as arrived.
      if (dist(x, y, targetX, targetY) < 0.5) {
        x = targetX;
        y = targetY;
        arrived = true;
      }
    }
  }

  void display() { // draws the particle
    fill(arrived ? targetColor : 0); // Use target color if arrived, if not then black
    noStroke();
    rect(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT), // draws the pixel, gets the size by division
         width / TOTAL_WIDTH, height / TOTAL_HEIGHT);
  }
}

// Send pixel data to the serial port
void sendToSerial() {
  if (serial != null) {
    loadPixels();
    int idx = 0;
    // index variable to keep track of the current position within an array, specifically the buffer array. 
    // ensures program writes the pixel data sequentially into the correct locations in the array.
    for (int y = 0; y < TOTAL_HEIGHT; y++) { //  Loops through every pixel
      for (int x = 0; x < TOTAL_WIDTH; x++) {
        color c = get(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT));
        int rgb16 = packRGB16((int) red(c), (int) green(c), (int) blue(c)); // retrieves its color
        buffer[idx++] = (byte) ((rgb16 >> 8) & 0xFF);
        buffer[idx++] = (byte) (rgb16 & 0xFF); // converts the color to a 16-bit format
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
