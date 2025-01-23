import processing.serial.*;

// --------------------------------------------------------------------
// CONFIG
// --------------------------------------------------------------------
final int MATRIX_WIDTH  = 32;
final int MATRIX_HEIGHT = 32;
final int BAUD_RATE     = 921600;

// States
final int GATHERING  = 0;
final int HOLDING    = 1;
final int SCATTERING = 2;

// Timings
final int IMAGE_DISPLAY_TIME = 2000; // ms to hold each pattern after gathering

// --------------------------------------------------------------------
// GLOBALS
// --------------------------------------------------------------------
Serial serial;
byte[] buffer;  // For sending 16-bit pixel data

// Particle array (one Particle per pixel on the 32×32 matrix)
Particle[] particles;

// The current pattern + next pattern (both are 32×32 images)
PImage currentPattern;
PImage nextPattern;

// State machine
int mode          = GATHERING;
int modeStartTime = 0;

// --------------------------------------------------------------------
// SETUP
// --------------------------------------------------------------------
void setup() {
  // IMPORTANT: size is forced to 32×32
  size(32,32);
  frameRate(60);

  // Initialize the first two random patterns
  currentPattern = createRandomFolkPattern();
  nextPattern    = createRandomFolkPattern();

  // Create particle array and data buffer for serial
  particles = new Particle[MATRIX_WIDTH * MATRIX_HEIGHT];
  buffer    = new byte[MATRIX_WIDTH * MATRIX_HEIGHT * 2];

  // Initialize the particles for the FIRST pattern
  initializeParticles(currentPattern);

  // Try to open the serial port
  try {
    String portName = "/dev/cu.usbserial-02B5FCCE"; // <--- Adapt for your setup
    serial = new Serial(this, portName, BAUD_RATE);
  } 
  catch (Exception e) {
    println("Serial port could not be opened...");
  }
}

// --------------------------------------------------------------------
// DRAW
// --------------------------------------------------------------------
void draw() {
  background(0);

  // State machine
  switch (mode) {
    case GATHERING:
      if (allParticlesArrived()) {
        mode = HOLDING;
        modeStartTime = millis();
      }
      break;

    case HOLDING:
      if (millis() - modeStartTime >= IMAGE_DISPLAY_TIME) {
        mode = SCATTERING;
        modeStartTime = millis();
        startScattering();
      }
      break;

    case SCATTERING:
      if (allParticlesScattered()) {
        // Move to the next pattern
        currentPattern = nextPattern;
        nextPattern    = createRandomFolkPattern();
        initializeParticles(currentPattern);

        mode = GATHERING;
        modeStartTime = millis();
      }
      break;
  }

  // Update & display the particles
  for (Particle p : particles) {
    p.update(mode);
    p.display();
  }

  // Send data to LED matrix
  sendToSerial();
}

// --------------------------------------------------------------------
// 1) Initialize Particles for the CURRENT pattern
//    We spawn them from random edges so they gather “in.”
// --------------------------------------------------------------------
void initializeParticles(PImage pattern) {
  int index = 0;
  for (int py = 0; py < MATRIX_HEIGHT; py++) {
    for (int px = 0; px < MATRIX_WIDTH; px++) {
      color c = pattern.get(px, py);

      float startX, startY;
      // Random edges
      if (random(1) < 0.5) {
        // left or right
        startX = (random(1) < 0.5) ? 0 : (MATRIX_WIDTH - 1);
        startY = random(MATRIX_HEIGHT);
      } else {
        // top or bottom
        startX = random(MATRIX_WIDTH);
        startY = (random(1) < 0.5) ? 0 : (MATRIX_HEIGHT - 1);
      }

      if (particles[index] == null) {
        particles[index] = new Particle(startX, startY, px, py, c);
      } else {
        Particle p = particles[index];
        p.x = startX;
        p.y = startY;
        p.setTarget(px, py, c);
        p.arrived   = false;
        p.scattered = false;
      }
      index++;
    }
  }
}

// --------------------------------------------------------------------
// 2) Start the scattering phase: move each Particle to random edges
// --------------------------------------------------------------------
void startScattering() {
  for (Particle p : particles) {
    p.startScatter();
  }
}

// --------------------------------------------------------------------
// 3) Check if all particles have arrived
// --------------------------------------------------------------------
boolean allParticlesArrived() {
  for (Particle p : particles) {
    if (!p.arrived) return false;
  }
  return true;
}

// --------------------------------------------------------------------
// 4) Check if all particles are scattered
// --------------------------------------------------------------------
boolean allParticlesScattered() {
  for (Particle p : particles) {
    if (!p.scattered) return false;
  }
  return true;
}

// --------------------------------------------------------------------
// 5) Particle class
// --------------------------------------------------------------------
class Particle {
  float x, y;          // current position in float, range [0..31]
  float targetX, targetY; 
  color targetColor;
  boolean arrived;
  boolean scattered;

  float scatterX, scatterY; // random edge for scattering

  Particle(float sx, float sy, float tx, float ty, color c) {
    x = sx; 
    y = sy;
    targetX = tx; 
    targetY = ty;
    targetColor = c;
    arrived     = false;
    scattered   = false;
  }

  void setTarget(float tx, float ty, color c) {
    targetX     = tx;
    targetY     = ty;
    targetColor = c;
    arrived     = false;
  }

  void startScatter() {
    // random edges
    if (random(1) < 0.5) {
      scatterX = (random(1) < 0.5) ? 0 : (MATRIX_WIDTH - 1);
      scatterY = random(MATRIX_HEIGHT);
    } else {
      scatterX = random(MATRIX_WIDTH);
      scatterY = (random(1) < 0.5) ? 0 : (MATRIX_HEIGHT - 1);
    }
    scattered = false;
  }

  void update(int mode) {
    float speed = 0.2; // gather/scatter speed factor
    switch(mode) {
      case GATHERING:
        scattered = false;
        if (!arrived) {
          x += (targetX - x) * speed;
          y += (targetY - y) * speed;
          if (dist(x, y, targetX, targetY) < 0.5) {
            x = targetX;
            y = targetY;
            arrived = true;
          }
        }
        break;

      case HOLDING:
        // do nothing
        break;

      case SCATTERING:
        arrived = false;
        if (!scattered) {
          x += (scatterX - x) * speed;
          y += (scatterY - y) * speed;
          if (dist(x, y, scatterX, scatterY) < 0.5) {
            x = scatterX;
            y = scatterY;
            scattered = true;
          }
        }
        break;
    }
  }

  // Draw 1×1 pixel at integer coords
  void display() {
    // Round positions to int so we fill exactly one pixel
    int ix = floor(x);
    int iy = floor(y);

    fill(targetColor);
    noStroke();
    rect(ix, iy, 1, 1);
  }
}

// --------------------------------------------------------------------
// 6) Serial Communication: Send 32×32 to LED matrix
// --------------------------------------------------------------------
void sendToSerial() {
  if (serial == null) return;

  // Because the window is exactly 32×32,
  // each pixel is exactly 1 screen pixel, so we can read get(x, y) directly.
  loadPixels();
  int idx = 0;
  for (int py = 0; py < MATRIX_HEIGHT; py++) {
    for (int px = 0; px < MATRIX_WIDTH; px++) {
      color c = get(px, py); 
      int rgb16 = packRGB16(int(red(c)), int(green(c)), int(blue(c)));
      buffer[idx++] = (byte)((rgb16 >> 8) & 0xFF);
      buffer[idx++] = (byte)(rgb16 & 0xFF);
    }
  }
  serial.write('*'); // marker
  serial.write(buffer);
}

// Convert 24-bit color to 16-bit (565)
int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}

// --------------------------------------------------------------------
// 7) Create a random 32×32 folk pattern using basic shapes
// --------------------------------------------------------------------
PImage createRandomFolkPattern() {
  // We'll draw into a temporary PGraphics of size 32×32
  PGraphics pg = createGraphics(MATRIX_WIDTH, MATRIX_HEIGHT);
  pg.beginDraw();
  pg.background(0); // black background

  pg.noStroke();

  // Simple color palette
  color[] palette = {
    color(255),    // white
    color(255, 0, 0),   // red
    color(0),          // black
    color(0, 200, 0),  // green
    color(255, 200, 0) // yellow
  };

  // Draw a random number of shapes
  int shapeCount = (int) random(8, 15); 
  for (int i = 0; i < shapeCount; i++) {
    color c = palette[(int) random(palette.length)];
    pg.fill(c);

    // Choose a shape type
    int shapeType = (int) random(4);
    // 0 = rectangle
    // 1 = line
    // 2 = rhombus
    // 3 = circle

    // Random position in top-left quadrant
    float x = random(MATRIX_WIDTH/2);
    float y = random(MATRIX_HEIGHT/2);
    float w = random(2, 8);
    float h = random(2, 8);

    // Draw shape in that quadrant
    drawShape(pg, shapeType, x, y, w, h);

    // Mirror horizontally + vertically for symmetry
    drawShape(pg, shapeType, MATRIX_WIDTH-1 - x - w, y, w, h);
    drawShape(pg, shapeType, x, MATRIX_HEIGHT-1 - y - h, w, h);
    drawShape(pg, shapeType, MATRIX_WIDTH-1 - x - w, 
              MATRIX_HEIGHT-1 - y - h, w, h);
  }

  pg.endDraw();
  return pg.get();
}

// --------------------------------------------------------------------
// Helper to draw a single shape in the PGraphics
// --------------------------------------------------------------------
void drawShape(PGraphics pg, int shapeType, float x, float y, float w, float h) {
  pg.pushStyle(); // so line settings, etc., don't leak out
  switch(shapeType) {
    case 0: // rectangle
      pg.rect(x, y, w, h);
      break;
    case 1: // line
      pg.stroke(pg.fillColor);
      pg.strokeWeight(1);
      pg.line(x, y, x + w, y + h);
      break;
    case 2: // rhombus (diamond)
      pg.noStroke();
      pg.quad(x + w*0.5, y,
              x + w,     y + h*0.5,
              x + w*0.5, y + h,
              x,         y + h*0.5);
      break;
    case 3: // circle
      pg.noStroke();
      pg.ellipse(x + w*0.5, y + h*0.5, w, h);
      break;
  }
  pg.popStyle();
}
