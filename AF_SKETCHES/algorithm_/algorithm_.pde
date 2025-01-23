import processing.serial.*;

// constants
// >>>>>>>>>>>>>>>>>>>>>>>>
final int TOTAL_WIDTH       = 32;
final int TOTAL_HEIGHT      = 32;
final int BAUD_RATE         = 921600;
final int IMAGE_DISPLAY_TIME = 3000;

// global
// >>>>>>>>>>>>>>>>>>>>>>>>
Serial serial;
byte[] buffer;

PImage baseImage;
PGraphics renderedTree;
int lastRenderTime = 0;


// setup
// >>>>>>>>>>>>>>>>>>>>>>>>
void setup() {
  size(32 * 10, 32 * 10);
  frameRate(30);

  // init img
  baseImage = loadImage("image1.png");
  baseImage.resize(TOTAL_WIDTH, TOTAL_HEIGHT);

   // init buffer
  buffer = new byte[TOTAL_WIDTH * TOTAL_HEIGHT * 2];

  // init serial comm
  try {
    String portName = "/dev/tty.usbserial-02B62278";
    serial = new Serial(this, portName, BAUD_RATE);
  }
  catch (Exception e) {
    println("Serial port not initialized...");
  }
  
  // constructing PGraphics object
  renderedTree = createGraphics(TOTAL_WIDTH, TOTAL_HEIGHT);
  // track time
  lastRenderTime = millis();
}

// draw
// >>>>>>>>>>>>>>>>>>>>>>>>
void draw() {
  
  background(0);
  
  if (millis() - lastRenderTime > IMAGE_DISPLAY_TIME) {
    createRandomTreeVariant();
    lastRenderTime = millis();
  }

  image(renderedTree, 0, 0, width, height);
  
  sendToSerial();
  
}

// actual tree creation
// >>>>>>>>>>>>>>>>>>>>>>>>
void createRandomTreeVariant() {
  renderedTree.beginDraw();
  renderedTree.background(0);

  // 1) Draw the base skeleton image
  renderedTree.image(baseImage, 0, 0);

  // 2) Draw random tulpini
  //    e.g.: random position, number, color, etc.
  //    randomTree.fill(...);
  //    randomTree.rect(...);  // or use line, ellipse, etc.

  // 3) Draw random flowers
  //    e.g.: random # of flowers, random positions
  //    Make sure they don't overlap if needed
  //    randomTree.ellipse(...);

  renderedTree.endDraw();
}

void sendToSerial() {
  if (serial != null) {

    renderedTree.loadPixels();

    int idx = 0;
    for (int y = 0; y < TOTAL_HEIGHT; y++) {
      for (int x = 0; x < TOTAL_WIDTH; x++) {
        color c = renderedTree.get(x, y);
        int rgb16 = packRGB16(int(red(c)), int(green(c)), int(blue(c)));
        buffer[idx++] = (byte)((rgb16 >> 8) & 0xFF);
        buffer[idx++] = (byte)(rgb16 & 0xFF);
      }
    }
    serial.write('*');
    serial.write(buffer);
  }
}

// RGB to 16-bit color
int packRGB16(int r, int g, int b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}
