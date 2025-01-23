import processing.serial.*;


// constants
// >>>>>>>>>>>>>>>>>>>
final int TOTAL_WIDTH         = 32;
final int TOTAL_HEIGHT        = 32;
final int BAUD_RATE           = 921600;
final int IMAGE_DISPLAY_TIME  = 4000;  // display duration for each image // before chaos
final int CHAOS_DURATION      = 2000;  // explosion duration

// distance between flowers
final float MIN_FLOWER_DIST   = 1.0;


// colors
// >>>>>>>>>>>>>>>>>>>
final color[] COLOUR_PALETTE = {
  color(207, 41, 69), // red
  color(218, 122, 162), // pink
  color(211, 144, 1), // yellow
  color(70, 164, 202), // blue
  color(0, 122, 82), // emerald
  color(56, 150, 35)     // green
};

Serial serial;
byte[] buffer;

Particle[] particles;
int lastImageChangeTime = 0; // tracks the last time the tree changed
boolean chaosPhase = false;  // verifies if the explosion is happening

PImage startImage;     // loads base image

// setup
// >>>>>>>>>>>>>>>>>>>

void setup() {
  size(32, 32);
  frameRate(80);

  startImage = loadImage("image1.png");
  if (startImage == null) {
    exit(); // exit if there's no img
  }
  startImage.resize(TOTAL_WIDTH, TOTAL_HEIGHT);

  // DO NOT DELETE
  reinforceTrunk();

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2];
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT];

  // generate start image tree
  initializeParticles();

  // CHANGE SERIAL PORT HERE
  // >>>>>>>>>>>>>>>>>>>>>>>>

  try {
    String portName = "/dev/cu.usbserial-02B62278";
    serial = new Serial(this, portName, BAUD_RATE);
  }
  catch (Exception e) {
    println("Serial port not initialized...");
  }
}

// draw
// >>>>>>>>>>>>>>>>>>>

void draw() {
  background(0);

  // check is it time for explosion
  if (!chaosPhase && millis() - lastImageChangeTime > IMAGE_DISPLAY_TIME) {
    chaosPhase = true;
    startChaos(); // particles are scattered
  }

  // reassemble particles after chaos
  if (chaosPhase && millis() - lastImageChangeTime > IMAGE_DISPLAY_TIME + CHAOS_DURATION) {
    initializeParticles();
    lastImageChangeTime = millis();
    chaosPhase = false; // exit chaos
  }

  for (Particle p : particles) {
    p.update(chaosPhase);
    p.display();
  }

  sendToSerial();
}

// init particles
// >>>>>>>>>>>>>>>>>>>

void initializeParticles() {
  PImage sourceImage = generateSymmetricalTree();

  // Assign or reset each particle's position & target color
  int index = 0;
  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {

      // get starting pos
      int startX = particles[index] != null ? (int) particles[index].x : (int) random(width);
      int startY = particles[index] != null ? (int) particles[index].y : (int) random(height);

      // get target colour
      color targetColor = sourceImage.get(x, y);

      // if particle exists then reset, else create new
      if (particles[index] != null) {
        // reset particle to new target
        particles[index].reset(startX, startY, x, y, targetColor);
      } else {
        // create new particle at start pos
        particles[index] = new Particle(startX, startY, x, y, targetColor);
      }
      index++; // loop through all particles
    }
  }
}

// actual tree generation
// >>>>>>>>>>>>>>>>>>>

PImage generateSymmetricalTree() {

  // create object
  PGraphics pg = createGraphics(TOTAL_WIDTH, TOTAL_HEIGHT);
  pg.beginDraw();
  pg.background(0);

  pg.image(startImage, 0, 0);

  // place trunk in the middle
  int trunkCenterX = TOTAL_WIDTH / 2;

  // branches (right + mirror left)
  // >>>>>>>>>>>>>>>>>>>>>>
  int numBranches = int(random(3, 8));
  for (int i = 0; i < numBranches; i++) {

    int branchBaseY = int(random(10, TOTAL_HEIGHT - 5)); // random position on the trunk
    // !!!!!!!!!!!!!!!!!!!
    // do not change values, these were decided after many many (many) trials and errors
    float length = random(3, 12); // random lenght
    float angleDeg = random(20, 70); //random angle
    color branchColor = getRandomAllowedColor(); //random colour

    // draw right branch
    drawBranch(pg, trunkCenterX, branchBaseY, length, angleDeg, branchColor);

    // mirror left branch
    drawBranch(pg, trunkCenterX, branchBaseY, length, -angleDeg, branchColor);
  }

  // leaves
  // >>>>>>>>>>>>>>>>>>>>>>
  if (random(1) < 0.8) {
    int numLeaves = int(random(5, 15)); // change these values at your own risk
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

  // flowers
  // >>>>>>>>>>>>>>>>>>>>>>
  if (random(1) < 0.6) {
    int numFlowers = int(random(2, 6));

    // init a fixed-size array to store placed flower positions on the right side
    PVector[] placedFlowersRight = new PVector[numFlowers];
    int placedCount = 0;  // nr. of flowers successfully placed

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

  // reinforce the first image again to ensure it's not too altered by new elements
  reinforceTrunk(pg);

  pg.endDraw();
  return pg.get(); //return new image
}

// trunk
// >>>>>>>>>>>>>>>>>>>

void reinforceTrunk() {
  
  // verify the trunk to ensure it's exactly 2 pixels wide and matches the start image
  // this kept breaking randomly so make sure to keep this function in
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

void reinforceTrunk(PGraphics pg) { // temp canvas
  // Define the trunk center columns
  // draw new tree versions
  int centerX = TOTAL_WIDTH / 2;
  int leftTrunkX = centerX - 1;
  int rightTrunkX = centerX;

  pg.loadPixels();
  startImage.loadPixels(); // startImage is up to date

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
// >>>>>>>>>>>>>>>>>>>

void drawBranch(PGraphics pg, float baseX, float baseY, float length, float angleDeg, color branchColor) {
  float rad = radians(angleDeg);
  float endX = baseX + length * cos(rad);  // calc end position
  float endY = baseY - length * sin(rad);

  pg.stroke(branchColor);
  pg.strokeWeight(1);
  pg.line(baseX, baseY, endX, endY);
}

// draw leaf
// >>>>>>>>>>>>>>>>>>>

void drawLeaf(PGraphics pg, float x, float y, color c, float size) {
  pg.noStroke();
  pg.fill(c);
  pg.ellipse(x, y, size, size);
}

// draw flower
// >>>>>>>>>>>>>>>>>>>

void drawFlower(PGraphics pg, float x, float y, color c, float size) {
  pg.pushMatrix();    // saves current state
  pg.translate(x, y); // moves origin to flower centre
  pg.noStroke();
  pg.fill(c);

  pg.beginShape();
  int petals = 5;
  for (int i = 0; i < petals; i++) {
    float theta = TWO_PI * i / petals; // calc angle for each petal
    float rx = cos(theta) * size;      // flower x coordinate
    float ry = sin(theta) * size;      // flower y coordinate
    pg.vertex(rx, ry);                 // add them to shape
  }
  pg.endShape(CLOSE);

  pg.popMatrix(); // restores previous transformation state
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

// "Chaos": randomly assign new positions to all particles
// >>>>>>>>>>>>>>>>>>>
void startChaos() {
  for (Particle p : particles) {
    p.startChaos();
  }
}

// Particle class for each 1 pixel = 1 particle
// >>>>>>>>>>>>>>>>>>>
class Particle {
  float x, y; // Current position
  int targetX, targetY;
  color targetColor;
  float chaosX, chaosY; // Chaos position
  boolean inChaos;

  Particle(int startX, int startY, int targetX, int targetY, color targetColor) {
    reset(startX, startY, targetX, targetY, targetColor);
  }

  // resets all particle variables
  void reset(int startX, int startY, int targetX, int targetY, color targetColor) {
    x = startX;
    y = startY;
    this.targetX = targetX; // destination for reassembly
    this.targetY = targetY;
    this.targetColor = targetColor;
    inChaos = false;
  }

  // chaos
  // >>>>>>>>>>>>>>>>>>>

  void update(boolean chaosPhase) {
    if (chaosPhase && !inChaos) {
      // when particle is in chaos mode but hasn't reached chaos position
      // move slightly toward chaos coordinates
      x += (chaosX - x) * 0.05;
      y += (chaosY - y) * 0.05;
      // go to chaos if close enough
      if (dist(x, y, chaosX, chaosY) < 0.5) {
        x = chaosX;
        y = chaosY;
        inChaos = true;
      }
    } else if (!chaosPhase) {
      // if not in chaos mode i.e. during reassembly, move toward target position
      x += (targetX - x) * 0.05;
      y += (targetY - y) * 0.05;
    }
  }

  void startChaos() {
    // assign random position for particle during explosion
    chaosX = random(width);
    chaosY = random(height);
    inChaos = false;
  }

  void display() {
    fill(targetColor);
    noStroke();
    rect(round(x), round(y), 1, 1);
  }
}

// serial comm
// >>>>>>>>>>>>>>>>>>>

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

// colours
// >>>>>>>>>>>>>>>>>>>

int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}

color getRandomAllowedColor() {
  int idx = int(random(COLOUR_PALETTE.length));
  return COLOUR_PALETTE[idx];
}
