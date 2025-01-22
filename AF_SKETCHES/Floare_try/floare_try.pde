import processing.serial.*;

final int TOTAL_WIDTH  = 32;
final int TOTAL_HEIGHT = 32;
final int BAUD_RATE    = 921600;

Serial serial;
byte[] buffer;

PImage sourceImage;
Particle[] particles;

void setup() {
  size(32, 32);
  frameRate(60);
  
  sourceImage = loadImage("try_2.png");
  sourceImage.resize(TOTAL_WIDTH, TOTAL_HEIGHT); 

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2]; // For 16-bit color output
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT]; // One particle per pixel
  
  // Initialize particles (starting from edges or center randomly)
  int index = 0;
  
  for (int y = 0; y < TOTAL_HEIGHT; y++) { // loops over all rows of the image
    for (int x = 0; x < TOTAL_WIDTH; x++) { // loops over all columns of the image
    
      boolean startFromCenter = random(1) < 0.5; // Randomly decide start point (random nr. between 1 and 0)
      
      // if startFromCenter is true, starting position is the center of the canvas
      int startX = startFromCenter ? width / 2 : 
      
      
      (random(1) < 0.5 ? 0 : width - 1);
      
      //
      int startY = startFromCenter ? height / 2 : (random(1) < 0.5 ? 0 : height - 1);
      color targetColor = sourceImage.get(x, y); // Get target pixel color
      particles[index++] = new Particle(startX, startY, x, y, targetColor);
    }
  }

  // Setup serial connection
  String[] ports = Serial.list();
  printArray(ports);
  try {
    String portName = "/dev/tty.usbserial-02B62278"; // Replace with your port
    serial = new Serial(this, portName, BAUD_RATE);
    println("Serial port initialized: " + portName);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0);

  // Update and display all particles
  for (Particle p : particles) {
    p.update();
    p.display();
  }

  // Send current state to serial
  sendToSerial();
}

// Particle class to handle individual pixels
class Particle {
  float x, y;          // Current position
  int targetX, targetY; // Target (final) position
  color targetColor;   // Target pixel color
  boolean arrived;     // Has the particle reached its target?

  Particle(int startX, int startY, int targetX, int targetY, color targetColor) {
    this.x = startX;
    this.y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
    this.targetColor = targetColor;
    this.arrived = false;
  }

  void update() {
    if (!arrived) {
      // Move towards the target position
      x += (targetX - x) * 0.02; // Smooth movement
      y += (targetY - y) * 0.02;
      
      // stop moving when close enough to the target
      if (dist(x, y, targetX, targetY) < 0.5) {
        x = targetX;
        y = targetY;
        arrived = true;
      }
    }
  }

  void display() {
    if (arrived && brightness(targetColor) > 0) {
      fill(targetColor); // Use the target color
    } else {
      fill(0); // Black for non-arrived particles
    }
    noStroke();
    rect(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT), 
         width / TOTAL_WIDTH, height / TOTAL_HEIGHT);
  }
}

void sendToSerial() {
  if (serial != null) {
    loadPixels();
    int idx = 0;
    for (int y = 0; y < TOTAL_HEIGHT; y++) {
      for (int x = 0; x < TOTAL_WIDTH; x++) {
        color c = get(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT));
        int rgb16 = packRGB16((int) red(c), (int) green(c), (int) blue(c));
        buffer[idx++] = (byte) ((rgb16 >> 8) & 0xFF); // High byte
        buffer[idx++] = (byte) (rgb16 & 0xFF);        // Low byte
      }
    }
    serial.write('*');     // Start of frame
    serial.write(buffer);  // Pixel data
  }
}

// Pack RGB into 16-bit 5-6-5 format
int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}
