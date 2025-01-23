import processing.serial.*;

// Matrix dimensions and communication settings
final int TOTAL_WIDTH = 32;
final int TOTAL_HEIGHT = 32;
final int COLOR_DEPTH = 16; // 16-bit RGB565 format
final int BAUD_RATE = 921600;

Serial serial;
byte[] buffer;

// Colors
color[] palette = {
  color(56, 150, 35),  // #389623
  color(0, 133, 89),   // #008559
  color(207, 41, 69),  // #CF2945
  color(222, 106, 65), // #DE6A41
  color(211, 144, 1),  // #D39001
  color(70, 164, 202), // #46A4CA
  color(203, 92, 138)  // #CB5C8A
};

// Particles for explosion
Particle[] particles;
int particleCount = 300; // Number of particles

// Animation control
boolean isReversing = false; // Whether the explosion is reversing
float animationSpeed = 0.03; // Speed of animation

void setup() {
  size(32, 32);
  particles = createParticles(); // Initialize particles

  // Prepare the buffer for sending data
  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * (COLOR_DEPTH / 8)];

  // Initialize the serial connection
  String[] list = Serial.list();
  printArray(list);

  try {
    final String PORT_NAME = "/dev/cu.usbserial-02B5FCCE"; // Replace with your port
    serial = new Serial(this, PORT_NAME, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0); // Black background

  boolean allComplete = true;

  // Update particles
  for (Particle p : particles) {
    if (isReversing) {
      if (!p.reverseMove(animationSpeed)) allComplete = false;
    } else {
      if (!p.moveToTarget(animationSpeed)) allComplete = false;
    }
    p.display();
  }

  // Switch direction when the explosion or reverse is complete
  if (allComplete) {
    isReversing = !isReversing;
    if (!isReversing) resetParticles(); // Reset for the next explosion
  }

  // Send the current frame to the LED matrix
  sendToMatrix();
}

// Create particles for the explosion
Particle[] createParticles() {
  Particle[] particles = new Particle[particleCount];
  for (int i = 0; i < particles.length; i++) {
    float angle = random(TWO_PI);
    float radius = random(5, 16); // Explosion radius
    float targetX = width / 2 + cos(angle) * radius;
    float targetY = height / 2 + sin(angle) * radius;
    color c = adjustBrightness(palette[int(random(palette.length))], random(0.5, 1));
    particles[i] = new Particle(width / 2, height / 2, targetX, targetY, c);
  }
  return particles;
}

// Reset particles to the center
void resetParticles() {
  for (Particle p : particles) {
    p.reset(width / 2, height / 2);
  }
}

// Adjust brightness of a color
color adjustBrightness(color c, float factor) {
  return color(red(c) * factor, green(c) * factor, blue(c) * factor);
}

// Particle class
class Particle {
  float x, y; // Current position
  float targetX, targetY; // Target position
  float startX, startY; // Start position (center)
  color c; // Particle color

  Particle(float startX, float startY, float targetX, float targetY, color c) {
    this.startX = startX;
    this.startY = startY;
    this.x = startX;
    this.y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
    this.c = c;
  }

  boolean moveToTarget(float speed) {
    x = lerp(x, targetX, speed);
    y = lerp(y, targetY, speed);
    return dist(x, y, targetX, targetY) < 0.5;
  }

  boolean reverseMove(float speed) {
    x = lerp(x, startX, speed);
    y = lerp(y, startY, speed);
    return dist(x, y, startX, startY) < 0.5;
  }

  void reset(float startX, float startY) {
    this.x = startX;
    this.y = startY;
  }

  void display() {
    fill(c);
    noStroke();
    rect(x, y, 1, 1); // Render as a single pixel
  }
}

// Send current frame to the LED matrix
void sendToMatrix() {
  if (serial != null) {
    int idx = 0;
    loadPixels();
    for (int i = 0; i < pixels.length; i++) {
      color c = pixels[i];
      if (COLOR_DEPTH == 16) {
        int rgb16 = packRGB16(
          (byte) (c >> 16 & 0xFF), 
          (byte) (c >> 8 & 0xFF), 
          (byte) (c & 0xFF)
        );
        byte[] bytes = splitBytes(rgb16);
        buffer[idx++] = bytes[0];
        buffer[idx++] = bytes[1];
      }
    }
    serial.write('*'); // Start command
    serial.write(buffer); // Send the buffer
  }
}

// Convert 8-bit RGB values to 16-bit RGB565 format
int packRGB16(byte r, byte g, byte b) {
  byte r5 = (byte) ((r >> 3) & 0x1F);  // 5 bits for red
  byte g6 = (byte) ((g >> 2) & 0x3F);  // 6 bits for green
  byte b5 = (byte) ((b >> 3) & 0x1F);  // 5 bits for blue
  return (r5 << 11) | (g6 << 5) | b5;
}

// Split a 16-bit integer into two bytes
byte[] splitBytes(int int16) {
  byte highByte = (byte) ((int16 >> 8) & 0xFF);  // Get upper 8 bits
  byte lowByte  = (byte) (int16 & 0xFF);        // Get lower 8 bits
  return new byte[]{highByte, lowByte};
}
