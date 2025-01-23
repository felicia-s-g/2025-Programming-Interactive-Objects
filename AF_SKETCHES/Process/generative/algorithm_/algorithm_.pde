import processing.serial.*;

// constants
// >>>>>>>>>>>>>>>>>>>>>>>>
final int TOTAL_WIDTH       = 32;
final int TOTAL_HEIGHT      = 32;
final int BAUD_RATE         = 921600;
final int IMAGE_DISPLAY_TIME = 3000;

// state machine
final int GATHERING   = 0;
final int HOLDING     = 1;
final int SCATTERING  = 2;

// global
// >>>>>>>>>>>>>>>>>>>>>>>>
Serial serial;
byte[] buffer;

PImage[] images;
Particle[] particles;

int currentImageIndex = 1;
int mode = GATHERING;
int modeStartTime = 0;

// setup
// >>>>>>>>>>>>>>>>>>>>>>>>
void setup() {
  size(32 * 10, 32 * 10);
  frameRate(80);

  // init img
  images = new PImage[2];

  images[0] = loadImage("image1.png");
  images[0].resize(TOTAL_WIDTH, TOTAL_HEIGHT);

  images[1] = images[0].copy();

  // init particles
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT];
  // initializeParticlesForImage(currentImageIndex);

  // init buffer
  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2];

  // init serial comm
  try {
    String portName = "/dev/tty.usbserial-02B62278";
    serial = new Serial(this, portName, BAUD_RATE);
  }
  catch (Exception e) {
    println("Serial port not initialized...");
  }
}

// draw
// >>>>>>>>>>>>>>>>>>>>>>>>
void draw() {

  background(0);

  // state machine
  // >>>>>>>>>>>>>>>>>>>>>>>>
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

      // TO WRITE
      images[1] = createRandomTreeVariant();

      assignTargetForImage(currentImageIndex);

      mode = GATHERING;
      modeStartTime = millis();
    }
    break;
  }

  for (Particle p : particles) {
    p.update(mode);
    p.display();
  }

  sendToSerial();
}

// init particles for current image
// >>>>>>>>>>>>>>>>>>>>>>>>
void initializeParticlesForImage(int imageIndex) {
  PImage sourceImage = images[imageIndex];
  int index = 0;

  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      int startX, startY;
      if (random(1) < 0.5) {
        startX = (random(1) < 0.5) ? 0 : width - 1;
        startY = int(random(height));
      } else {
        startX = int(random(width));
        startY = (random(1) < 0.5) ? 0 : height - 1;
      }
      color targetColor = sourceImage.get(x, y);
      particles[index++] = new Particle(startX, startY, x, y, targetColor);
    }
  }
}

// pixels = particles 
// >>>>>>>>>>>>>>>>>>>>>>>>
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

// scattering function
// >>>>>>>>>>>>>>>>>>>>>>>>
void startScattering() {
  for (Particle p : particles) {
    p.startScatter();
  }
}

// is everyone here?
// >>>>>>>>>>>>>>>>>>>>>>>>
boolean allParticlesArrived() {
  for (Particle p : particles) {
    if (!p.arrived) {
      return false;
    }
  }
  return true;
}

// is everyone there?
// >>>>>>>>>>>>>>>>>>>>>>>>
boolean allParticlesScattered() {
  for (Particle p : particles) {
    if (!p.scattered) {
      return false;
    }
  }
  return true;
}

// create particle object
// >>>>>>>>>>>>>>>>>>>>>>>>
class Particle {
  float x, y;
  float targetX, targetY;
  color targetColor;
  boolean arrived;
  boolean scattered;

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

// state machine update
// >>>>>>>>>>>>>>>>>>>>>>>>
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

  void setTarget(int tx, int ty, color c) {
    targetX = tx;
    targetY = ty;
    targetColor = c;
    arrived = false;
  }

// create particle scattering
// >>>>>>>>>>>>>>>>>>>>>>>>
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
    rect(round(x * (width / float(TOTAL_WIDTH))),
      round(y * (height / float(TOTAL_HEIGHT))),
      width / float(TOTAL_WIDTH),
      height / float(TOTAL_HEIGHT));
  }
}

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
    serial.write('*');
    serial.write(buffer);
  }
}

// RGB to 16-bit color
int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}







// ANTONIA IS ALSO WRITING THIS >>>


// actual tree creation
// >>>>>>>>>>>>>>>>>>>>>>>>
void createRandomTreeVariant() { // actually PImage createRandomTreeVariant() {

  PGraphics pg = createGraphics(TOTAL_WIDTH, TOTAL_HEIGHT);

  pg.beginDraw();
  pg.background(0);
  pg.image(images[0], 0, 0);

  // 1) draw trunk (2px)
  float trunkX = TOTAL_WIDTH / 2.0;
  float trunkHeight = random(8, 20);
  float trunkTopY = TOTAL_HEIGHT - trunkHeight;
  
  pg.noStroke();
  pg.fill(56, 150, 35);
  pg.rect(trunkX, trunkTopY, 2, trunkHeight);

  // 2) draw random branches
  //    random y position [on trunk!], random #
  //    length & shape
  //    .fill(...);
  //    .rect(...);

  // 3) draw random flowers / berries
  //    random position, random #
  //    make sure they don't overlap if needed
  //    .rect(...);

  //    .endDraw();
}
