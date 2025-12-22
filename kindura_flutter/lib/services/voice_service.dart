import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class VoiceService extends GetxController {
  // Voice command handlers
  final List<Function(String, double)> _medicationHandlers = [];
  
  // Voice listening state
  var isListening = false.obs;
  var lastCommand = ''.obs;
  
  @override
  void onInit() {
    super.onInit();
    _initializeVoiceService();
  }
  
  void _initializeVoiceService() {
    // Initialize voice service functionality
    if (kDebugMode) {
      print('Voice service initialized');
    }
  }
  
  void addMedicationVoiceHandler(Function(String, double) handler) {
    _medicationHandlers.add(handler);
  }
  
  void removeMedicationVoiceHandler(Function(String, double) handler) {
    _medicationHandlers.remove(handler);
  }
  
  void startListeningForMedicationCommands() {
    isListening.value = true;
    if (kDebugMode) {
      print('Started listening for medication commands');
    }
  }
  
  void stopListening() {
    isListening.value = false;
    if (kDebugMode) {
      print('Stopped listening for voice commands');
    }
  }
  
  void processVoiceCommand(String command, double confidence) {
    lastCommand.value = command;
    
    // Notify all medication handlers
    for (final handler in _medicationHandlers) {
      try {
        handler(command, confidence);
      } catch (e) {
        if (kDebugMode) {
          print('Error in voice command handler: $e');
        }
      }
    }
  }
  
  @override
  void onClose() {
    stopListening();
    _medicationHandlers.clear();
    super.onClose();
  }
}