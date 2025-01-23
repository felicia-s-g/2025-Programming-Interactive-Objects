import processing.serial.*;

final int TOTAL_WIDTH = 32;
final int TOTAL_HEIGHT = 32;
final int BAUD_RATE = 921600;

final int IMAGE_DISPLAY_TIME = 2000; // Time (in ms) to display a fully formed image
final int TRANSITION_TIME = 3000;   // Time (in ms) for the chaotic transition to the next image

Serial serial;
byte[] buffer;

PImage[] images;     // Array to hold the sequence of images
Particle[] particles; // Particles representing individual pixels
int currentImageIndex = 0;
int lastImageChangeTime = 0;

boolean inTransition = false; // Indicates if we're transitioning between images
float transitionProgress = 0; // Progress of the transition (0.0 to 1.0)

void setup() {
  size(32, 32);
  frameRate(60);

  // Load images
  images = new PImage[7];
  images[0] = loadImage("image1.png");
  images[1] = loadImage("image2.png");
  images[2] = loadImage("image3.png");
  images[3] = loadImage("image4.png");
  images[4] = loadImage("image5.png");
  images[5] = loadImage("image6.png");
  images[6] = loadImage("image7.png");
  for (PImage img : images) img.resize(TOTAL_WIDTH, TOTAL_HEIGHT);

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2];
  particles = new Particle[TOTAL_WIDTH * TOTAL_HEIGHT];

  initializeParticles();

  // Initialize serial communication
  try {
    String portName = "/dev/tty.usbserial-02B62278"; // Adjust port name as needed
    serial = new Serial(this, portName, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void initializeParticles() {
  int index = 0;
  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      int startX = (int) random(width);  // Start position is random
      int startY = (int) random(height);
      color startColor = color(0);       // Initial color is black

      int targetX = x;
      int targetY = y;
      color targetColor = images[currentImageIndex].get(x, y);

      particles[index++] = new Particle(startX, startY, targetX, targetY, startColor, targetColor);
    }
  }
}

void draw() {
  background(0);

  int elapsedTime = millis() - lastImageChangeTime;

  if (!inTransition && elapsedTime >= IMAGE_DISPLAY_TIME) {
    // Start transition to the next image
    inTransition = true;
    transitionProgress = 0;
  }

  if (inTransition) {
    transitionProgress += 1.0 / (TRANSITION_TIME * frameRate / 1000.0);

    if (transitionProgress >= 1.0) {
      // Complete the transition
      inTransition = false;
      currentImageIndex = (currentImageIndex + 1) % images.length;
      lastImageChangeTime = millis();

      // Update particle targets to the next image
      for (int i = 0; i < particles.length; i++) {
        particles[i].reset(images[currentImageIndex].get(i % TOTAL_WIDTH, i / TOTAL_WIDTH));
      }
    }
  }

  // Update and display particles
  for (Particle p : particles) {
    p.update();
    p.display();
  }

  // Send the current state to the serial port
  sendToSerial();
}

class Particle {
  float x, y;        // Current position
  float tx, ty;      // Target position
  color c;           // Current color
  color targetColor; // Target color

  Particle(float startX, float startY, float targetX, float targetY, color startColor, color targetColor) {
    x = startX;
    y = startY;
    tx = targetX;
    ty = targetY;
    c = startColor;
    this.targetColor = targetColor;
  }

  void update() {
    if (inTransition) {
      // Add random chaos to the movement
      x += random(-2, 2);
      y += random(-2, 2);

      // Gradually move towards the new target position
      x = lerp(x, tx, 0.05);
      y = lerp(y, ty, 0.05);

      // Gradually fade into the new target color
      c = lerpColor(c, targetColor, 0.05);
    } else {
      // During the steady display phase, lock onto the grid position
      x = lerp(x, tx, 0.2);
      y = lerp(y, ty, 0.2);
      c = lerpColor(c, targetColor, 0.2);
    }
  }

  void display() {
    fill(c);
    noStroke();
    rect(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT),
         width / TOTAL_WIDTH, height / TOTAL_HEIGHT);
  }

  void reset(color newTargetColor) {
    tx = (int) random(width); // Start transition with a random position
    ty = (int) random(height);
    targetColor = newTargetColor;
  }
}

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
    serial.write('*');
    serial.write(buffer);
  }
}

int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}
