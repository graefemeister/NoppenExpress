import 'dart:isolate'; 
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundService {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'train_station_channel',
        channelName: 'Zug-Zentrale Hintergrunddienst',
        channelDescription: 'Hält die Verbindung zu Zügen und Fernbedienung stabil.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyBackgroundTaskHandler());
}

class MyBackgroundTaskHandler extends TaskHandler {
  // TaskStarter wurde in neueren Versionen entfernt/geändert
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    print("🚀 Hintergrund-Task gestartet");
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // Intervall-Event
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {
    print("🛑 Hintergrund-Task beendet");
  }
}