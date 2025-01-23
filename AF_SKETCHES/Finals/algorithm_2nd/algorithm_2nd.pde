import processing.serial.*;


// constants

final int TOTAL_WIDTH         = 32;
final int TOTAL_HEIGHT        = 32;
final int BAUD_RATE           = 921600;
final int IMAGE_DISPLAY_TIME  = 4000;  // display duration for each image
final int CHAOS_DURATION      = 2000;  // explosion duration

// distance between flowers 
final float MIN_FLOWER_DIST   = 1.0;


// colors
final color[] ALLOWED_COLORS = {
  color(207, 41, 69),    // red
  color(218, 122, 162),  // pink
  color(211, 144, 1),    // yellow
  color(70, 164, 202),   // blue
  color(0, 122, 82),     // emerald
  color(56, 150, 35)     // green
};


Serial serial;
byte[] buffer;

Particle[] particles;       
int lastImageChangeTime = 0; // Tracks the last time the tree changed
boolean chaosPhase = false;  // Verifies if the explosion is happening

PImage startImage;           

void setup() {
  size(32,32);
  frameRate(80);


  startImage = loadImage("image1.png");
  if (startImage == null) {
    exit();
  }
  startImage.resize(TOTAL_WIDTH, TOTAL_HEIGHT);

  reinforceTrunk();

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2]; 
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT]; 

  // Generate the first variation from the start image
  initializeParticles();

  // Initialize serial communication
  try {
    String portName = "/dev/cu.usbserial-02B5FCCE"; // Update this to your serial port
    serial = new Serial(this, portName, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0); 

  // check time for explosion 
  if (!chaosPhase && millis() - lastImageChangeTime > IMAGE_DISPLAY_TIME) {
    chaosPhase = true;
    startChaos(); 
  }

  // generates new variation after explosion
  if (chaosPhase && millis() - lastImageChangeTime > IMAGE_DISPLAY_TIME + CHAOS_DURATION) {
    initializeParticles();
    lastImageChangeTime = millis();
    chaosPhase = false; 
  }

 
  for (Particle p : particles) {
    p.update(chaosPhase);
    p.display();
  }

  sendToSerial();
}



void initializeParticles() {
  PImage sourceImage = generateSymmetricalTree();

  // Assign or reset each particle's position & target color
  int index = 0;
  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      int startX = particles[index] != null ? (int) particles[index].x : (int) random(width);
      int startY = particles[index] != null ? (int) particles[index].y : (int) random(height);

      color targetColor = sourceImage.get(x, y);

      if (particles[index] != null) {
        particles[index].reset(startX, startY, x, y, targetColor);
      } else {
        particles[index] = new Particle(startX, startY, x, y, targetColor);
      }
      index++;
    }
  }
}



PImage generateSymmetricalTree() {
  
  PGraphics pg = createGraphics(TOTAL_WIDTH, TOTAL_HEIGHT);
  pg.beginDraw();
  pg.background(0);

  
  pg.image(startImage, 0, 0);

  // place trunk in the middle 
  int trunkCenterX = TOTAL_WIDTH / 2;

  // branches (right + mirror left)
  int numBranches = int(random(3, 8));
  for (int i = 0; i < numBranches; i++) {
   
    int branchBaseY = int(random(10, TOTAL_HEIGHT - 5)); // random position on the trunk
    float length = random(3, 12); // random lenght
    float angleDeg = random(20, 70); //random angle
    color branchColor = getRandomAllowedColor(); //random color

    
    drawBranch(pg, trunkCenterX, branchBaseY, length, angleDeg, branchColor); // draw right branch
    drawBranch(pg, trunkCenterX, branchBaseY, length, -angleDeg, branchColor); // mirror left branch
  }

  // leaves (right + mirror left)
  if (random(1) < 0.8) {
    int numLeaves = int(random(5, 15));
    for (int i = 0; i < numLeaves; i++) {
      float leafY = random(5, TOTAL_HEIGHT - 5);
      float xOffset = random(2, 10);
      float size = random(1, 3); // limit size 
      color leafColor = getRandomAllowedColor();

      float leafXRight = trunkCenterX + xOffset;
      drawLeaf(pg, leafXRight, leafY, leafColor, size); //  draw right leaf

     
      float leafXLeft = trunkCenterX - xOffset;
      drawLeaf(pg, leafXLeft, leafY, leafColor, size); // mirror left leaf
    }
  }

  //  flowers (right + mirror left)
  if (random(1) < 0.6) {
    int numFlowers = int(random(2, 6));

    // Initialize a fixed-size array to store placed flower positions on the right side
    PVector[] placedFlowersRight = new PVector[numFlowers];
    int placedCount = 0;  // Number of flowers successfully placed

    for (int i = 0; i < numFlowers; i++) {
      float size = random(1, 3);  // limit flower size (prevent them from being too big)
      color flowerColor = getRandomAllowedColor();

     // flower positioning
      boolean placed = false;
      for (int attempt = 0; attempt < 20; attempt++) {
        float flowerY = random(5, TOTAL_HEIGHT - 5);
        float xOffset = random(5, 12);
        float fxRight = trunkCenterX + xOffset;

        // check distance between flowers
        if (isFarEnough(fxRight, flowerY, placedFlowersRight, placedCount, MIN_FLOWER_DIST)) {
          drawFlower(pg, fxRight, flowerY, flowerColor, size); // draw right flower 

          
          float fxLeft = trunkCenterX - xOffset;
          drawFlower(pg, fxLeft, flowerY, flowerColor, size); // mirror left flower 

          
          placedFlowersRight[placedCount] = new PVector(fxRight, flowerY); // store flower position 
          placedCount++;

          placed = true;
          break; 
        }
      }
      // If not placed after 20 attempts, skip to the next flower
    }
  }

  // reinforce the first image again to ensure it's not altered by new elements
  reinforceTrunk(pg);

  pg.endDraw();
  return pg.get(); //return new image
}


// verify the trunk to ensure it's exactly 2 pixels wide and matches the start image

void reinforceTrunk() {
  PImage reinforcedImage = startImage.copy();

  //define trunk center position
  int centerX = TOTAL_WIDTH / 2;
  int leftTrunkX = centerX - 1;
  int rightTrunkX = centerX;

  // Iterate through each pixel and set the trunk pixels
  reinforcedImage.loadPixels();
  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    // Copy the trunk pixels from startImage
    color trunkColorLeft = startImage.get(leftTrunkX, y);
    color trunkColorRight = startImage.get(rightTrunkX, y);

    reinforcedImage.set(leftTrunkX, y, trunkColorLeft);
    reinforcedImage.set(rightTrunkX, y, trunkColorRight);
  }
  reinforcedImage.updatePixels();

  // Update the startImage to the reinforced version
  startImage = reinforcedImage;
}

void reinforceTrunk(PGraphics pg) {
  // Define the trunk center columns
  int centerX = TOTAL_WIDTH / 2;
  int leftTrunkX = centerX - 1;
  int rightTrunkX = centerX;

  pg.loadPixels();
  startImage.loadPixels(); // Ensure startImage is up-to-date

  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    // Copy the trunk pixels from startImage to the PGraphics buffer
    color trunkColorLeft = startImage.get(leftTrunkX, y);
    color trunkColorRight = startImage.get(rightTrunkX, y);

    pg.pixels[y * TOTAL_WIDTH + leftTrunkX] = trunkColorLeft;
    pg.pixels[y * TOTAL_WIDTH + rightTrunkX] = trunkColorRight;
  }
  pg.updatePixels();
}


// draw branch

void drawBranch(PGraphics pg, float baseX, float baseY, float length, float angleDeg, color branchColor) {
  float rad = radians(angleDeg);
  float endX = baseX + length * cos(rad);
  float endY = baseY - length * sin(rad);

  pg.stroke(branchColor);
  pg.strokeWeight(1);
  pg.line(baseX, baseY, endX, endY);
}


// draw leaf

void drawLeaf(PGraphics pg, float x, float y, color c, float size) {
  pg.noStroke();
  pg.fill(c);
  pg.ellipse(x, y, size, size);
}

// draw flower 
void drawFlower(PGraphics pg, float x, float y, color c, float size) {
  pg.pushMatrix();
  pg.translate(x, y);
  pg.noStroke();
  pg.fill(c);

  pg.beginShape();
  int petals = 5;
  for (int i = 0; i < petals; i++) {
    float theta = TWO_PI * i / petals;
    float rx = cos(theta) * size;
    float ry = sin(theta) * size;
    pg.vertex(rx, ry);
  }
  pg.endShape(CLOSE);

  pg.popMatrix();
}


// Checks if (x,y) is at least minDist away from all points in a PVector array
boolean isFarEnough(float x, float y, PVector[] points, int count, float minDist) {
  for (int i = 0; i < count; i++) {
    PVector p = points[i];
    if (dist(x, y, p.x, p.y) < minDist) {
      return false;
    }
  }
  return true;
}

// "Chaos": Randomly assign new positions to all particles
void startChaos() {
  for (Particle p : particles) {
    p.startChaos();
  }
}


// Particle class for each pixel

class Particle {
  float x, y; // Current position
  int targetX, targetY;  
  color targetColor;   
  float chaosX, chaosY;  
  boolean inChaos;

  Particle(int startX, int startY, int targetX, int targetY, color targetColor) {
    reset(startX, startY, targetX, targetY, targetColor);
  }

  void reset(int startX, int startY, int targetX, int targetY, color targetColor) {
    x = startX;
    y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
    this.targetColor = targetColor;
    inChaos = false;
  }

  void update(boolean chaosPhase) {
    if (chaosPhase && !inChaos) {
      // Move toward chaos position
      x += (chaosX - x) * 0.05;
      y += (chaosY - y) * 0.05;
      // Snap to chaos if close enough
      if (dist(x, y, chaosX, chaosY) < 0.5) {
        x = chaosX;
        y = chaosY;
        inChaos = true;
      }
    } else if (!chaosPhase) {
      // Move toward target position
      x += (targetX - x) * 0.05;
      y += (targetY - y) * 0.05;
    }
  }

  void startChaos() {
    chaosX = random(width);
    chaosY = random(height);
    inChaos = false;
  }

  void display() {
    fill(targetColor);
    noStroke();
    rect(x, y, 1, 1);
  }
}



void sendToSerial() {
  if (serial != null) {
    loadPixels();
    int idx = 0;
    for (int y = 0; y < TOTAL_HEIGHT; y++) {
      for (int x = 0; x < TOTAL_WIDTH; x++) {
        color c = get(x, y);
        int rgb16 = packRGB16((int) red(c), (int) green(c), (int) blue(c));
        buffer[idx++] = (byte) ((rgb16 >> 8) & 0xFF);
        buffer[idx++] = (byte) (rgb16 & 0xFF);
      }
    }
    serial.write('*');    // Start frame marker
    serial.write(buffer); // Send pixel data
  }
}


int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}


color getRandomAllowedColor() {
  int idx = int(random(ALLOWED_COLORS.length));
  return ALLOWED_COLORS[idx];
}
