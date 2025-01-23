import processing.serial.*;

final int TOTAL_WIDTH  = 32;
final int TOTAL_HEIGHT = 32;
final int COLOR_DEPTH  = 16; // 24 or 16 bits
final int BAUD_RATE    = 921600;

Serial serial;
byte[] buffer;

Pattern[] patterns; // Array for patterns
int patternCountX = 4; // Number of patterns along X-axis
int patternCountY = 4; // Number of patterns along Y-axis
float animationSpeed = 0.01; // Control explosion speed

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

  // Calculate pattern size
  int patternWidth = TOTAL_WIDTH / patternCountX;
  int patternHeight = TOTAL_HEIGHT / patternCountY;

  // Initialize patterns
  patterns = new Pattern[patternCountX * patternCountY];
  int idx = 0;
  for (int x = 0; x < patternCountX; x++) {
    for (int y = 0; y < patternCountY; y++) {
      patterns[idx++] = new Pattern(
        x * patternWidth, // Start X
        y * patternHeight, // Start Y
        patternWidth,      // Pattern width
        patternHeight      // Pattern height
      );
    }
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

  boolean allComplete = true; // Check if all patterns are complete

  // Update and display all patterns
  for (Pattern p : patterns) {
    if (!p.update(animationSpeed)) {
      allComplete = false;
    }
    p.display();
  }

  // Reset patterns for continuous animation
  if (allComplete) {
    resetPatterns();
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

// Reset all patterns for continuous animation
void resetPatterns() {
  for (Pattern p : patterns) {
    p.reset();
  }
}

// Pattern class for each smaller pattern
class Pattern {
  int startX, startY; // Starting position of the pattern
  int width, height;  // Dimensions of the pattern
  Particle[] particles; // Array of particles for the pattern
  int particleCount = 20; // Number of particles per pattern

  Pattern(int startX, int startY, int width, int height) {
    this.startX = startX;
    this.startY = startY;
    this.width = width;
    this.height = height;

    // Initialize particles for the pattern
    particles = new Particle[particleCount];
    for (int i = 0; i < particles.length; i++) {
      float angle = i * TWO_PI / particleCount;
      float radius = min(width, height) / 3.0; // Scale radius to fit pattern size
      float targetX = startX + width / 2 + cos(angle) * radius;
      float targetY = startY + height / 2 + sin(angle) * radius;
      color c = palette[i % palette.length]; // Cycle through the palette
      particles[i] = new Particle(
        random(startX, startX + width), random(startY, startY + height), 
        targetX, targetY, c
      );
    }
  }

  boolean update(float speed) {
    boolean complete = true;
    for (Particle p : particles) {
      if (!p.moveToTarget(speed)) {
        complete = false;
      }
    }
    return complete;
  }

  void display() {
    for (Particle p : particles) {
      p.display();
    }
  }

  void reset() {
    for (Particle p : particles) {
      float angle = random(TWO_PI);
      float radius = min(width, height) / 3.0;
      float targetX = startX + width / 2 + cos(angle) * radius;
      float targetY = startY + height / 2 + sin(angle) * radius;
      p.reset(random(startX, startX + width), random(startY, startY + height), targetX, targetY);
    }
  }
}

// Particle class for individual particles
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
