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
If you are facing the error ``` *** [upload] Error 2 ``` like:
```
Connecting........_____....._____....._____....._____....._____....._____....._____

A fatal error occurred: Failed to connect to ESP32: Timed out waiting for packet header
*** [upload] Error 2
========================================================= [FAILED] Took 30.98 seconds =========================================================

 *  The terminal process "platformio 'run', '--target', 'upload'" terminated with exit code: 1. 
 *  Terminal will be reused by tasks, press any key to close it.
```
you could have a connection issue with between your mac and your board.<br>
To solve this refer to the folder ```z1_connection_issue```.<br>

The folder is structured as follows:
```
  src
    main.cpp
    common
      pico_driver_v5_pinout.h
  platformio.ini
  extra_script.py
```

#### What is different from the other examples?<br>
We have added a file named: ```extra_script.py```; This file contains a piece of code to perform a ```default_reset``` before the board upload the platformio project.<br>
So, make sure to have the ```extra_script.py``` file in your folder at the same level as ```platformio.ini```.<br>
In order to let know platformio to run the personalised script before the uploading of the project you need to be sure that inside your ```platformio.ini``` file you added the following lines:
```
; Include the custom pre-upload script
extra_scripts = pre:extra_script.py
```

Finally, before uploading the code into your board, be sure to not have the port selection as "Auto". You need to select the board you want to let the personalised script know the address of your board. To select the port just click on the connection icon, placed in the bottom status bar, "Set upload/monitor/test port" and select your usbserial port.
