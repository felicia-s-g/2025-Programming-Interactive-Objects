# One Thousand~ Pixels
SUPSI MAInD  
Programming interctive objects  
Workshop 20–24.1.2025

# Project Brief
The aim of the workshop is to embrace constratints and develop ideas around the limitations of a low resolution display. 

# Topics
- Idea driven development and research 
- Realtime graphics and animation concepts 
- Serial communication 
- Wireless communication
- Quick prototyping 
- LED matrices 

# Part list
- RGB LED matrix 32×32 P6 (P6 means that the LED pitch is 6mm)
- PicoDriver, custom ESP32 controller
- USB-C cable (data and power)
- 5V power cable for the LED matrix (usually comes with the matrix)

Aleternative to the custom PicoDriver:  
- [Teensy 4.0 or 4.1 development board](https://www.pjrc.com/teensy/) (a Teensy 3.2 will do but has limited memory and processor speed)
- [SmartLed shield](https://docs.pixelmatix.com/SmartMatrix/) (not strictly necessary but handy to quickly connect the microcontroller)
- Micro-USB cable for Teensy programming
- 5V power supply (3A minimum), plus cables

# Software requirements
- [VS Code](https://code.visualstudio.com/download)
- [Platformio for VS Code](https://platformio.org) (install as VS Code plugin)
- [GitHub Desktop](https://desktop.github.com) (not mandatory, but handy)
- Some Windows machines may need an extra serial port driver [CP210x USB to UART Bridge](https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers?tab=downloads)  

# Workshop organization

### Day 1  
- “1024 pixels“ assignment and start of the week  
- Introduction to LED matrices  
- Introduction to the ESP32 microcontroller
- Software setup (VS Code, GitHub, etc.)
- Introdcution/recap to Arduino 
- Introduction to serial ports and serial communication
- Introduction to realtime graphics and graphics APIs

### Day 2-4
- Code exercises, theory
- Personal reserach, prototyping, project development 
- Daily feedback and project discussion  

### Day 5
- Presentation 
- Documentation 

# Prepare for the daily project critique
- Try a direction with focus on each of these approaches:  
the phyiscial LED matrix, LEDs as light source(s), context
- Bring something interesting, a little discovery – not an idea for a finished project; let the process guide you
- Show hand drawings and sketches, low-quality screenshots or videos, a little demo, an animation  
- No mood-boards! No projects of others that involve LED matrices! 

### Fallback 
- If you are unable to generate an idea turn the matrix into a (new) clock!

# Issues
## How to solve connection error on macOS (probably on Sonoma and newer)
If you are facing the error ``` *** [upload] Error 2 ``` like the following:
```
Connecting........_____....._____....._____....._____....._____....._____....._____

A fatal error occurred: Failed to connect to ESP32: Timed out waiting for packet header
*** [upload] Error 2
========================================================= [FAILED] Took 30.98 seconds =========================================================
```
you could have a connection issue with between your mac and your board.<br>
To solve this follow those steps:
1. Open the folder ```z1_connection_issue``` in Visual Studio Code and wait until Platformio is correctly setted up;
2. As soon as the setup is completed open the platformio terminal by clicking on the icon in the status bar, if you don't know where is it just refer to this image ![platformio terminal](https://github.com/Master-Interaction-Design-SUPSI/2025-Programming-Interactive-Objects/blob/main/zz_resources/openTerminal.png?raw=true);
3. Write in the terminal the following command ```python3 connection_fix.py```
4. If the terminal is printing ```Updated /Users/yourUsername/.platformio/platforms/espressif32@3.5.0/builder/main.py successfully``` everything worked properly.