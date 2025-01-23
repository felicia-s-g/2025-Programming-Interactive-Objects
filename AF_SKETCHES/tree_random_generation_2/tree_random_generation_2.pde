import processing.serial.*;

final int TOTAL_WIDTH = 32;
final int TOTAL_HEIGHT = 32;
final int BAUD_RATE = 921600;

// Time (in ms) to display image *after* all particles have arrived
final int IMAGE_DISPLAY_TIME = 3000;

// States
final int GATHERING   = 0;
final int HOLDING     = 1;
final int SCATTERING  = 2;

Serial serial;
byte[] buffer;

// images[0] = the original skeleton (inspiration)
// images[1] = a random variant derived from images[0]
PImage[] images;      
Particle[] particles; // One particle per pixel

// We'll gather from images[1]
int currentImageIndex = 1;  
int mode = GATHERING;       
int modeStartTime = 0;

void setup() {
  size(32, 32);
  frameRate(80);

  // 1) Create array of 2 images
  images = new PImage[2];

  // 2) Load the original skeleton into images[0]
  images[0] = loadImage("try_2.png");
  images[0].resize(TOTAL_WIDTH, TOTAL_HEIGHT);

  // 3) Initialize images[1] as a copy of images[0] so the first gather
  //    uses the original skeleton
  images[1] = images[0].copy();

  // Allocate the 16-bit color buffer
  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2];

  // Create the particle array
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT];

  // Initialize all particles for images[1] (the first image to gather)
  initializeParticlesForImage(currentImageIndex);

  // Initialize serial communication
  try {
    String portName = "/dev/cu.usbserial-02B5FCCE"; // <-- Adjust as needed!
    serial = new Serial(this, portName, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0);

  // --- State machine ---
  switch (mode) {
    case GATHERING:
      if (allParticlesArrived()) {
        mode = HOLDING;
        modeStartTime = millis();
      }
      break;

    case HOLDING:
      if (millis() - modeStartTime > IMAGE_DISPLAY_TIME) {
        mode = SCATTERING;
        modeStartTime = millis();
        startScattering();
      }
      break;

    case SCATTERING:
      if (allParticlesScattered()) {
        // Generate a brand-new random variant based on images[0]
        images[1] = createRandomTreeVariant();
        // Reassign targets to the new image
        assignTargetForImage(currentImageIndex);

        mode = GATHERING;
        modeStartTime = millis();
      }
      break;
  }

  // Update and display all particles
  for (Particle p : particles) {
    p.update(mode);
    p.display();
  }

  // Send the current frame out the serial port
  sendToSerial();
}

//------------------------------------------------------
// Initialize all particles for a given image index
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

      // Create the Particle
      particles[index++] = new Particle(startX, startY, x, y, targetColor);
    }
  }
}

//------------------------------------------------------
// Assign new target positions/colors for the next gather
//------------------------------------------------------
void assignTargetForImage(int imageIndex) {
  PImage sourceImage = images[imageIndex];
  int index = 0;

  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      color c = sourceImage.get(x, y);
      particles[index].setTarget(x, y, c);
      index++;
    }
  }
}

//------------------------------------------------------
// Trigger scattering (explosion)
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
// Particle class
//------------------------------------------------------
class Particle {
  float x, y;              // Current position
  float targetX, targetY;  // Target position
  color targetColor;       
  boolean arrived;         
  boolean scattered;       

  float scatterX, scatterY; // Where we want to scatter to

  Particle(float startX, float startY, float tx, float ty, color c) {
    x = startX;
    y = startY;
    targetX = tx;
    targetY = ty;
    targetColor = c;
    arrived = false;
    scattered = false;
  }

  void update(int mode) {
    switch (mode) {
      case GATHERING:
        scattered = false;
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
        if (!arrived) {
          arrived = true;
        }
        break;

      case SCATTERING:
        arrived = false;
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

  void setTarget(float tx, float ty, color c) {
    targetX = tx;
    targetY = ty;
    targetColor = c;
    arrived = false;
  }

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
    fill(targetColor);
    noStroke();
    rect(x * (width / float(TOTAL_WIDTH)), 
         y * (height / float(TOTAL_HEIGHT)), 
         width / float(TOTAL_WIDTH), 
         height / float(TOTAL_HEIGHT));
  }
}

//------------------------------------------------------
// Send the 32x32 pixel data out the serial port
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
    serial.write('*');    // Start-of-frame marker
    serial.write(buffer); // Send the entire pixel buffer
  }
}

//------------------------------------------------------
// Convert 24-bit R,G,B into 16-bit (RGB565) color
//------------------------------------------------------
int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}

//------------------------------------------------------
// Create a new random tree variant based on images[0]
// (the "inspiration" skeleton).
//  - 1-pixel wide trunk
//  - Non-overlapping flowers that must touch trunk
//  - 6..12 flowers
//------------------------------------------------------
PImage createRandomTreeVariant() {
  // We'll draw on a PGraphics, then return it as a PImage
  PGraphics pg = createGraphics(TOTAL_WIDTH, TOTAL_HEIGHT);
  pg.beginDraw();

  // 1) Start with black background (or optional alpha)
  pg.background(0);

  // 2) Draw the original skeleton from images[0]
  pg.image(images[0], 0, 0);

  // 3) Draw a 1-pixel-wide trunk (vertical)
  float trunkX = TOTAL_WIDTH / 2.0;     // horizontally centered
  float trunkHeight = random(8, 16);    // random trunk length
  float trunkTopY = TOTAL_HEIGHT - trunkHeight;  // top of trunk
  pg.noStroke();
  pg.fill(120, 60, 0); // brownish trunk color
  pg.rectMode(CORNER);
  pg.rect(trunkX, trunkTopY, 1, trunkHeight);

  // 4) Place random flowers so they:
  //    - Touch the trunk
  //    - Don't overlap each other
  //    - Count between 6..12
  int flowerCount = (int) random(6, 13); // 6..12
  float minDist = 1.0; // gap so flowers don't overlap

  ArrayList<PVector> centers = new ArrayList<PVector>();
  ArrayList<Float> radii   = new ArrayList<Float>();

  for (int i = 0; i < flowerCount; i++) {
    boolean placed = false;
    for (int attempts = 0; attempts < 50 && !placed; attempts++) {
      float flowerSize = random(2, 5);
      float r = flowerSize / 2.0;

      // Decide if the flower is on left or right side of the trunk
      boolean leftSide = random(1) < 0.5;
      float cx = leftSide ? trunkX - r : trunkX + r;

      // Y is randomly above the trunk top (could adjust range as you like)
      float cy = trunkTopY - random(2, 8);

      // Check overlap with existing flowers
      boolean overlap = false;
      for (int j = 0; j < centers.size(); j++) {
        float dx = cx - centers.get(j).x;
        float dy = cy - centers.get(j).y;
        float distSq = dx * dx + dy * dy;
        float needed = radii.get(j) + r + minDist;
        if (distSq < needed * needed) {
          overlap = true;
          break;
        }
      }

      if (!overlap) {
        centers.add(new PVector(cx, cy));
        radii.add(r);
        placed = true;
      }
    }
  }

  // Draw all the flowers
  for (int i = 0; i < centers.size(); i++) {
    PVector fc = centers.get(i);
    float rr = radii.get(i);
    pg.noStroke();
    pg.fill(random(180,255), random(100,255), random(150,255));
    pg.ellipse(fc.x, fc.y, rr * 2, rr * 2);
  }

  pg.endDraw();
  return pg.get();
}
