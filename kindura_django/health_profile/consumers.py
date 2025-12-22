import json
from channels.generic.websocket import AsyncWebsocketConsumer

class WatchVitalsConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        # All clients join the same group for watch vitals updates
        self.group_name = 'watch_vitals'

        # Join the group
        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name
        )

        await self.accept()
        print(f"✅ WebSocket connected: {self.channel_name}")

    async def disconnect(self, close_code):
        # Leave the group
        await self.channel_layer.group_discard(
            self.group_name,
            self.channel_name
        )
        print(f"❌ WebSocket disconnected: {self.channel_name}")

    async def receive(self, text_data):
        # Handle incoming messages from clients (if needed)
        pass

    async def watch_vitals_update(self, event):
        """
        Handler for watch_vitals_update messages from channel layer.
        Sends the vitals data to the WebSocket client.
        """
        vitals = event['vitals']

        # Send the vitals to the WebSocket client
        await self.send(text_data=json.dumps({
            'type': 'watch_vitals',
            'data': vitals
        }))
