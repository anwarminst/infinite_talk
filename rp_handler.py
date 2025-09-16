from handler import handler
import runpod

# Start the RunPod serverless handler
runpod.serverless.start({"handler": handler})
