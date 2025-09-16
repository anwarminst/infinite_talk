#!/bin/bash

# Function to check if ComfyUI is ready
wait_for_comfyui() {
    echo "Waiting for ComfyUI to be ready..."
    max_wait=120
    wait_count=0
    while [ $wait_count -lt $max_wait ]; do
        if curl -s http://127.0.0.1:8188/ > /dev/null 2>&1; then
            echo "ComfyUI is ready!"
            return 0
        fi
        echo "Waiting for ComfyUI... ($wait_count/$max_wait)"
        sleep 2
        wait_count=$((wait_count + 2))
    done
    return 1
}

# Start supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
