import processing.serial.*;

final int TOTAL_WIDTH = 32;
final int TOTAL_HEIGHT = 32;
final int BAUD_RATE = 921600;
final int IMAGE_DISPLAY_TIME = 10000; // Time (in ms) for each image to stay fully assembled

// Global Variables
Serial serial;
byte[] buffer;

PImage[] images; // Stores the images to cycle through
Particle[] particles; // An array of Particle objects representing individual pixels
int currentImageIndex = 0; // Tracks which image is being displayed
int lastImageChangeTime = 0; // Tracks the last time the image changed
boolean scattering = false; // Tracks whether the particles are scattering away

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

  // Check if it's time to transition
  if (!scattering && millis() - lastImageChangeTime > IMAGE_DISPLAY_TIME) {
    scattering = true; // Begin the scattering process
    startScattering(); // Reassign new random positions for scattering
  }

  // If all particles are scattered, move to the next image
  if (scattering && allParticlesScattered()) {
    currentImageIndex = (currentImageIndex + 1) % images.length; // Cycle through the images
    initializeParticles(); // Reinitialize particles for the next image
    lastImageChangeTime = millis(); // Reset the timer
    scattering = false; // Reset scattering state
  }

  // Update and display particles
  for (Particle p : particles) {
    p.update(scattering);
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
      // Set the particle's starting position to a random edge of the screen
      int startX, startY;
      if (random(1) < 0.5) {
        // Start on the left or right edge
        startX = random(1) < 0.5 ? 0 : width - 1;
        startY = (int) random(height);
      } else {
        // Start on the top or bottom edge
        startX = (int) random(width);
        startY = random(1) < 0.5 ? 0 : height - 1;
      }

      // Get the target pixel color from the image
      color targetColor = sourceImage.get(x, y);

      // Create a new Particle object
      particles[index++] = new Particle(startX, startY, x, y, targetColor);
    }
  }
}

// Reassign new random positions for scattering
void startScattering() {
  for (Particle p : particles) {
    p.startScatter();
  }
}

// Check if all particles are scattered
boolean allParticlesScattered() {
  for (Particle p : particles) {
    if (!p.isScattered()) {
      return false;
    }
  }
  return true;
}

// Particle class for individual pixel behavior
class Particle {
  float x, y;        // Current position
  int targetX, targetY; // Target position
  color targetColor; // Target color
  boolean arrived;   // Has particle reached target position
  int scatterX, scatterY; // Random scatter position
  boolean scattered; // Has particle scattered away

  Particle(int startX, int startY, int targetX, int targetY, color targetColor) {
    x = startX;
    y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
    this.targetColor = targetColor;
    arrived = false;
    scattered = false;
  }

  void update(boolean scattering) {
    if (!arrived) {
      // Move the particle towards the target
      x += (targetX - x) * 0.05;
      y += (targetY - y) * 0.05;

      if (dist(x, y, targetX, targetY) < 0.5) { // Snap into place
        x = targetX;
        y = targetY;
        arrived = true;
      }
    } else if (scattering && !scattered) {
      // Move the particle towards its scatter position
      x += (scatterX - x) * 0.05;
      y += (scatterY - y) * 0.05;

      if (dist(x, y, scatterX, scatterY) < 0.5) { // Snap into scatter position
        x = scatterX;
        y = scatterY;
        scattered = true;
      }
    }
  }

  void startScatter() {
    // Assign a random edge position for scattering
    if (random(1) < 0.5) {
      scatterX = random(1) < 0.5 ? 0 : width - 1; // Left or right edge
      scatterY = (int) random(height);
    } else {
      scatterX = (int) random(width);
      scatterY = random(1) < 0.5 ? 0 : height - 1; // Top or bottom edge
    }
    scattered = false; // Reset scattered state
  }

  boolean isScattered() {
    return scattered;
  }

  void display() {
    fill(arrived ? targetColor : 0); // Use target color if arrived, black otherwise
    noStroke();
    rect(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT),
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
