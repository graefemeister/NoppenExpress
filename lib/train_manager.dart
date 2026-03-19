import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'train_core.dart'; 

class TrainManager {
  static const String _storageKey = 'lokleiter_trains';

  static Future<void> saveTrains(List<TrainController> controllers) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> data = controllers.map((c) => c.config.toMap()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  static Future<List<TrainController>> loadTrains() async {
    final prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    return loadTrainsFromContent(jsonString);
  }

  static List<TrainController> loadTrainsFromContent(String jsonString) {
    try {
      List<dynamic> jsonData = jsonDecode(jsonString);
      List<TrainController> list = [];
      for (var item in jsonData) {
        TrainConfig config = TrainConfig.fromMap(item);
        if (config.protocol == 'lego_hub') {
          list.add(LegoHubController(config));
        } else if (config.protocol == 'circuit_cube') {
          list.add(CircuitCubeController(config));
        } else {
          // Standardfall für alle anderen Mould King Hubs
          list.add(MouldKingController(config));
        }
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  static Future<String> exportAsJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey) ?? "[]";
  }
}