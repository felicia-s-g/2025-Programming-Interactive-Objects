/**
 * This Processing sketch displays a series of images in a slideshow
 * and sends all the pixels of the current image to the serial port.
 */

import processing.serial.*;

final int TOTAL_WIDTH  = 32;
final int TOTAL_HEIGHT = 32;
final int COLOR_DEPTH  = 16; // 24 or 16 bits
final int BAUD_RATE    = 921600;

Serial serial;
byte[] buffer;

// Array to hold multiple images
PImage[] images;
int totalImages = 5;        // Total number of images
int currentImage = 0;       // Index of the current image
int displayTime = 3000;     // Time each image is displayed (in milliseconds)
int lastChangeTime = 0;     // Timestamp of the last image change

void setup() {
  size(32,32);
  smooth(8);
  
  // Initialize the images array
  images = new PImage[totalImages];
  
  // Load images into the array
  for (int i = 0; i < totalImages; i++) {
    String imageName = "image" + (i + 1) + ".png"; // e.g., image1.jpg
    images[i] = loadImage(imageName);
    
    if (images[i] != null) {
      images[i].resize(TOTAL_WIDTH, TOTAL_HEIGHT); // Resize to match matrix size
    } else {
      println("Could not load " + imageName);
    }
  }
  
  // Initialize the buffer
  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * (COLOR_DEPTH / 8)];
  
  // List available serial ports
  String[] list = Serial.list();
  printArray(list);
  
  try {
    // Replace with your actual port name
    final String PORT_NAME = "/dev/cu.usbserial-02B5FCCE"; // macOS/Linux
    // final String PORT_NAME = "COM3"; // Windows
    serial = new Serial(this, PORT_NAME, BAUD_RATE);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
  
  // Initialize the timestamp
  lastChangeTime = millis();
}

void draw() {
  background(0); // Clear the canvas
  
  // Display the current image
  if (images[currentImage] != null) {
    image(images[currentImage], 0, 0);
  }
  
  // Check if it's time to change to the next image
  if (millis() - lastChangeTime > displayTime) {
    currentImage = (currentImage + 1) % totalImages; // Move to next image
    lastChangeTime = millis();                       // Reset the timestamp
  }
  
  // --------------------------------------------------------------------------
  // Write to the serial port (if open)
  if (serial != null) {
    loadPixels();
    images[currentImage].loadPixels(); // Ensure pixels are loaded from the image
    int idx = 0;
    
    if (COLOR_DEPTH == 24) {
      for (int i = 0; i < pixels.length; i++) {
        color c = images[currentImage].pixels[i];
        buffer[idx++] = (byte)((c >> 16) & 0xFF); // R
        buffer[idx++] = (byte)((c >> 8) & 0xFF);  // G
        buffer[idx++] = (byte)(c & 0xFF);         // B
      }
    } else if (COLOR_DEPTH == 16) {
      for (int i = 0; i < pixels.length; i++) {
        color c = images[currentImage].pixels[i];
        byte r = (byte)((c >> 16) & 0xFF); // R
        byte g = (byte)((c >> 8) & 0xFF);  // G
        byte b = (byte)(c & 0xFF);         // B
        int rgb16 = packRGB16(r, g, b);
        byte[] bytes = splitBytes(rgb16);
        buffer[idx++] = bytes[0];
        buffer[idx++] = bytes[1];
      }
    }
    
    serial.write('*');     // The 'data' command
    serial.write(buffer);  // Send the pixel values
  }
}

// Convert 8-bit RGB values to 5-6-5 bits
// Pack into 16-bit value: RRRRRGGG GGGBBBBB
int packRGB16(byte r, byte g, byte b) {
  byte r5 = (byte)((r >> 3) & 0x1F);  // 5 bits for red
  byte g6 = (byte)((g >> 2) & 0x3F);  // 6 bits for green
  byte b5 = (byte)((b >> 3) & 0x1F);  // 5 bits for blue
  return (r5 << 11) | (g6 << 5) | b5;
}

// Split a 16-bit int into two bytes
byte[] splitBytes(int int16) {
  byte highByte = (byte)((int16 >> 8) & 0xFF);  // Upper 8 bits
  byte lowByte  = (byte)(int16 & 0xFF);         // Lower 8 bits
  return new byte[]{highByte, lowByte};
}
