import java.util.Random;
import processing.serial.*;

Serial serial;

final int TOTAL_WIDTH  = 32;       // Canvas width (Matrix width)
final int TOTAL_HEIGHT = 32;       // Canvas height (Matrix height)
final int COLOR_DEPTH  = 16;       // Color depth: 16 bits (5-6-5 format)
final int BAUD_RATE    = 921600;   // Serial baud rate

byte[] buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 3];
int lastPosX = 0;
int lastPosY = 0;
boolean movement = false;
Random rand = new Random();

// Color palette from example, replacing green-heavy scheme
color glitchColor1 = color(207, 41, 69);   // #CF2945 (Vibrant red/pink)
color glitchColor2 = color(218, 139, 21);  // #DA8B15 (Orange)
color glitchColor3 = color(56, 150, 35);   // #389623 (Green)

void setup() {
  size(320, 320);  // Scaled-up canvas for visibility
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
  // Check if the mouse is being moved
  if (movement && mouseX != 0 && mouseY != 0) {
    int posDifX = (lastPosX - mouseX);
    int posDifY = (lastPosY - mouseY);
    int a = (int)Math.round((Math.sqrt(posDifX * posDifX + posDifY * posDifY)) / 3);  // Adjusted size scaling for matrix

    // Draw visible circles for feedback on the scaled-up canvas
    ellipse(mouseX * 10, mouseY * 10, a * 10, a * 10);
    
    // Apply blur effect for smoother visuals
    filter(BLUR, 4);

    // Transfer the circle shape to the matrix representation (with glitchy effect)
    drawToMatrix(mouseX, mouseY, a);

    movement = false;
    lastPosX = mouseX;
    lastPosY = mouseY;
  } else {
    filter(BLUR, 4);
  }

  // Ensure serial communication only if serial is initialized
  if (serial != null) {
    sendCanvasToSerial();
  }
}

// Mouse movement triggers the drawing
void mouseMoved() {
  movement = true;
}

// Reset background on mouse press
void mousePressed() {
  background(#000000);
}

// Function to draw to matrix with glitchy effects
void drawToMatrix(int mx, int my, int radius) {
  // Map mouse position to matrix coordinates
  int matrixX = constrain(mx, 0, TOTAL_WIDTH - 1);
  int matrixY = constrain(my, 0, TOTAL_HEIGHT - 1);

  // Introduce glitch effect by randomly shifting the circle
  int randomShiftX = (int) random(-1, 1);  // Glitch horizontal shift (smaller)
  int randomShiftY = (int) random(-1, 1);  // Glitch vertical shift (smaller)

  // Create a basic circular pattern with glitches on the matrix
  for (int y = -radius; y <= radius; y++) {
    for (int x = -radius; x <= radius; x++) {
      int dist = (int) Math.sqrt(x * x + y * y);  // Calculate distance to center

      // Check if pixel lies within the circle
      if (dist <= radius) {
        int pixelX = matrixX + x + randomShiftX;
        int pixelY = matrixY + y + randomShiftY;

        // Ensure the pixel stays within bounds
        if (pixelX >= 0 && pixelX < TOTAL_WIDTH && pixelY >= 0 && pixelY < TOTAL_HEIGHT) {
          color c = getGlitchColor(dist, radius);  // Get the color for this pixel with glitches
          
          // Update the buffer to send to the serial
          int idx = (pixelY * TOTAL_WIDTH + pixelX) * 3;
          buffer[idx] = (byte) red(c);
          buffer[idx + 1] = (byte) green(c);
          buffer[idx + 2] = (byte) blue(c);
        }
      }
    }
  }
}

// Function to create glitchy color gradient based on distance from center
color getGlitchColor(int dist, int radius) {
  // Introduce glitch effect (more controlled color palette)
  float intensity = map(dist, 0, radius, 1, 0);

  // The glitch effect will alternate between the colors based on distance
  if (dist < radius / 3) {
    return glitchColor1;  // Vibrant red/pink
  } else if (dist < 2 * radius / 3) {
    return glitchColor2;  // Orange
  } else {
    return glitchColor3;  // Green
  }
}

// Send the buffer data to the serial port
void sendCanvasToSerial() {
  if (serial != null) {
    serial.write('*'); // Start of frame marker
    serial.write(buffer); // Send the pixel buffer to the serial port
  }
}
