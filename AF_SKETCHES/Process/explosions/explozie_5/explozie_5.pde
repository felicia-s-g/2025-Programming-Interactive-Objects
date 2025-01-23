import processing.serial.*;

final int TOTAL_WIDTH  = 32;
final int TOTAL_HEIGHT = 32;
final int COLOR_DEPTH  = 16; // 24 or 16 bits
final int BAUD_RATE    = 921600;

Serial serial;
byte[] buffer;

Particle[] particles; // Array for particles
int particleCount = 1000; // Dense particles
float animationSpeed = 0.02; // Speed for smoother animation

// Custom color palette
color[] palette = {
  color(56, 150, 35),  // #389623
  color(0, 133, 89),   // #008559
  color(207, 41, 69),  // #CF2945
  color(222, 106, 65), // #DE6A41
  color(211, 144, 1),  // #D39001
  color(70, 164, 202), // #46A4CA
  color(203, 92, 138)  // #CB5C8A
};

void setup() {
  size(32, 32);
  smooth(8);

  // Initialize particles for symmetrical geometrical patterns
  particles = new Particle[particleCount];
  for (int i = 0; i < particles.length; i++) {
    float radius = random(1, 12); // Control the spread of particles
    float angle = i % 12 * TWO_PI / 12; // Distribute particles symmetrically
    float targetX = width / 2 + cos(angle) * radius;
    float targetY = height / 2 + sin(angle) * radius;

    // Apply symmetry and layering for complex patterns
    if (i % 3 == 0) {
      targetX += random(-3, 3);
    } else if (i % 3 == 1) {
      targetY += random(-3, 3);
    }

    color c = palette[i % palette.length]; // Cycle through the palette
    particles[i] = new Particle(random(width), random(height), targetX, targetY, c);
  }

  // Prepare the buffer for serial data
  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * (COLOR_DEPTH / 8)];

  // Initialize the serial connection
  String[] list = Serial.list();
  printArray(list);

  try {
    final String PORT_NAME = "/dev/cu.usbserial-02B5FCCE";
    serial = new Serial(this, PORT_NAME, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0); // Black background

  boolean allComplete = true; // Track if all particles reached their targets

  // Update and display all particles
  for (Particle p : particles) {
    if (!p.moveToTarget(animationSpeed)) {
      allComplete = false;
    }
    p.display();
  }

  // Reset particles when the pattern completes
  if (allComplete) {
    resetParticles();
  }

  // Send pixel data to the LED matrix
  if (serial != null) {
    int idx = 0;
    loadPixels();
    for (int i = 0; i < pixels.length; i++) {
      color c = pixels[i];
      if (COLOR_DEPTH == 24) {
        buffer[idx++] = (byte) (c >> 16 & 0xFF); // r
        buffer[idx++] = (byte) (c >> 8 & 0xFF);  // g
        buffer[idx++] = (byte) (c & 0xFF);       // b
      } else if (COLOR_DEPTH == 16) {
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

// Reset particles for continuous symmetrical patterns
void resetParticles() {
  for (int i = 0; i < particles.length; i++) {
    float radius = random(1, 12);
    float angle = i % 12 * TWO_PI / 12;
    float targetX = width / 2 + cos(angle) * radius;
    float targetY = height / 2 + sin(angle) * radius;

    if (i % 3 == 0) {
      targetX += random(-3, 3);
    } else if (i % 3 == 1) {
      targetY += random(-3, 3);
    }

    particles[i].reset(random(width), random(height), targetX, targetY);
  }
}

// Particle class for geometrical patterns
class Particle {
  float x, y; // Current position
  float targetX, targetY; // Target position
  color c; // Color of the particle

  Particle(float startX, float startY, float targetX, float targetY, color c) {
    this.x = startX;
    this.y = startY;
    this.targetX = targetX * (width / TOTAL_WIDTH);
    this.targetY = targetY * (height / TOTAL_HEIGHT);
    this.c = c;
  }

  boolean moveToTarget(float speed) {
    x = lerp(x, targetX, speed);
    y = lerp(y, targetY, speed);
    return dist(x, y, targetX, targetY) < 0.5; // Return true if close to target
  }

  void reset(float startX, float startY, float targetX, float targetY) {
    this.x = startX;
    this.y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
  }

  void display() {
    fill(c);
    noStroke();
    rect(x, y, 1, 1); // Render as a single pixel
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
