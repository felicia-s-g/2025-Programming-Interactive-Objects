import processing.serial.*;

final int MATRIX_WIDTH  = 32;
final int MATRIX_HEIGHT = 32;
final int BAUD_RATE     = 921600;

// States
final int GATHERING  = 0;
final int HOLDING    = 1;
final int SCATTERING = 2;

// Timings
final int IMAGE_DISPLAY_TIME = 2000; // ms to hold each pattern after gathering

Serial serial;
byte[] buffer;  // For sending 16-bit pixel data


Particle[] particles;


PImage currentPattern;
PImage nextPattern;


int mode = GATHERING;
int modeStartTime = 0;


void setup() {
  
  size(32, 32);
  frameRate(60);

 
  currentPattern = createRandomFolkPattern();
  nextPattern = createRandomFolkPattern();

 
  particles = new Particle[MATRIX_WIDTH * MATRIX_HEIGHT];
  buffer = new byte[MATRIX_WIDTH * MATRIX_HEIGHT * 2];

  
  initializeParticles(currentPattern);

 
  try {
   
    String portName = "/dev/cu.usbserial-02B5FCCE";
    serial = new Serial(this, portName, BAUD_RATE);
  } 
  catch (Exception e) {
    println("Serial port could not be opened...");
  }
}



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


void startScattering() {
  for (Particle p : particles) {
    p.startScatter();
  }
}


boolean allParticlesArrived() {
  for (Particle p : particles) {
    if (!p.arrived) return false;
  }
  return true;
}


boolean allParticlesScattered() {
  for (Particle p : particles) {
    if (!p.scattered) return false;
  }
  return true;
}


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


PImage createRandomFolkPattern() {
  PGraphics pg = createGraphics(MATRIX_WIDTH, MATRIX_HEIGHT);
  pg.beginDraw();
  pg.background(0);  // black


  pg.noStroke();


  color[] palette = {
    color(0xFFBF2928), // #BF2928
    color(0xFFDA7AA2), // #DA7AA2
    color(0xFFF5F5F5)  // #F5F5F5
  };


  // then mirror each one to the right half.  
  for (int y = 0; y < MATRIX_HEIGHT; y++) {
    for (int x = 0; x < MATRIX_WIDTH/2; x++) {

      float chance = random(1);
      if (chance < 0.2) {
    
        color c = palette[(int) random(palette.length)];
        pg.fill(c);


        int shapeType = (int) random(3);
        switch(shapeType) {
          case 0: 
        
            pg.rect(x, y, 1, 1);
            break;

          case 1:
      
            drawCross(pg, x, y, c);
            break;

          case 2:

            drawDiamond(pg, x, y, c);
            break;
        }

       
        int mirrorX = (MATRIX_WIDTH - 1) - x;
        

        switch(shapeType) {
          case 0:
            // Dot
            pg.rect(mirrorX, y, 1, 1);
            break;
          case 1:
            drawCross(pg, mirrorX, y, c);
            break;
          case 2:
            drawDiamond(pg, mirrorX, y, c);
            break;
        }
      }
    }
  }

  pg.endDraw();
  return pg.get();
}

// Small cross shape (center + up/down/left/right)
void drawCross(PGraphics pg, int cx, int cy, color c) {
  // Center
  pg.rect(cx, cy, 1, 1);
  // Up
  if (cy - 1 >= 0) pg.rect(cx, cy - 1, 1, 1);
  // Down
  if (cy + 1 < MATRIX_HEIGHT) pg.rect(cx, cy + 1, 1, 1);
  // Left
  if (cx - 1 >= 0) pg.rect(cx - 1, cy, 1, 1);
  // Right
  if (cx + 1 < MATRIX_WIDTH) pg.rect(cx + 1, cy, 1, 1);
}

// Small diamond shape (center + diagonals)
void drawDiamond(PGraphics pg, int cx, int cy, color c) {
  // Center
  pg.rect(cx, cy, 1, 1);
  // Up-Left
  if (cx - 1 >= 0 && cy - 1 >= 0) pg.rect(cx - 1, cy - 1, 1, 1);
  // Up-Right
  if (cx + 1 < MATRIX_WIDTH && cy - 1 >= 0) pg.rect(cx + 1, cy - 1, 1, 1);
  // Down-Left
  if (cx - 1 >= 0 && cy + 1 < MATRIX_HEIGHT) pg.rect(cx - 1, cy + 1, 1, 1);
  // Down-Right
  if (cx + 1 < MATRIX_WIDTH && cy + 1 < MATRIX_HEIGHT) pg.rect(cx + 1, cy + 1, 1, 1);
}
