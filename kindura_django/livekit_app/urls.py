from django.urls import path
from . import views

app_name = 'livekit'

urlpatterns = [
    path('get-token/', views.get_token, name='get_token'),
    path('delete-room/', views.delete_room, name='delete_room'),
] 