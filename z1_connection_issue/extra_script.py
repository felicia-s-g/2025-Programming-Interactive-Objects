import os
from os.path import expanduser
Import("env")

def before_upload(source, target, env):
    print("Let's erase the flash before uploading")
    # Retrieve the upload port from platformio.ini
    upload_port = env.subst("$UPLOAD_PORT")
    
    # Define the path to esptool (adjust based on your system)
    esptool_path = os.path.join(
        expanduser("~"),
        "Library/Arduino15/packages/esp32/tools/esptool_py/4.5.1/esptool"
    )
    
    print(f"Using port: {upload_port}")
    print(f"Using esptool: {esptool_path}")
    
    # Run the reset command using esptool with dynamic port and path
    env.Execute(
        f"'{esptool_path}' --chip esp32 --port '{upload_port}' --baud 921600 --before default_reset --after hard_reset erase_flash"
    )
    
    print("Now we can upload platformio project")

# Attach the pre-upload action
env.AddPreAction("upload", before_upload)