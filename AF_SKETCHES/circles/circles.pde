import java.util.Random;
import processing.serial.*;

Serial serial;

final int TOTAL_WIDTH  = 32;       // Canvas width
final int TOTAL_HEIGHT = 32;       // Canvas height
final int COLOR_DEPTH  = 16;       // Color depth: 16 bits (5-6-5 format)
final int BAUD_RATE    = 921600;   // Serial baud rate

byte[] buffer;

int triangleSize = 5;  // Adjusted triangle size for small canvas
int rotationSpeed = 5; // Slower rotation for better visuals
int rotation = 0;
int timer = 0;
boolean smallCircles = true;
Random rand = new Random();

void setup() {
  size(32, 32);
  frameRate(25);
  noFill();
  smooth();

  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * (COLOR_DEPTH / 8)];

  // List available serial ports and initialize the selected port
  String[] list = Serial.list();
  printArray(list);

  try {
    final String PORT_NAME = "/dev/tty.usbserial-02B62278"; // Replace with your port
    serial = new Serial(this, PORT_NAME, BAUD_RATE);
    println("Serial port initialized: " + PORT_NAME);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  background(#CF2945); // red

  // Draw the 32x32 grid of large circles
  fill(#389623); // Light white color for large circles
  for (int x = 2; x < width; x += 4) { // Spacing: Adjust for a 32x32 grid
    for (int y = 2; y < height; y += 4) {
      ellipse(x, y, 3, 3); // Small circle size for grid fit
    }
  }

  // On mouse press, alternate effects between small circles and rotating triangles
  if (mousePressed) {
    if (timer <= 0) {
      timer = rand.nextInt(6) + 1;
      smallCircles = !smallCircles;
    }

    if (smallCircles) {
      // Draw smaller circles over the grid
      fill(#389623); // Background color to "erase" parts of large circles
      for (int x = 2; x < width; x += 4) {
        for (int y = 2; y < height; y += 4) {
          ellipse(x, y, 2, 2); // Smaller circles
        }
      }
    } else {
      // Draw rotating triangles
      fill(#DA8B15); // yellow
      for (int x = 4; x < width; x += 8) { // Spacing for triangles
        for (int y = 4; y < height; y += 8) {
          drawTriangle(x, y, triangleSize, rotation);
        }
      }
    }

    rotation += rotationSpeed; // Update rotation for animation
    timer--;
  }

  // Send the canvas data to the serial port
  sendCanvasToSerial();
}

// Draws a triangle at (x, y) with a given size and rotation
void drawTriangle(int x, int y, int size, int rot) {
  int x1 = (int) (x + Math.round(size * Math.cos(Math.toRadians(rot))));
  int x2 = (int) (x + Math.round(size * Math.cos(Math.toRadians(120 + rot))));
  int x3 = (int) (x + Math.round(size * Math.cos(Math.toRadians(240 + rot))));

  int y1 = (int) (y - Math.round(size * Math.sin(Math.toRadians(rot))));
  int y2 = (int) (y - Math.round(size * Math.sin(Math.toRadians(120 + rot))));
  int y3 = (int) (y - Math.round(size * Math.sin(Math.toRadians(240 + rot))));
  triangle(x1, y1, x2, y2, x3, y3);
}

// Sends the canvas data as a pixel buffer via the serial port
void sendCanvasToSerial() {
  if (serial != null) {
    loadPixels();
    int idx = 0;

    if (COLOR_DEPTH == 16) {
      for (int i = 0; i < pixels.length; i++) {
        color c = pixels[i];
        byte r = (byte) (c >> 16 & 0xFF); // Extract red
        byte g = (byte) (c >> 8 & 0xFF);  // Extract green
        byte b = (byte) (c & 0xFF);       // Extract blue
        int rgb16 = packRGB16(r, g, b);
        byte[] bytes = splitBytes(rgb16);
        buffer[idx++] = bytes[0];
        buffer[idx++] = bytes[1];
      }
    }

    serial.write('*');    // Command to indicate data
    serial.write(buffer); // Send the pixel data
  }
}

// Packs RGB values into 16-bit (5-6-5) format
int packRGB16(byte r, byte g, byte b) {
  byte r5 = (byte) ((r >> 3) & 0x1F);
  byte g6 = (byte) ((g >> 2) & 0x3F);
  byte b5 = (byte) ((b >> 3) & 0x1F);
  return (r5 << 11) | (g6 << 5) | b5;
}

// Splits a 16-bit int into two bytes
byte[] splitBytes(int int16) {
  byte highByte = (byte) ((int16 >> 8) & 0xFF);
  byte lowByte = (byte) (int16 & 0xFF);
  return new byte[] { highByte, lowByte };
}
