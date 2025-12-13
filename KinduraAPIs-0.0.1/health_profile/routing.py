from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/watch-vitals/$', consumers.WatchVitalsConsumer.as_asgi()),
]
