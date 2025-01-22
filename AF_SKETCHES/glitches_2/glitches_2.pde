import processing.serial.*;

Serial serial;
int TOTAL_WIDTH = 32; // Canvas width in pixels
int TOTAL_HEIGHT = 32; // Canvas height in pixels
byte[] buffer;

void setup() {
  size(32 * 16, 32 * 16); // Maintain 32x32 size, scaled up for visibility
  frameRate(10); // Balanced framerate for subtle dynamics
  noSmooth();
  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 3]; // RGB color depth

  // Initialize serial port
  String[] ports = Serial.list();
  printArray(ports);
  try {
    String portName = "/dev/tty.usbserial-02B62278"; // Replace with your port
    serial = new Serial(this, portName, 921600);
    println("Serial port initialized: " + portName);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(0); // Black background

  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      color pixelColor = getPatternColor(x, y);
      float intensity = getPatternIntensity(x, y); // Intensity determines brightness

      // Some pixels are completely black
      if (random(1) < 0.1) { 
        pixelColor = color(0);
      } else {
        // Adjust brightness by blending towards black
        pixelColor = lerpColor(color(0), pixelColor, intensity);
      }

      // Draw pixel as a rectangle for scaling
      fill(pixelColor);
      noStroke();
      rect(x * (width / TOTAL_WIDTH), y * (height / TOTAL_HEIGHT), 
           width / TOTAL_WIDTH, height / TOTAL_HEIGHT);

      // Prepare buffer for the serial output
      int idx = (y * TOTAL_WIDTH + x) * 3;
      buffer[idx] = (byte) red(pixelColor);
      buffer[idx + 1] = (byte) green(pixelColor);
      buffer[idx + 2] = (byte) blue(pixelColor);
    }
  }

  sendCanvasToSerial();
}

float getPatternIntensity(int x, int y) {
  float ripple = sin((x + frameCount * 0.3) * 0.2) * cos((y + frameCount * 0.3) * 0.2) * 0.5 + 0.5;
  return constrain(ripple, 0, 1); // Smooth and organic shapes
}

color getPatternColor(int x, int y) {
  float noiseVal = noise((x + 50) * 0.1, (y + 50) * 0.1, frameCount * 0.02);
  if (noiseVal < 0.33) {
    return color(207, 41, 69); // #CF2945
  } else if (noiseVal < 0.66) {
    return color(218, 139, 21); // #DA8B15
  } else {
    return color(56, 150, 35); // #389623
  }
}

void sendCanvasToSerial() {
  if (serial != null) {
    serial.write('*'); // Indicate the start of a frame
    serial.write(buffer); // Send the pixel buffer
  }
}
