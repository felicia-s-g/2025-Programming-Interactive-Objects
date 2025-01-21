
#include "common/pico_driver_v5_pinout.h"

#include <Arduino.h>
#include <SmartMatrix.h>

#define COLOR_DEPTH 24   // valid: 24, 48
#define TOTAL_WIDTH 64   // Total width of the chained matrices
#define TOTAL_HEIGHT 32  // Total height of the chained matrices
#define kRefreshDepth 24 // Valid: 24, 36, 48
#define kDmaBufferRows 4 // Valid: 2-4
#define kPanelType SM_PANELTYPE_HUB75_32ROW_32COL_MOD8SCAN // custom
#define kMatrixOptions (SM_HUB75_OPTIONS_NONE)
#define kbgOptions (SM_BACKGROUND_OPTIONS_NONE)

// SmartMatrix setup & buffer allocation
SMARTMATRIX_ALLOCATE_BUFFERS(matrix, TOTAL_WIDTH, TOTAL_HEIGHT, kRefreshDepth, kDmaBufferRows, kPanelType, kMatrixOptions);

// A single background layer "bg"
SMARTMATRIX_ALLOCATE_BACKGROUND_LAYER(bg, TOTAL_WIDTH, TOTAL_HEIGHT, COLOR_DEPTH, kbgOptions);

void setup() {
    // On board LED (useful for debugging)
    pinMode(PICO_LED_PIN, OUTPUT);

    // Turn the on board LED on
    digitalWrite(PICO_LED_PIN, 1);

    bg.enableColorCorrection(true);
    matrix.addLayer(&bg);
    matrix.setBrightness(255);

    // Init the library and the matrix
    matrix.begin();
}

int frame = 0;

void loop() {
    // Clear the screen
    bg.fillScreen({0, 0, 0});

    // Set the font
    // bg.setFont(font3x5);
    // bg.setFont(font5x7);
    bg.setFont(font6x10);
    // bg.setFont(font8x13);
    // bg.setFont(gohufont11);
    // bg.setFont(gohufont11b);

	const char* text = "Zestre  Dor  Obicei ";
	int textWidth = strlen(text) * 6; 

	int textX = TOTAL_WIDTH - (frame % textWidth); 
    int textY = TOTAL_HEIGHT / 2 - 5; 


    bg.drawString(textX, TOTAL_HEIGHT / 2 - 6, {200, 40, 60}, text);
	bg.drawString(textX - textWidth, TOTAL_HEIGHT / 2 - 6, {200, 40, 60}, text);
 
    bg.swapBuffers(false);


    frame++;
	delay(70);
}