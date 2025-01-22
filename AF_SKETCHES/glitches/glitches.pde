import processing.serial.*;

Serial serial;
int TOTAL_WIDTH = 32; // Canvas width in characters
int TOTAL_HEIGHT = 32; // Canvas height in characters
char[] asciiPalette = { '.', ':', '*', '+', '#', '@' }; // ASCII shades
color[] colors = { #CF2945, #000000, #DA8B15, #389623 }; // Colors used in the original code with added white for higher intensity

float glitchIntensity = 0.6; // Adjust glitch intensity (0 to 1)
byte[] buffer;

void setup() {
  size(32 * 16, 32); // Maintain 32x32 size, scaled up for visibility
  frameRate(15); // Slow framerate for glitch effect
  noSmooth();
  textAlign(CENTER, CENTER);
  textSize(width / TOTAL_WIDTH); // Adjust text size to fit the grid
  fill(255);

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2]; // 16-bit color depth

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
  background(#000000); // Black background

  for (int y = 0; y < TOTAL_HEIGHT; y++) {
    for (int x = 0; x < TOTAL_WIDTH; x++) {
      char symbol = getGlitchySymbol(x, y);
      float intensity = getGlitchyIntensity(x, y); // Light intensity determines size

      color c = getGlitchyColor(x, y);
      fill(c);

      float size = map(intensity, 0, 1, 2, width / TOTAL_WIDTH); // Map intensity to size

      text(symbol, x * (width / TOTAL_WIDTH) + (width / TOTAL_WIDTH) / 2, 
           y * (height / TOTAL_HEIGHT) + (height / TOTAL_HEIGHT) / 2);

      // Prepare buffer for the serial output
      int pixelColor = packRGB16(c);
      int idx = (y * TOTAL_WIDTH + x) * 2;
      buffer[idx] = (byte) ((pixelColor >> 8) & 0xFF);
      buffer[idx + 1] = (byte) (pixelColor & 0xFF);
    }
  }

  sendCanvasToSerial();
}

char getGlitchySymbol(int x, int y) {
  float noiseVal = noise(x * glitchIntensity, y * glitchIntensity, frameCount * 0.05);
  int index = int(noiseVal * asciiPalette.length);
  return asciiPalette[constrain(index, 0, asciiPalette.length - 1)];
}

float getGlitchyIntensity(int x, int y) {
  return noise(x * glitchIntensity * 2, y * glitchIntensity * 2, frameCount * 0.1); // Intensity based on noise
}

color getGlitchyColor(int x, int y) {
  float noiseVal = noise((x + 100) * glitchIntensity, (y + 100) * glitchIntensity, frameCount * 0.05);
  color baseColor = colors[int(noiseVal * colors.length) % colors.length];
  return baseColor;
}

void sendCanvasToSerial() {
  if (serial != null) {
    serial.write('*'); // Indicate the start of a frame
    serial.write(buffer); // Send the pixel buffer
  }
}

int packRGB16(color c) {
  int r = (int) red(c) >> 3;
  int g = (int) green(c) >> 2;
  int b = (int) blue(c) >> 3;
  return (r << 11) | (g << 5) | b;
}
