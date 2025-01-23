import processing.serial.*;

final int TOTAL_WIDTH  = 32;
final int TOTAL_HEIGHT = 32;
final int COLOR_DEPTH  = 16; // 24 or 16 bits
final int BAUD_RATE    = 921600;

Serial serial;
byte[] buffer;

Particle[] particles; // array of particles
int particleCount = 600; // nr. of particles
boolean explosionComplete = false; 
float animationSpeed = 0.08; // explosion speed

//float animationSpeed = 1; // explosion speed

color[] palette = {
  color(34, 139, 34),  // Green
  color(60, 179, 113), // Light Green
  color(220, 20, 60),  // Red
  color(255, 165, 0),  // Orange
  color(219, 112, 147),// Pink
  color(30, 144, 255), // Blue
  color(218, 165, 32), // Golden
  color(255, 228, 181) // Light Peach
};

void setup() {
  size(32, 32);
  smooth(8);

  // Initialize particles for the flower-like pattern
  particles = new Particle[particleCount];
  for (int i = 0; i < particles.length; i++) {
    float angle = random(TWO_PI);
    float radius = random(5, 12); // control the spread of the particles
    float targetX = width / 2 + cos(angle) * radius;
    float targetY = height / 2 + sin(angle) * radius;
    color c = palette[int(random(palette.length))];
    particles[i] = new Particle(random(width), random(height), targetX, targetY, c);
  }

  // Prepare the buffer for serial data
  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * (COLOR_DEPTH / 8)];

  // Initialize the serial connection
  String[] list = Serial.list();
  printArray(list);

  try {
    final String PORT_NAME = "/dev/tty.usbserial-02B62278";
    serial = new Serial(this, PORT_NAME, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0); 

  explosionComplete = true; // Assume explosion is complete unless proven otherwise

  // Update and display all particles
  for (Particle p : particles) {
    if (!p.moveToTarget(animationSpeed)) {
      explosionComplete = false; // Not complete if any particle is still moving
    }
    p.display();
  }

  // If the explosion is complete, restart
  if (explosionComplete) {
    resetParticles();
  }

  // Send the pixel data to the LED matrix
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

// Reset the particles for a new snowflake explosion
void resetParticles() {
  for (int i = 0; i < particles.length; i++) {
    // Choose one of the six axes for the snowflake pattern
    int axis = int(random(6)); 
    float angle = axis * PI / 3; // 6 axes, each 60 degrees apart
    float radius = random(5, 12); // Distance from the center
    float targetX = width / 2 + cos(angle) * radius;
    float targetY = height / 2 + sin(angle) * radius;

    // Add some randomness to make it less uniform
    targetX += random(-2, 2);
    targetY += random(-2, 2);

    particles[i].reset(random(width), random(height), targetX, targetY);
  }
}

// Particle class for the flower-like pattern
class Particle {
  float x, y; // Current position
  float targetX, targetY; // Target position
  color c; // Color of the particle

  Particle(float startX, float startY, float targetX, float targetY, color c) {
    this.x = startX;
    this.y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
    this.c = c;
  }

  // Move the particle toward the target
  boolean moveToTarget(float speed) {
    x = lerp(x, targetX, speed);
    y = lerp(y, targetY, speed);
    return dist(x, y, targetX, targetY) < 0.5; // Return true if close to target
  }

  // Reset particle to a new random position
  void reset(float startX, float startY, float targetX, float targetY) {
    this.x = startX;
    this.y = startY;
    this.targetX = targetX;
    this.targetY = targetY;
  }

  // Display the particle
  void display() {
    fill(c);
    noStroke();
    ellipse(x, y, 2, 2); // Particles are small circles
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
