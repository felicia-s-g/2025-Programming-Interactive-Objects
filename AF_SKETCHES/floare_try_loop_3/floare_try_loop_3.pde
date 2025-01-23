import processing.serial.*;

final int TOTAL_WIDTH = 32;
final int TOTAL_HEIGHT = 32;
final int BAUD_RATE = 921600;
final int IMAGE_DISPLAY_TIME = 10000; // Time (in ms) for each image to stay fully assembled
final int CHAOS_DURATION = 2000; // Time (in ms) for the chaos phase

// Global Variables
Serial serial;
byte[] buffer;

PImage[] images; // Stores the images to cycle through
Particle[] particles; // An array of Particle objects representing individual pixels
int currentImageIndex = 0; // Tracks which image is being displayed
int lastImageChangeTime = 0; // Tracks the last time the image changed
boolean chaosPhase = false; // Tracks whether the particles are in the "chaos" phase

void setup() {
  size(32, 32);
  frameRate(80);

  // load and resize the images into array
  images = new PImage[7];
  for (int i = 0; i < 7; i++) {
    images[i] = loadImage("image" + (i + 1) + ".png"); 
    images[i].resize(TOTAL_WIDTH, TOTAL_HEIGHT);
  }

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2]; // For 16-bit color output
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT]; // One particle per pixel

  initializeParticles();

  // Initialize serial communication
  try {
    String portName = "/dev/tty.usbserial-02B62278"; // Adjust the port name as needed
    serial = new Serial(this, portName, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0); // Clear the screen

  // Check if it's time to transition to chaos
  if (!chaosPhase && millis() - lastImageChangeTime > IMAGE_DISPLAY_TIME) {
    chaosPhase = true; // Begin the chaos phase
    startChaos(); // Reassign random positions for chaos
  }

  // If chaos phase is over, move to the next image
  if (chaosPhase && millis() - lastImageChangeTime > IMAGE_DISPLAY_TIME + CHAOS_DURATION) {
    currentImageIndex = (currentImageIndex + 1) % images.length; // Cycle through the images
    initializeParticles(); // Reinitialize particles for the next image
    lastImageChangeTime = millis(); // Reset the timer
    chaosPhase = false; // End chaos phase
  }

  // Update and display particles
  for (Particle p : particles) {
    p.update(chaosPhase);
    p.display();
  }

  // Send the current state to the serial port
  sendToSerial();
}

// Initialize particles for the current image
void initializeParticles() {
  PImage sourceImage = images[currentImageIndex]; // Get the current image
  int index = 0;

  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      // Set the particle's starting position to its current position
      int startX = particles[index] != null ? (int) particles[index].x : (int) random(width);
      int startY = particles[index] != null ? (int) particles[index].y : (int) random(height);

      // Get the target pixel color from the image
      color targetColor = sourceImage.get(x, y);

      // Create a new Particle object or update an existing one
      if (particles[index] != null) {
        particles[index].reset(startX, startY, x, y, targetColor);
      } else {
        particles[index] = new Particle(startX, startY, x, y, targetColor);
      }

      index++;
    }
  }
}

// Assign new random positions for chaos
void startChaos() {
  for (Particle p : particles) {
    p.startChaos();
  }
}

class Particle {
  float x, y;        // Current position
  int targetX, targetY; // Target position
  color targetColor; // Target color
  int chaosX, chaosY; // Random chaos position
  boolean inChaos; // Is the particle in the chaos phase

  Particle(int startX, int startY, int targetX, int targetY, color targetColor) {
    reset(startX, startY, targetX, targetY, targetColor);
  }

  void reset(int startX, int startY, int targetX, int targetY, color targetColor) {
    x = startX;
    y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
    this.targetColor = targetColor;
    inChaos = false; // Reset chaos state
  }

  void update(boolean chaosPhase) {
    if (chaosPhase && !inChaos) {
      // Move the particle towards its chaos position
      x += (chaosX - x) * 0.05;
      y += (chaosY - y) * 0.05;

      // Snap into chaos position if close enough
      if (dist(x, y, chaosX, chaosY) < 0.5) {
        x = chaosX;
        y = chaosY;
        inChaos = true; // Chaos position reached
      }
    } else if (!chaosPhase) {
      // Move the particle towards its target position
      x += (targetX - x) * 0.05;
      y += (targetY - y) * 0.05;
    }
  }

  void startChaos() {
    // Assign a random position anywhere on the screen for chaos
    chaosX = (int) random(width);
    chaosY = (int) random(height);
    inChaos = false; // Reset inChaos state
  }

  void display() {
    fill(targetColor); // Always use the particle's target color
    noStroke();
    rect(round(x * (width / TOTAL_WIDTH)), round(y * (height / TOTAL_HEIGHT)),
         width / TOTAL_WIDTH, height / TOTAL_HEIGHT);
  }
}

// Send pixel data to the serial port
void sendToSerial() {
  if (serial != null) {
    loadPixels();
    int idx = 0;
    for (int y = 0; y < TOTAL_HEIGHT; y++) {
      for (int x = 0; x < TOTAL_WIDTH; x++) {
        color c = get(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT));
        int rgb16 = packRGB16((int) red(c), (int) green(c), (int) blue(c));
        buffer[idx++] = (byte) ((rgb16 >> 8) & 0xFF);
        buffer[idx++] = (byte) (rgb16 & 0xFF);
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
