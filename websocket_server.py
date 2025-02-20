import asyncio
import websockets
import subprocess

async def handle_test_failure(websocket, path):
    async for message in websocket:
        print(f"Received failure message: {message}")
        
        # Pull the fixed version from GitHub
        print("Fetching correct version from GitHub...")
        subprocess.run(["git", "checkout", "fixed_version"], check=True)
        
        # Build and push the fixed Docker image
        print("Building new Docker image...")
        subprocess.run(["docker", "build", "-t", "gbedu/helloworld:fixed", "."], check=True)
        subprocess.run(["docker", "push", "gbedu/helloworld:fixed"], check=True)

        # Deploy to Production
        print("Redeploying fixed version to Production...")
        subprocess.run(["kubectl", "apply", "-f", "k8s/prod-deployment.yaml"], check=True)

        await websocket.send("Fixed version deployed!")

start_server = websockets.serve(handle_test_failure, "0.0.0.0", 8765)

print("WebSocket server running on ws://0.0.0.0:8765")
asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
