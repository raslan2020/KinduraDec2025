import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kindura_ai/data/response/status.dart';
import 'package:kindura_ai/models/home/course_list.dart' as course_models;
import 'package:kindura_ai/models/user_profile/user_profile_model.dart';
import 'package:kindura_ai/repository/home_repository/home_repository.dart';
import 'package:kindura_ai/res/routes/routes_name.dart';
import 'package:kindura_ai/res/app_url/app_url.dart';
import 'package:kindura_ai/utils/utils.dart';
import 'package:kindura_ai/utils/performance_monitor.dart';
import 'package:kindura_ai/user_preference/user_preferences_view_model.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:kindura_ai/screens/medication/medication_controller.dart';
import 'package:kindura_ai/services/watch_vitals_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomeController extends GetxController {
  final HomeRepository _homeRepository = HomeRepository();
  final UserPreferences userPreferences = UserPreferences();
  final PerformanceMonitor _monitor = PerformanceMonitor();
  late WatchVitalsService _watchVitalsService;
  WebSocketChannel? _watchVitalsChannel;
  late livekit.Room room;
  RxBool isConnected = false.obs;

  String token = "";
  DateTime? _connectionStartTime;
  DateTime? _lastTranscriptionTime;

  final requestStatus = Status.COMPLETED.obs;
  final agentStatus = Status.COMPLETED.obs;
  final courseList = course_models.CourseList().obs;
  final userProfile = UserProfile().obs;
  RxString errors = ''.obs;

  // Watch vitals data
  final watchVitals = Rx<Map<String, dynamic>>({
    'heart_rate': 72,
    'blood_oxygen': 98,
    'sleep_hours': 0.0,
    'awakenings': 0,
    'sleep_quality': 'unknown',
    'falls_count': 0,
    'is_demo': true,
  });
  final watchVitalsStatus = Status.COMPLETED.obs;

  // Voice trigger
  final stt.SpeechToText _speech = stt.SpeechToText();
  RxBool isListening = false.obs;
  RxBool hasTriggered = false.obs;
  String recognizedText = "";

  @override
  void onInit() async {
    super.onInit();
    _monitor.startTimer('app_initialization');
    await homeApi();
    _initSpeechRecognition(); // Start listening for trigger word
    _loadMedications(); // Load medications on app startup
    _initWatchVitalsService(); // Initialize Watch vitals sync
    loadWatchVitals(); // Load Watch vitals for widget
    _connectWatchVitalsWebSocket(); // Connect to WebSocket for real-time updates
    _monitor.endTimer('app_initialization');
  }

  void _connectWatchVitalsWebSocket() {
    try {
      // Build WebSocket URL based on API base URL
      String wsUrl;
      if (AppUrl.isLocalEnvironment) {
        wsUrl = 'ws://127.0.0.1:8000/ws/watch-vitals/';
      } else {
        // Convert http to ws for production
        final baseUrl = AppUrl.baseUrl.replaceFirst('http', 'ws').replaceFirst('/api', '');
        wsUrl = '${baseUrl}ws/watch-vitals/';
      }

      print('🔌 Connecting to Watch vitals WebSocket: $wsUrl');
      _watchVitalsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen for messages from the WebSocket
      _watchVitalsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            if (data['type'] == 'watch_vitals' && data['data'] != null) {
              final vitals = data['data'];
              print('📡 WebSocket vitals received: HR=${vitals['heart_rate']}, O2=${vitals['blood_oxygen']}');

              // Update local state immediately
              watchVitals.value = {
                'heart_rate': (vitals['heart_rate'] ?? 72).toDouble(),
                'blood_oxygen': (vitals['blood_oxygen'] ?? 98).toDouble(),
                'sleep_hours': (vitals['total_sleep_hours'] ?? 0).toDouble(),
                'awakenings': vitals['awakenings_count'] ?? 0,
                'sleep_quality': vitals['sleep_quality'] ?? 'unknown',
                'falls_count': vitals['falls_count'] ?? 0,
                'is_demo': false,
              };
              watchVitalsStatus.value = Status.COMPLETED;
            }
          } catch (e) {
            print('❌ Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          // Attempt to reconnect after 5 seconds
          Future.delayed(Duration(seconds: 5), () {
            _connectWatchVitalsWebSocket();
          });
        },
        onDone: () {
          print('⚠️ WebSocket connection closed');
          // Attempt to reconnect after 5 seconds
          Future.delayed(Duration(seconds: 5), () {
            _connectWatchVitalsWebSocket();
          });
        },
      );

      print('✅ WebSocket connected for Watch vitals');
    } catch (e) {
      print('❌ Failed to connect WebSocket: $e');
      // Fallback to polling if WebSocket fails
      Future.delayed(Duration(seconds: 5), () {
        _connectWatchVitalsWebSocket();
      });
    }
  }

  void _initWatchVitalsService() {
    _watchVitalsService = WatchVitalsService();

    // Listen for real-time Watch vitals updates
    _watchVitalsService.onVitalsReceived = (vitals) {
      print('Watch vitals received from Watch: $vitals');

      // Update local state immediately for UI
      watchVitals.value = {
        'heart_rate': (vitals['heart_rate'] ?? 72).toDouble(),
        'blood_oxygen': (vitals['blood_oxygen'] ?? 98).toDouble(),
        'sleep_hours': (vitals['total_sleep_hours'] ?? 0).toDouble(),
        'awakenings': vitals['awakenings_count'] ?? 0,
        'sleep_quality': vitals['sleep_quality'] ?? 'unknown',
        'falls_count': vitals['falls_count'] ?? 0,
        'is_demo': false,
      };

      // Also reload from API to ensure DB sync
      loadWatchVitals();
    };
  }

  Future<void> loadWatchVitals() async {
    try {
      watchVitalsStatus.value = Status.LOADING;
      var value = await _homeRepository.getWatchVitals();

      if (value['status'] == true && value['result'] != null) {
        watchVitals.value = {
          'heart_rate': (value['result']['heart_rate'] ?? 72).toDouble(),
          'blood_oxygen': (value['result']['blood_oxygen'] ?? 98).toDouble(),
          'sleep_hours': (value['result']['sleep_hours'] ?? 0).toDouble(),
          'awakenings': value['result']['awakenings'] ?? 0,
          'sleep_quality': value['result']['sleep_quality'] ?? 'unknown',
          'falls_count': value['result']['falls_count'] ?? 0,
          'is_demo': value['result']['is_demo'] ?? false,
        };
        watchVitalsStatus.value = Status.COMPLETED;
        print("Watch vitals loaded: ${watchVitals.value}");
      } else {
        watchVitalsStatus.value = Status.ERROR;
        print("Failed to load watch vitals");
      }
    } catch (e) {
      watchVitalsStatus.value = Status.ERROR;
      print("Error loading watch vitals: $e");
    }
  }

  void _loadMedications() async {
    try {
      // Initialize medication controller if not already done
      if (!Get.isRegistered<MedicationController>()) {
        Get.put(MedicationController());
      }

      // Load medications from database with timeout
      final medicationController = Get.find<MedicationController>();

      // Don't wait for medications to load to avoid blocking the app
      medicationController.loadMedications(forceRefresh: true).then((_) {
        print("Loaded ${medicationController.medications.length} medications from database");
      }).catchError((e) {
        print("Error loading medications on startup: $e");
      });

      // Also load adherence summary for the home screen display
      medicationController.loadAdherenceSummary().then((_) {
        print("📊 Adherence summary loaded for home screen");
      }).catchError((e) {
        print("Error loading adherence summary: $e");
      });
    } catch (e) {
      print("Error initializing medication controller: $e");
    }
  }

  void _initSpeechRecognition() async {
    _monitor.startTimer('speech_recognition_init');

    // Disable speech recognition for now to prevent looping errors
    _monitor.endTimer('speech_recognition_init');
    _monitor.logPerformanceMetric('speech_recognition_disabled', true);

    // Comment out speech recognition to avoid continuous errors
    // Will re-enable when app is stable
    /*
    bool available = await _speech.initialize(
      onStatus: (status) {
        _monitor.logPerformanceMetric('speech_status_change', status);
        // Only restart listening if no trigger has occurred
        if (!hasTriggered.value &&
            (status == "done" || status == "notListening")) {
          _startListening();
        }
      },
      onError: (error) {
        _monitor.logError('speech_recognition', 'Speech recognition error', error);
        print("Error: $error");
      },
    );

    if (available && !hasTriggered.value) {
      _startListening();
      _monitor.endTimer('speech_recognition_init');
      _monitor.logPerformanceMetric('speech_recognition_available', true);
    } else {
      _monitor.endTimer('speech_recognition_init');
      _monitor.logError('speech_recognition', 'Speech recognition not available or already triggered', null);
    }
    */
  }

  void _startListening() {
    const triggerPhrases = [
      "hey kindura",
      "hey condura", 
      "hey candura",
      "hey kindra",
      "hey kyndura",
      "hey kandra",
      "hey kan dura",
      "hey ken dura",
      "hi kindura",
      "okay kindura",
      "kindura",
      "condura",
      "candura",
      "kindra",
      "kyndura",
      "kandra",
      "dora",
      "ken dora",
      "kendura",
      "gendura",
      "jindura",
      "cindura",
      "syndura",
    ];

    _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords.toLowerCase();
        print("Recognized: $recognizedText");
        _monitor.logPerformanceMetric('speech_recognition_result', recognizedText);

        bool triggerFound = false;
        
        // Check exact matches first
        for (final phrase in triggerPhrases) {
          if (recognizedText.contains(phrase)) {
            _monitor.logVoiceTrigger(recognizedText, true);
            connectToRoom(); // initiate connection
            triggerFound = true;
            break;
          }
        }
        
        // Check fuzzy matches for kindura-like sounds
        if (!triggerFound) {
          final fuzzyTriggers = [
            "i can do it",
            "i can do that",
            "i can dura",
            "i can doing", 
            "i kind of",
            "i conda",
            "icon do it",
            "icon dura",
            "can do it",
            "can dura",
          ];
          
          for (final fuzzyPhrase in fuzzyTriggers) {
            if (recognizedText.contains(fuzzyPhrase)) {
              print("Fuzzy trigger detected: $fuzzyPhrase in '$recognizedText'");
              _monitor.logVoiceTrigger(recognizedText, true);
              connectToRoom(); // initiate connection
              triggerFound = true;
              break;
            }
          }
        }
        
        if (!triggerFound && recognizedText.isNotEmpty) {
          _monitor.logVoiceTrigger(recognizedText, false);
        }
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
      cancelOnError: false,
    );

    isListening.value = true;
    _monitor.logPerformanceMetric('speech_listening_started', true);
  }

  Future<void> homeApi() async {
    _monitor.startTimer('home_api_initialization');
    agentStatus.value = Status.LOADING;
    
    try {
      await Future.wait([
        getCourseList(),
        userProfileApi(),
      ]).then((value) {
        livekitTokenApi();
        agentStatus.value = Status.COMPLETED;
        _monitor.endTimer('home_api_initialization');
        _monitor.logPerformanceMetric('home_api_success', true);
      }).onError((error, stackTrace) {
        agentStatus.value = Status.ERROR;
        errors.value = error.toString();
        _monitor.endTimer('home_api_initialization');
        _monitor.logError('home_api', 'Home API initialization failed', error, stackTrace);
      });
    } catch (error, stackTrace) {
      agentStatus.value = Status.ERROR;
      errors.value = error.toString();
      _monitor.endTimer('home_api_initialization');
      _monitor.logError('home_api', 'Unexpected error in home API', error, stackTrace);
    }
  }

  Future<void> livekitTokenApi() async {
    _monitor.startTimer('livekit_token_api');
    try {
      final courseDetails = courseList.value.result?.toJson() ?? {};
      courseDetails['current_time'] =
          DateTime.now().toLocal().toIso8601String();
      courseDetails['auth_token'] = await userPreferences.getToken();
      courseDetails['language'] = userProfile.value.result?.language;
      courseDetails['agent_conversation_choice'] =
          userProfile.value.result?.agentConservationChoice;
      var data = {
        "identity": userProfile.value.result?.email,
        "room": "room_${userProfile.value.result?.email}",
        "name": userProfile.value.result?.firstName,
        "course_details": courseDetails,
      };

      print("the data is $data");
      _monitor.logPerformanceMetric('livekit_token_request_data_size', data.toString().length);

      var value = await _homeRepository.livekitToken(data);
      print("the value is $value");
      
      final duration = _monitor.endTimer('livekit_token_api');
      _monitor.logPerformanceMetric('livekit_token_response_time', duration?.inMilliseconds ?? 0, 'ms');
      
      if (value['status'] == true) {
        token = value['result']['token'];
        _monitor.logPerformanceMetric('livekit_token_success', true);
        _monitor.logPerformanceMetric('livekit_token_length', token.length);
      } else {
        _monitor.logError('livekit_token', 'Failed to get LiveKit token', value["result"]["error"]);
        Util.Snack_Bar("Warning", value["result"]["error"]);
      }
    } catch (error) {
      errors.value = error.toString();
      _monitor.endTimer('livekit_token_api');
      _monitor.logError('livekit_token', 'Error getting LiveKit token', error);
      print('Error connecting: $error');
    }
  }

  Future<void> deleteLivekitRoomApi() async {
    try {
      var value = await _homeRepository.deleteLivekitRoom({
        "room": "room_${userProfile.value.result?.email}",
      });
      print("the value is $value");
      if (value['status'] == true) {
        Util.Snack_Bar("Success",
            "Your reports and feedback has been submitted successfully");
      } else {
        Util.Snack_Bar("Warning", "Something went wrong");
      }
    } catch (error) {
      errors.value = error.toString();
      print('Error connecting in deleteLivekitRoomApi: $error');
    }
  }

  Future<void> userProfileApi() async {
    try {
      var value = await _homeRepository.userProfile();
      if (value['status'] == true) {
        userProfile.value = UserProfile.fromJson(value);
      } else {
        Util.Snack_Bar("Warning", "Something went wrong");
      }
    } catch (error) {
      errors.value = error.toString();
      print('Error connecting in userProfileApi: $error');
    }
  }

  Future<void> getCourseList() async {
    // Course endpoint has been replaced with medical documents
    // Keeping this method for backward compatibility but it doesn't fetch courses anymore
    try {
      // Skip fetching courses as they've been replaced with medical documents
      print("Skipping getCourseList - courses replaced with medical documents");
      courseList.value = course_models.CourseList(status: true, result: course_models.Result());
    } catch (error) {
      errors.value = error.toString();
      print('Error in getCourseList: $error');
    }
  }

  Future<void> connectToRoom() async {
    // Prevent multiple connection attempts
    if (requestStatus.value == Status.LOADING) {
      print("Already connecting, please wait...");
      _monitor.logPerformanceMetric('connection_attempt_blocked', true);
      return;
    }
    
    _connectionStartTime = DateTime.now();
    _monitor.startTimer('livekit_connection');
    _monitor.logLiveKitEvent('connection_start', {
      'room': "room_${userProfile.value.result?.email}",
      'user': userProfile.value.result?.email,
    });
    
    requestStatus.value = Status.LOADING;
    hasTriggered.value = true;
    _speech.stop();
    
    // Always get a fresh token for new connections
    token = "";
    await livekitTokenApi();

    room = livekit.Room();
    final options = livekit.RoomOptions(
      adaptiveStream: true,
      dynacast: true,
      defaultAudioOutputOptions: livekit.AudioOutputOptions(
        speakerOn: true,
      ),
      defaultAudioCaptureOptions: livekit.AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
      ),
    );

    try {
      final url = "wss://kindura-u99yilqz.livekit.cloud";
      print("the url is $url");
      print("the token is $token");
      
      _monitor.startTimer('livekit_websocket_connection');

      await room.connect(url, token, roomOptions: options);
      
      final websocketDuration = _monitor.endTimer('livekit_websocket_connection');
      _monitor.logPerformanceMetric('websocket_connection_time', websocketDuration?.inMilliseconds ?? 0, 'ms');
      
      await room.localParticipant!.setMicrophoneEnabled(true);
      _monitor.logLiveKitEvent('microphone_enabled', {'enabled': true});

      // Ensure speaker is enabled for audio output
      await livekit.Hardware.instance.setSpeakerphoneOn(true);
      print("🔊 Speaker enabled for audio output");

      // Check for any existing remote participants and their tracks
      print("🔍 Checking for existing remote participants: ${room.remoteParticipants.length}");
      for (final participant in room.remoteParticipants.values) {
        print("👤 Found existing participant: ${participant.identity}");
        print("   - Audio tracks: ${participant.audioTrackPublications.length}");
        for (final trackPublication in participant.audioTrackPublications) {
          print("   - Track pub: subscribed=${trackPublication.subscribed}, enabled=${trackPublication.enabled}");
          if (trackPublication.track != null) {
            final audioTrack = trackPublication.track as livekit.AudioTrack;
            audioTrack.start();
            print("✅ Started existing audio track from ${participant.identity}");
          } else {
            // Try to subscribe if not already
            print("⚠️ Track is null, attempting to subscribe...");
          }
        }
      }

      // Subscribe to remote participant tracks (for audio from agent)
      room.createListener()
        ..on<livekit.TrackPublishedEvent>((event) {
          print("📢 Track PUBLISHED: ${event.publication.kind} from ${event.participant.identity}");
          print("   - Source: ${event.publication.source}");
          print("   - Subscribed: ${event.publication.subscribed}");
          print("   - SID: ${event.publication.sid}");
        })
        ..on<livekit.TrackSubscribedEvent>((event) {
          final now = DateTime.now();
          final connectionDelay = _connectionStartTime != null
            ? now.difference(_connectionStartTime!).inMilliseconds
            : 0;

          print("✅ Track SUBSCRIBED: ${event.track.kind} from ${event.participant.identity}");
          _monitor.logLiveKitEvent('track_subscribed', {
            'track_kind': event.track.kind.toString(),
            'participant_identity': event.participant.identity,
            'connection_delay_ms': connectionDelay,
          });

          if (event.track.kind == livekit.TrackType.AUDIO) {
            print("🔊 Audio track subscribed from agent!");
            _monitor.logPerformanceMetric('audio_track_ready_time', connectionDelay, 'ms');

            // Enable audio playback for agent voice
            final audioTrack = event.track as livekit.AudioTrack;
            audioTrack.start();
            print("🎵 Agent audio track started for playback");

            // Ensure speaker is on
            livekit.Hardware.instance.setSpeakerphoneOn(true);
            print("🔊 Speaker confirmed ON");
          }
        })
        ..on<livekit.TrackUnsubscribedEvent>((event) {
          print("❌ Track UNSUBSCRIBED: ${event.track.kind} from ${event.participant.identity}");
        })
        ..on<livekit.ParticipantConnectedEvent>((event) {
          final connectionDelay = _connectionStartTime != null 
            ? DateTime.now().difference(_connectionStartTime!).inMilliseconds 
            : 0;
            
          print("Participant connected: ${event.participant.identity}");
          _monitor.logLiveKitEvent('participant_connected', {
            'participant_identity': event.participant.identity,
            'connection_delay_ms': connectionDelay,
          });
        })
        ..on<livekit.TranscriptionEvent>((event) {
          final now = DateTime.now();
          final transcriptionDelay = _lastTranscriptionTime != null 
            ? now.difference(_lastTranscriptionTime!).inMilliseconds 
            : 0;
          _lastTranscriptionTime = now;
          
          for (final segment in event.segments) {
            print("New transcription from ${segment.id}: ${segment.text}");
            _monitor.logTranscription(
              segment.id,
              segment.text,
              'agent',
              true
            );
          }
          
          _monitor.logPerformanceMetric('transcription_interval', transcriptionDelay, 'ms');

          if (event.segments.isNotEmpty) {
            requestStatus.value = Status.COMPLETED;
          }
        })
        ..on<livekit.RoomDisconnectedEvent>((event) {
          _monitor.logLiveKitEvent('room_disconnected', {
            'reason': event.reason?.toString(),
          });
        });

      final totalConnectionTime = _monitor.endTimer('livekit_connection');
      
      isConnected.value = true;
      requestStatus.value = Status.COMPLETED;
      
      _monitor.logPerformanceMetric('total_connection_time', totalConnectionTime?.inMilliseconds ?? 0, 'ms');
      _monitor.logLiveKitEvent('connection_established', {
        'connection_time_ms': totalConnectionTime?.inMilliseconds,
        'websocket_url': url,
      });
      
      print("Successfully connected to LiveKit room");
    } catch (e) {
      final failedConnectionTime = _monitor.endTimer('livekit_connection');
      
      requestStatus.value = Status.ERROR;
      isConnected.value = false;
      token = "";
      
      _monitor.logError('livekit_connection', 'Failed to connect to LiveKit room', e);
      _monitor.logPerformanceMetric('failed_connection_time', failedConnectionTime?.inMilliseconds ?? 0, 'ms');
      
      print('Error connecting in connectToRoom: $e');
      Util.Snack_Bar("Connection Error", "Failed to connect. Please try again.");
    }
  }

  Future<void> logout() async {
    hasTriggered.value = true;
    _speech.stop();
    await userPreferences.removeUser();
    // Navigate first, then delete controllers
    Get.offAllNamed(RoutesName.splashScreen);
    Get.deleteAll();
  }

  void disconnect() async {
    _monitor.startTimer('livekit_disconnect');
    try {
      requestStatus.value = Status.LOADING;
      
      // Disconnect from room first
      if (room.connectionState != livekit.ConnectionState.disconnected) {
        _monitor.logLiveKitEvent('disconnection_start', {
          'connection_state': room.connectionState.toString(),
        });
        
        room.disconnect();
        _monitor.logLiveKitEvent('room_disconnected_locally', {});
        print("Disconnected from LiveKit room");
      }
      
      // Then delete the room on server
      await deleteLivekitRoomApi();
      
      // Reset all connection state
      token = "";
      isConnected.value = false;
      hasTriggered.value = false;
      _connectionStartTime = null;
      _lastTranscriptionTime = null;
      
      // Restart speech recognition for voice triggers
      _initSpeechRecognition();

      // Refresh medication data after voice session (agent may have updated dose events)
      print("🔄 Refreshing medication data after voice session...");
      _loadMedications();

      final disconnectDuration = _monitor.endTimer('livekit_disconnect');
      _monitor.logPerformanceMetric('disconnect_time', disconnectDuration?.inMilliseconds ?? 0, 'ms');

      requestStatus.value = Status.COMPLETED;
      print("Cleanup completed, ready for new connection");
    } catch (e) {
      final failedDisconnectTime = _monitor.endTimer('livekit_disconnect');
      _monitor.logError('livekit_disconnect', 'Error during disconnect', e);
      _monitor.logPerformanceMetric('failed_disconnect_time', failedDisconnectTime?.inMilliseconds ?? 0, 'ms');
      
      print("Error during disconnect: $e");
      // Force reset state even on error
      isConnected.value = false;
      token = "";
      requestStatus.value = Status.ERROR;
    }
  }

  // Get performance report for debugging
  Map<String, dynamic> getPerformanceReport() {
    return _monitor.getPerformanceSummary();
  }

  // Get recent logs for debugging
  List<Map<String, dynamic>> getRecentLogs([int limit = 50]) {
    return _monitor.getRecentLogs(limit);
  }

  // Export all logs as JSON string
  String exportPerformanceLogs() {
    return _monitor.exportLogs();
  }

  // Start performance monitoring
  void startPerformanceMonitoring() {
    _monitor.setEnabled(true);
    print('🚀 Performance monitoring started');
    Util.Snack_Bar("Debug", "Performance monitoring started");
  }

  // Stop performance monitoring
  void stopPerformanceMonitoring() {
    _monitor.setEnabled(false);
    print('⏹️ Performance monitoring stopped');
    Util.Snack_Bar("Debug", "Performance monitoring stopped");
  }

  // Toggle performance monitoring
  void togglePerformanceMonitoring() {
    if (_monitor.isEnabled) {
      stopPerformanceMonitoring();
    } else {
      startPerformanceMonitoring();
    }
  }

  // Show debug widget
  void showDebugWidget() {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header with controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Performance Monitor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Toggle button
                  ElevatedButton(
                    onPressed: togglePerformanceMonitoring,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _monitor.isEnabled ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_monitor.isEnabled ? 'Stop' : 'Start'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Performance summary
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _monitor.isEnabled ? Icons.play_circle : Icons.pause_circle,
                        color: _monitor.isEnabled ? Colors.green : Colors.red,
                      ),
                      title: Text('Monitoring: ${_monitor.isEnabled ? 'Active' : 'Stopped'}'),
                      subtitle: Text('Total logs: ${_monitor.getRecentLogs().length}'),
                    ),
                  ),
                  ...getPerformanceReport().entries.map((entry) {
                    return Card(
                      child: ListTile(
                        title: Text(entry.key.toString().replaceAll('_', ' ').toUpperCase()),
                        trailing: Text(
                          entry.value.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Get.back();
                      // Import the performance debug widget
                      Get.bottomSheet(
                        const Scaffold(
                          body: Center(
                            child: Text('Full Debug Widget - Import performance_debug_widget.dart'),
                          ),
                        ),
                        isScrollControlled: true,
                      );
                    },
                    child: const Text('Open Full Debug Widget'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
      isDismissible: true,
    );
  }

  @override
  void onClose() {
    _speech.stop();
    _watchVitalsChannel?.sink.close();
    _watchVitalsService.dispose();
    super.onClose();
  }
}
