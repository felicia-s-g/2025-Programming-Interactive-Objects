import java.util.Random;

static final int DIVISION_FACTOR = 8;
int lastPosX, lastPosY;
Random rand;
boolean movement;


void setup () {

  size(32, 32);
  frameRate(30);
  noFill(); 
  smooth() ; 
  noStroke();
  background (#000000);
  fill(#CF2945);
  lastPosX = 0;
  lastPosY = 0;
  movement = false;
  rand = new Random();
}

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

if(movement && mouseX != 0 && mouseY != 0) {
 int posDifX = (lastPosX - mouseX);
 int posDifY = (lastPosY - mouseY);
 int a = (int)Math.round((Math.sqrt(posDifX*posDifX + posDifY*posDifY))/DIVISION_FACTOR); 
 ellipse(mouseX, mouseY, a,a);
 filter(BLUR, 4);
 movement = false;
 lastPosX = mouseX;
 lastPosY = mouseY;
}
else {
 filter(BLUR, 4);
}
} 

void mouseMoved() {
  movement = true;
 
}
void mousePressed(){
background(#000000);
}
