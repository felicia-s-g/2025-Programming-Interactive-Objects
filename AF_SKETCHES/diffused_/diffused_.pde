import java.util.Random;
import processing.serial.*;

Serial serial;

final int TOTAL_WIDTH  = 32;       // Canvas width (Matrix width)
final int TOTAL_HEIGHT = 32;       // Canvas height (Matrix height)
final int COLOR_DEPTH  = 16;       // Color depth: 16 bits (5-6-5 format)
final int BAUD_RATE    = 921600;   // Serial baud rate

byte[] buffer;
int lastPosX = 0;
int lastPosY = 0;
boolean movement = false;
Random rand = new Random();

void setup() {
  size(320, 320);  // Scaled up canvas for visibility
  frameRate(25);   // Frame rate
  noFill();
  smooth();
  noStroke();
  background(#000000);

  // Initialize the serial port
  try {
    final String PORT_NAME = "/dev/tty.usbserial-02B62278"; // Replace with your port
    serial = new Serial(this, PORT_NAME, BAUD_RATE);
    println("Serial port initialized: " + PORT_NAME);
  } catch (Exception e) {
    println("Serial port not initialized...");
  }
}

void draw() {
  if (movement && mouseX != 0 && mouseY != 0) {
    int posDifX = (lastPosX - mouseX);
    int posDifY = (lastPosY - mouseY);
    int a = (int)Math.round((Math.sqrt(posDifX * posDifX + posDifY * posDifY)) / 3);  // Adjusted size scaling for matrix

    // Draw the circle on the scaled-up canvas
    ellipse(mouseX * 10, mouseY * 10, a * 10, a * 10);
    
    // Apply blur effect
    filter(BLUR, 4);

    // Transfer the circle shape to matrix representation
    drawToMatrix(mouseX, mouseY, a);

    movement = false;
    lastPosX = mouseX;
    lastPosY = mouseY;
  } else {
    filter(BLUR, 4);
  }
}

// Mouse movement triggers a flag
void mouseMoved() {
  movement = true;
}

// Reset background on mouse press
void mousePressed() {
  background(#000000);
}

// Function to draw to matrix
void drawToMatrix(int mx, int my, int radius) {
  // Map mouse position to matrix coordinates
  int matrixX = constrain(mx, 0, TOTAL_WIDTH - 1);
  int matrixY = constrain(my, 0, TOTAL_HEIGHT - 1);

  // Create a basic circular pattern on the matrix
  for (int y = -radius; y <= radius; y++) {
    for (int x = -radius; x <= radius; x++) {
      int dist = (int) Math.sqrt(x * x + y * y);  // Calculate distance to center

      // Check if pixel lies within the circle
      if (dist <= radius) {
        int pixelX = matrixX + x;
        int pixelY = matrixY + y;

        if (pixelX >= 0 && pixelX < TOTAL_WIDTH && pixelY >= 0 && pixelY < TOTAL_HEIGHT) {
          color c = getCircleColor(dist, radius);  // Get the color for this pixel
          
          // Update the buffer to send to the serial
          int idx = (pixelY * TOTAL_WIDTH + pixelX) * 3;
          buffer[idx] = (byte) red(c);
          buffer[idx + 1] = (byte) green(c);
          buffer[idx + 2] = (byte) blue(c);
        }
      }
    }
  }
  
  // Send the data to the matrix (serial communication)
  sendCanvasToSerial();
}

// Function to create a color gradient based on distance from center
color getCircleColor(int dist, int radius) {
  float intensity = map(dist, 0, radius, 1, 0);
  return color(255 * intensity, 0, 255 * (1 - intensity));  // RGB gradient (purple to blue)
}

// Send the buffer data to the serial port
void sendCanvasToSerial() {
  if (serial != null) {
    serial.write('*'); // Start of frame marker
    serial.write(buffer); // Send the pixel buffer to the serial port
  }
}

  
  
  
  
  
  
  
//  background(#CF2945); // red

//  // Draw the 32x32 grid of large circles
//  fill(#389623); // Light white color for large circles
//  for (int x = 2; x < width; x += 4) { // Spacing: Adjust for a 32x32 grid
//    for (int y = 2; y < height; y += 4) {
//      ellipse(x, y, 3, 3); // Small circle size for grid fit
//    }
//  }

//  // On mouse press, alternate effects between small circles and rotating triangles
//  if (mousePressed) {
//    if (timer <= 0) {
//      timer = rand.nextInt(6) + 1;
//      smallCircles = !smallCircles;
//    }

//    if (smallCircles) {
//      // Draw smaller circles over the grid
//      fill(#389623); // Background color to "erase" parts of large circles
//      for (int x = 2; x < width; x += 4) {
//        for (int y = 2; y < height; y += 4) {
//          ellipse(x, y, 2, 2); // Smaller circles
//        }
//      }
//    } else {
//      // Draw rotating triangles
//      fill(#DA8B15); // yellow
//      for (int x = 4; x < width; x += 8) { // Spacing for triangles
//        for (int y = 4; y < height; y += 8) {
//          drawTriangle(x, y, triangleSize, rotation);
//        }
//      }
//    }

//    rotation += rotationSpeed; // Update rotation for animation
//    timer--;
//  }

//  // Send the canvas data to the serial port
//  sendCanvasToSerial();
//}

//// Draws a triangle at (x, y) with a given size and rotation
//void drawTriangle(int x, int y, int size, int rot) {
//  int x1 = (int) (x + Math.round(size * Math.cos(Math.toRadians(rot))));
//  int x2 = (int) (x + Math.round(size * Math.cos(Math.toRadians(120 + rot))));
//  int x3 = (int) (x + Math.round(size * Math.cos(Math.toRadians(240 + rot))));

//  int y1 = (int) (y - Math.round(size * Math.sin(Math.toRadians(rot))));
//  int y2 = (int) (y - Math.round(size * Math.sin(Math.toRadians(120 + rot))));
//  int y3 = (int) (y - Math.round(size * Math.sin(Math.toRadians(240 + rot))));
//  triangle(x1, y1, x2, y2, x3, y3);
//}

//// Sends the canvas data as a pixel buffer via the serial port
//void sendCanvasToSerial() {
//  if (serial != null) {
//    loadPixels();
//    int idx = 0;

//    if (COLOR_DEPTH == 16) {
//      for (int i = 0; i < pixels.length; i++) {
//        color c = pixels[i];
//        byte r = (byte) (c >> 16 & 0xFF); // Extract red
//        byte g = (byte) (c >> 8 & 0xFF);  // Extract green
//        byte b = (byte) (c & 0xFF);       // Extract blue
//        int rgb16 = packRGB16(r, g, b);
//        byte[] bytes = splitBytes(rgb16);
//        buffer[idx++] = bytes[0];
//        buffer[idx++] = bytes[1];
//      }
//    }

//    serial.write('*');    // Command to indicate data
//    serial.write(buffer); // Send the pixel data
//  }
//}

//// Packs RGB values into 16-bit (5-6-5) format
//int packRGB16(byte r, byte g, byte b) {
//  byte r5 = (byte) ((r >> 3) & 0x1F);
//  byte g6 = (byte) ((g >> 2) & 0x3F);
//  byte b5 = (byte) ((b >> 3) & 0x1F);
//  return (r5 << 11) | (g6 << 5) | b5;
//}

//// Splits a 16-bit int into two bytes
//byte[] splitBytes(int int16) {
//  byte highByte = (byte) ((int16 >> 8) & 0xFF);
//  byte lowByte = (byte) (int16 & 0xFF);
//  return new byte[] { highByte, lowByte };
//}
