import processing.serial.*;

final int TOTAL_WIDTH = 32;
final int TOTAL_HEIGHT = 32;
final int BAUD_RATE = 921600;

// Time (in ms) to display image *after* all particles have arrived
final int IMAGE_DISPLAY_TIME = 1000;

// States
final int GATHERING = 0;
final int HOLDING   = 1;
final int SCATTERING = 2;

Serial serial;
byte[] buffer;

PImage[] images;      // Stores the images to cycle through
Particle[] particles; // One particle per pixel

int currentImageIndex = 0;  // Tracks which image is being displayed
int mode = GATHERING;       // Current state: gathering, holding, or scattering
int modeStartTime = 0;      // Timestamp (ms) of when we switched into the current mode

void setup() {
  size(32, 32);
  frameRate(80);

  // Load and resize the images into array
  images = new PImage[7];
  for (int i = 0; i < 5; i++) {
    images[i] = loadImage("image" + (i + 1) + ".png");
    images[i].resize(TOTAL_WIDTH, TOTAL_HEIGHT);
  }

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2]; // For 16-bit color output

  // Create the particle array
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT];

  // Initialize all particles ONCE at setup
  //   1) Start them from random edges
  //   2) Assign them target positions/colors for the INITIAL image
  initializeParticlesForImage(currentImageIndex);

  // Initialize serial communication
  try {
    String portName = "/dev/tty.usbserial-02B62278"; // Adjust the port name as needed
    serial = new Serial(this, portName, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0);

  // --- Check for state transitions ---
  switch (mode) {
    case GATHERING:
      // If all particles have arrived, switch to HOLDING
      if (allParticlesArrived()) {
        mode = HOLDING;
        modeStartTime = millis();
      }
      break;

    case HOLDING:
      // After holding for IMAGE_DISPLAY_TIME, switch to SCATTERING
      if (millis() - modeStartTime > IMAGE_DISPLAY_TIME) {
        mode = SCATTERING;
        modeStartTime = millis();
        startScattering();
      }
      break;

    case SCATTERING:
      // If all particles have scattered, switch images and go GATHER again
      if (allParticlesScattered()) {
        // Move to the next image
        currentImageIndex = (currentImageIndex + 1) % images.length;
        // Reassign targets for the next image using the scattered positions as starting points
        assignTargetForImage(currentImageIndex);
        mode = GATHERING;
        modeStartTime = millis();
      }
      break;
  }

  // --- Update and display all particles ---
  for (Particle p : particles) {
    p.update(mode);
    p.display();
  }

  // --- Send the current frame to the serial device ---
  sendToSerial();
}

//------------------------------------------------------
// Initialize all particles for the FIRST image (once in setup)
//------------------------------------------------------
void initializeParticlesForImage(int imageIndex) {
  PImage sourceImage = images[imageIndex];
  int index = 0;

  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      // Start the particle on a random edge
      int startX, startY;
      if (random(1) < 0.5) {
        // Left or right edge
        startX = (random(1) < 0.5) ? 0 : width - 1;
        startY = int(random(height));
      } else {
        // Top or bottom edge
        startX = int(random(width));
        startY = (random(1) < 0.5) ? 0 : height - 1;
      }

      // Target pixel color from the image
      color targetColor = sourceImage.get(x, y);

      // Create new Particle
      particles[index++] = new Particle(startX, startY, x, y, targetColor);
    }
  }
}

//------------------------------------------------------
// Assign new target positions/colors for NEXT image
// (We do NOT reset the (x,y) of the particles, so the
//  new "start positions" are wherever they left off.)
//------------------------------------------------------
void assignTargetForImage(int imageIndex) {
  PImage sourceImage = images[imageIndex];
  int index = 0;

  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      color c = sourceImage.get(x, y);

      // Update each particle's target
      particles[index].setTarget(x, y, c);
      index++;
    }
  }
}

//------------------------------------------------------
// Trigger scattering: choose a random edge for each particle
//------------------------------------------------------
void startScattering() {
  for (Particle p : particles) {
    p.startScatter();
  }
}

//------------------------------------------------------
// Check if all particles arrived at their target
//------------------------------------------------------
boolean allParticlesArrived() {
  for (Particle p : particles) {
    if (!p.arrived) {
      return false;
    }
  }
  return true;
}

//------------------------------------------------------
// Check if all particles are scattered
//------------------------------------------------------
boolean allParticlesScattered() {
  for (Particle p : particles) {
    if (!p.scattered) {
      return false;
    }
  }
  return true;
}

//------------------------------------------------------
// CLASS: Particle
//------------------------------------------------------
class Particle {
  float x, y;              // Current position
  float targetX, targetY;  // Target position
  color targetColor;       
  boolean arrived;         // Have we reached our gather target?
  boolean scattered;       // Have we reached our scatter position?

  // Where we want to scatter to (random edge)
  float scatterX, scatterY;

  Particle(float startX, float startY, float tx, float ty, color c) {
    x = startX;
    y = startY;
    targetX = tx;
    targetY = ty;
    targetColor = c;
    arrived = false;
    scattered = false;
  }

  // Update the current particle based on the mode
  void update(int mode) {
    switch (mode) {
      case GATHERING:
        scattered = false; // We are gathering, so definitely not scattered
        // Move the particle towards the target
        if (!arrived) {
          x += (targetX - x) * 0.05;
          y += (targetY - y) * 0.05;

          if (dist(x, y, targetX, targetY) < 0.5) {
            x = targetX;
            y = targetY;
            arrived = true;
          }
        }
        break;

      case HOLDING:
        // Do nothing special; we stay in place.
        // If needed, ensure we mark arrived if we're not.
        if (!arrived) {
          arrived = true;
        }
        break;

      case SCATTERING:
        arrived = false; // If we’re scattering, we’re definitely not "arrived" at an image
        // Move the particle towards its scatter position
        if (!scattered) {
          x += (scatterX - x) * 0.05;
          y += (scatterY - y) * 0.05;

          if (dist(x, y, scatterX, scatterY) < 0.5) {
            x = scatterX;
            y = scatterY;
            scattered = true;
          }
        }
        break;
    }
  }

  // Assign new target for next image gather
  void setTarget(float tx, float ty, color c) {
    targetX = tx;
    targetY = ty;
    targetColor = c;
    arrived = false;   // We'll gather again
  }

  // Assign a random edge for scattering
  void startScatter() {
    float r = random(1);
    if (r < 0.5) {
      scatterX = (random(1) < 0.5) ? 0 : width - 1;
      scatterY = random(height);
    } else {
      scatterX = random(width);
      scatterY = (random(1) < 0.5) ? 0 : height - 1;
    }
    scattered = false;
  }

  void display() {
    // If we are in "gathered" position, use the target color
    // Otherwise you can choose how to color them in transition
    fill(targetColor);
    noStroke();
    rect(x * (width / float(TOTAL_WIDTH)), 
         y * (height / float(TOTAL_HEIGHT)), 
         width / float(TOTAL_WIDTH), 
         height / float(TOTAL_HEIGHT));
  }
}

//------------------------------------------------------
// Send the pixel data to the serial port
//------------------------------------------------------
void sendToSerial() {
  if (serial != null) {
    loadPixels();
    int idx = 0;
    for (int y = 0; y < TOTAL_HEIGHT; y++) {
      for (int x = 0; x < TOTAL_WIDTH; x++) {
        color c = get(x * (width / TOTAL_WIDTH), 
                      y * (height / TOTAL_HEIGHT));
        int rgb16 = packRGB16(int(red(c)), int(green(c)), int(blue(c)));
        buffer[idx++] = (byte)((rgb16 >> 8) & 0xFF);
        buffer[idx++] = (byte)(rgb16 & 0xFF);
      }
    }
    serial.write('*');      // Start frame marker
    serial.write(buffer);   // Send pixel data
  }
}

// Convert RGB to 16-bit color
int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}
