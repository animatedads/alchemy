import asyncio
import websockets

async def echo(ws):
    async for message in ws:
        await ws.send(message)

async def main():
    async with websockets.serve(echo, "127.0.0.1", 18765):
        print("READY", flush=True)
        await asyncio.Future()

asyncio.run(main())
