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
  size(32, 32);
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
    // Change this port name to whatever is correct on your system
    String portName = "/dev/cu.usbserial-02B5FCCE";
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
      // Random edges (so they gather from outside)
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
  float x, y;          // current position
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
// 7) Create a random 32×32 folk pattern, symmetrical left-right.
//    Uses only black (#000000), white (#FFFFFF), and red (#FF0000).
//    We avoid filling the entire screen by focusing on:
//      - top border
//      - bottom border
//      - central "flower band"
// --------------------------------------------------------------------
PImage createRandomFolkPattern() {
  PGraphics pg = createGraphics(MATRIX_WIDTH, MATRIX_HEIGHT);
  pg.beginDraw();
  pg.background(0); // black background

  pg.noStroke();

  // Only these 3 colors:
  color BLACK = color(0, 0, 0);
  color WHITE = color(255, 255, 255);
  color RED   = color(255, 0, 0);

  color[] palette = { BLACK, WHITE, RED };

  // We'll do:
  // 1) A random border pattern near the top (rows ~1..3).
  // 2) A random border pattern near the bottom (rows ~28..30).
  // 3) One or two "flower" bands in the middle (rows ~10..20).
  //    Each "flower" is made of squares/rhombuses.

  // -- 1) TOP BORDER PATTERN --
  drawBorderPattern(pg, 1, 3, palette);

  // -- 2) BOTTOM BORDER PATTERN --
  drawBorderPattern(pg, 28, 30, palette);

  // -- 3) MIDDLE FLOWER BANDS --
  int bandCount = (int) random(1, 3); // 1 or 2 random flower bands
  for (int b = 0; b < bandCount; b++) {
    int bandY = (int) random(10, 20); // random row ~10..20
    drawFlowerBand(pg, bandY, palette);
  }

  pg.endDraw();
  return pg.get();
}

// --------------------------------------------------------------------
// DRAW A HORIZONTAL BORDER PATTERN (rows from rowStart to rowEnd)
//   with left-right symmetry
// --------------------------------------------------------------------
void drawBorderPattern(PGraphics pg, int rowStart, int rowEnd, color[] palette) {
  for (int y = rowStart; y <= rowEnd; y++) {
    for (int x = 0; x < MATRIX_WIDTH/2; x++) {
      // Random chance to place a pixel
      if (random(1) < 0.6) {
        color c = palette[(int) random(palette.length)];
        pg.fill(c);
        pg.rect(x, y, 1, 1);

        // Mirror to the right
        int mirrorX = (MATRIX_WIDTH - 1) - x;
        pg.rect(mirrorX, y, 1, 1);
      }
    }
  }
}

// --------------------------------------------------------------------
// DRAW A "FLOWER BAND" centered around a single row (bandY).
// We place a few "flowers" across that row or near that row, with
// squares/rhombuses, left-right symmetrical.
// --------------------------------------------------------------------
void drawFlowerBand(PGraphics pg, int bandY, color[] palette) {
  // We'll place a few "flower centers" in the left half,
  // then mirror to the right. Let's say 2..4 random flower centers.
  int flowerCount = (int) random(2, 5);

  for (int i = 0; i < flowerCount; i++) {
    int x = (int) random(0, MATRIX_WIDTH/2); // left half
    int y = bandY + (int) random(-2, 3);     // slightly vary around bandY

    // Decide a color for the flower
    color c = palette[(int) random(palette.length)];

    // Draw a small "flower" (2-4 pixels wide) using squares or rhombuses
    int shapeType = (int) random(2);

    switch(shapeType) {
      case 0:
        // squares cluster
        drawSquaresFlower(pg, x, y, c);
        break;
      case 1:
        // rhombuses cluster
        drawRhombusFlower(pg, x, y, c);
        break;
    }

    // Mirror it to the right
    int mirrorX = (MATRIX_WIDTH - 1) - x;
    switch(shapeType) {
      case 0:
        drawSquaresFlower(pg, mirrorX, y, c);
        break;
      case 1:
        drawRhombusFlower(pg, mirrorX, y, c);
        break;
    }
  }
}

// --------------------------------------------------------------------
// A small "flower" made of squares around (cx, cy)
// --------------------------------------------------------------------
void drawSquaresFlower(PGraphics pg, int cx, int cy, color c) {
  pg.fill(c);

  // Center
  pg.rect(cx, cy, 1, 1);

  // Possibly add 1 or 2 squares around
  if (random(1) < 0.8 && cy-1 >= 0) pg.rect(cx, cy-1, 1, 1); // up
  if (random(1) < 0.8 && cy+1 < MATRIX_HEIGHT) pg.rect(cx, cy+1, 1, 1); // down
  if (random(1) < 0.8 && cx-1 >= 0) pg.rect(cx-1, cy, 1, 1); // left
  if (random(1) < 0.8 && cx+1 < MATRIX_WIDTH) pg.rect(cx+1, cy, 1, 1); // right
}

// --------------------------------------------------------------------
// A small "flower" made of rhombuses/diamonds around (cx, cy)
// We'll place the center and maybe diagonals
// --------------------------------------------------------------------
void drawRhombusFlower(PGraphics pg, int cx, int cy, color c) {
  pg.fill(c);

  // Center
  pg.rect(cx, cy, 1, 1);

  // Possibly place diagonal corners
  if (random(1) < 0.8 && cx-1 >= 0 && cy-1 >= 0) pg.rect(cx-1, cy-1, 1, 1);
  if (random(1) < 0.8 && cx+1 < MATRIX_WIDTH && cy-1 >= 0) pg.rect(cx+1, cy-1, 1, 1);
  if (random(1) < 0.8 && cx-1 >= 0 && cy+1 < MATRIX_HEIGHT) pg.rect(cx-1, cy+1, 1, 1);
  if (random(1) < 0.8 && cx+1 < MATRIX_WIDTH && cy+1 < MATRIX_HEIGHT) pg.rect(cx+1, cy+1, 1, 1);
}
