import processing.serial.*;

final int TOTAL_WIDTH = 32;
final int TOTAL_HEIGHT = 32;
final int BAUD_RATE = 921600;

// display time for every image
final int IMAGE_DISPLAY_TIME = 3000;

// States
final int GATHERING = 0;
final int HOLDING   = 1;
final int SCATTERING = 2;

Serial serial;
byte[] buffer;



PImage[] images;      
Particle[] particles; // One particle per pixel


int currentImageIndex = 0;  
int mode = GATHERING;       
int modeStartTime = 0;      

void setup() {
  size(32, 32);
  frameRate(80);

 
  images = new PImage[1];
  images[0] = loadImage("image1.png"); 
  images[0].resize(TOTAL_WIDTH, TOTAL_HEIGHT);

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2]; 

  
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT];

 
  initializeParticlesForImage(currentImageIndex);

  
  try {
    String portName = "/dev/cu.usbserial-02B5FCCE"; // Adjust the port name as needed
    serial = new Serial(this, portName, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0);


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
        
        images[0] = createRandomTreeVariant();
        
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


  sendToSerial();
}


// Initialize all particles for the 1st image 
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


// new positions/colors for the new image

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



void startScattering() {
  for (Particle p : particles) {
    p.startScatter();
  }
}


boolean allParticlesArrived() {
  for (Particle p : particles) {
    if (!p.arrived) {
      return false;
    }
  }
  return true;
}


boolean allParticlesScattered() {
  for (Particle p : particles) {
    if (!p.scattered) {
      return false;
    }
  }
  return true;
}


class Particle {
  float x, y;              // Current position
  float targetX, targetY;  // Target position
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

  // Update the current particle based on the mode
  void update(int mode) {
    switch (mode) {
      case GATHERING:
        scattered = false;
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

  // Assign new target for next image 
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


// Generate a new PImage of the same size 
// that includes the original skeleton plus random 
// trunk(s), roots, and flowers.

PImage createRandomTreeVariant() {
  // Use a PGraphics to draw programmatically
  PGraphics pg = createGraphics(TOTAL_WIDTH, TOTAL_HEIGHT);
  pg.beginDraw();
  

  pg.background(0, 0);
  
  pg.image(images[0], 0, 0);


  float trunkX = TOTAL_WIDTH / 2.0;
  float trunkY = TOTAL_HEIGHT * 0.5;
  float trunkWidth = random(2, 4);
  float trunkHeight = random(6, 12);
  

  pg.noStroke();
  pg.fill(random(80, 140), random(30, 70), random(0, 40));
  pg.rectMode(CENTER);
  pg.rect(trunkX, trunkY, trunkWidth, trunkHeight);



  int flowerCount = (int)random(3, 8);
  for (int i = 0; i < flowerCount; i++) {
    // random position near top half
    float fx = random(TOTAL_WIDTH * 0.25, TOTAL_WIDTH * 0.75);
    float fy = random(TOTAL_HEIGHT * 0.1, TOTAL_HEIGHT * 0.4);
    float size = random(2, 5);
    
    // random color
    pg.fill(random(180,255), random(100,255), random(150,255));
    pg.ellipse(fx, fy, size, size);
  }
  
  pg.endDraw();

  // Return this newly constructed image
  return pg.get();
}
