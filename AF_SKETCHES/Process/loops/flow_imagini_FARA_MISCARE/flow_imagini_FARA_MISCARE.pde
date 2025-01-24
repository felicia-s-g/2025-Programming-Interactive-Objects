PImage[] images;           // Array to hold the images
int currentImage = 0;      // Index of the current image
int totalImages = 5;       // Total number of images in the slideshow
int displayTime = 3000;    // Time each image is displayed (in milliseconds)
int lastChangeTime = 0;    // Timestamp of the last image change

void setup() {
  size(800, 600);          // Set the window size to 800x600 pixels
  
  // Initialize the images array
  images = new PImage[totalImages];
  
  // Load images into the array
  for (int i = 0; i < totalImages; i++) {
    String imageName = "image" + (i + 1) + ".jpg"; // e.g., image1.jpg
    images[i] = loadImage(imageName);
    
    // Optional: Resize images to fit the window
    if (images[i] != null) {
      images[i].resize(width, height);
    } else {
      println("Could not load " + imageName);
    }
  }
  
  // Initialize the timestamp
  lastChangeTime = millis();
}

void draw() {
  background(0); // Clear the background with black color
  
  // Display the current image if it's loaded
  if (images[currentImage] != null) {
    image(images[currentImage], 0, 0);
  }
  
  // Check if it's time to change to the next image
  if (millis() - lastChangeTime > displayTime) {
    currentImage = (currentImage + 1) % totalImages; // Move to the next image
    lastChangeTime = millis();                        // Reset the timestamp
  }
}
