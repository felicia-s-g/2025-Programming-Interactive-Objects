import subprocess
import sys
import serial.tools.list_ports
Import("env")

def ensure_esptool_installed():
    try:
        import esptool
        return esptool
    except ImportError:
        print("esptool not found. Installing...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "esptool"])
        import esptool
        print("esptool installed successfully.")
        return esptool

def detect_upload_port():
    for port in serial.tools.list_ports.comports():
        if "cu.usbserial" in port.name:
            print(f"Found upload port: /dev/{port.name}")
            return f"/dev/{port.name}"

    print("Error: No suitable upload port found. Ensure the device is connected.")
    env.Exit(1)

esptool = ensure_esptool_installed()

def before_upload(source, target, env):
    upload_port = detect_upload_port()

    args = [
        "--chip", "auto",
        "--port", upload_port,
        "--baud", env.subst("$UPLOAD_SPEED"),
        "--before", "default_reset",
        "--after", "hard_reset",
        "erase_flash"
    ]
    
    print(f"Executing esptool with arguments: {args}")
    esptool.main(args)

env.AddPreAction("upload", before_upload)