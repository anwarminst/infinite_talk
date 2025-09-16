import subprocess
import requests
import time
import os
import sys
import signal

def start_comfy_server():
    """Start the ComfyUI server as a subprocess"""
    comfy_dir = '/workspace/ComfyUI'
    
    # Activate the virtual environment
    venv_python = os.path.join(comfy_dir, 'venv', 'bin', 'python')
    
    # Start ComfyUI server using the existing venv
    process = subprocess.Popen(
        [venv_python, 'main.py', '--listen', '0.0.0.0', '--port', '8188'],
        cwd=comfy_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    
    # Wait for server to start
    start_time = time.time()
    while time.time() - start_time < 60:  # Wait up to 60 seconds
        try:
            # Try to connect to the server
            response = requests.get('http://127.0.0.1:8188/server_status')
            if response.status_code == 200:
                print("ComfyUI server is ready!")
                return process
        except requests.exceptions.ConnectionError:
            time.sleep(1)
            continue
    
    # If we get here, server didn't start
    process.kill()
    raise RuntimeError("ComfyUI server failed to start within 60 seconds")

def cleanup(process):
    """Clean up the server process"""
    if process:
        process.kill()
        process.wait()

if __name__ == '__main__':
    # Start the server
    server_process = None
    try:
        server_process = start_comfy_server()
        
        # Set up signal handlers for graceful shutdown
        def signal_handler(signum, frame):
            cleanup(server_process)
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        # Keep the script running
        while True:
            time.sleep(1)
    except Exception as e:
        print(f"Error: {str(e)}")
        cleanup(server_process)
        sys.exit(1)
