/// Mould King Broadcast (4.0/6.0) Protocol Implementation
/// Based on the reverse engineering work by J0EK3R (Ivan Murvai)
import 'dart:typed_data';

class MouldKing40Protocol {
  static const List<int> _WA = [141, 210, 87, 161, 61, 167, 102, 176, 117, 49, 17, 72, 150, 119, 248, 227, 70, 233, 171, 208, 158, 83, 51, 216, 186, 152, 8, 36, 203, 59, 252, 113, 163, 244, 85];
  static const List<int> _WB = [199, 141, 210, 87, 161, 61, 167, 102, 176, 117, 49, 17, 72, 150, 119, 248, 227];
  static const List<int> _ADDR = [193, 194, 195, 196, 197];

  static int _reverseByte(int b) {
    int r = 0;
    for (int i = 0; i < 8; i++) { if ((b & (1 << i)) != 0) r |= (1 << (7 - i)); }
    return r & 0xFF;
  }

  static int _calcCrc16(List<int> cmd) {
    int crc = 0xFFFF;
    for (var b in _ADDR.reversed) {
      crc ^= (b << 8);
      for (int i = 0; i < 8; i++) crc = (crc & 0x8000 != 0) ? (crc << 1) ^ 0x11021 : (crc << 1);
    }
    for (var v in cmd) {
      crc ^= (_reverseByte(v) << 8);
      for (int i = 0; i < 8; i++) crc = (crc & 0x8000 != 0) ? (crc << 1) ^ 0x11021 : (crc << 1);
    }
    int res = 0;
    crc &= 0xFFFF;
    for (int i = 0; i < 16; i++) { if ((1 << i) & crc != 0) res |= (1 << (15 - i)); }
    return res ^ 0xFFFF;
  }

  static Uint8List _encrypt(List<int> commandData) {
    final int totalLength = 8 + commandData.length + 2;
    final List<int> data = List.filled(totalLength, 0);

    data[0] = _reverseByte(0x71); 
    data[1] = _reverseByte(0x0F); 
    data[2] = _reverseByte(0x55);
    for (int i = 0; i < 5; i++) data[3 + i] = _reverseByte(_ADDR[4 - i]);
    for (int i = 0; i < commandData.length; i++) data[8 + i] = commandData[i];
    
    final int crc = _calcCrc16(commandData);
    data[totalLength - 2] = crc & 0xFF;
    data[totalLength - 1] = (crc >> 8) & 0xFF;
    
    for (int i = 0; i < (totalLength - 3); i++) { data[3 + i] ^= _WB[i]; }
    for (int i = 0; i < totalLength; i++) { data[i] ^= _WA[i + 15]; }
    
    return Uint8List.fromList(data);
  }

  static int _scale(int speed) {
    if (speed.abs() < 5) return 0;
    // 0-100 auf 1-7 skalieren
    int val = (speed.abs() * 7 / 100).round().clamp(1, 7);
    // Bit 4 (Wert 8) ist das Richtungsflag
    return (speed > 0) ? val : (val + 8);
  }

  // --- PUBLIC API ---

  static Uint8List getHandshake() => _encrypt([173, 196, 189, 128, 128, 128, 0, 82]);

  /// Erzeugt das Fahr-Paket für 4 Ports (A, B, C, D)
  static Uint8List getDrive(int pA, int pB, int pC, int pD) {
    return _encrypt([
      125, 196, 189, 
      (_scale(pA) << 4) | (_scale(pB) & 0x0F), // Byte 3: Port A & B
      (_scale(pC) << 4) | (_scale(pD) & 0x0F), // Byte 4: Port C & D
      0, 0, 0, 0, 130
    ]);
  }

  /// Erzeugt das Unified-Fahr-Paket für Kanal 1, 2 und 3 gleichzeitig
  static Uint8List getUnifiedDrive(List<int> ch1, List<int> ch2, List<int> ch3) {
    // ch[0] = pA, ch[1] = pB, ch[2] = pC, ch[3] = pD
    
    // Kanal 1 berechnen
    int ch1_ab = (_scale(ch1[0]) << 4) | (_scale(ch1[1]) & 0x0F);
    int ch1_cd = (_scale(ch1[2]) << 4) | (_scale(ch1[3]) & 0x0F);
    
    // Kanal 2 berechnen
    int ch2_ab = (_scale(ch2[0]) << 4) | (_scale(ch2[1]) & 0x0F);
    int ch2_cd = (_scale(ch2[2]) << 4) | (_scale(ch2[3]) & 0x0F);
    
    // Kanal 3 berechnen
    int ch3_ab = (_scale(ch3[0]) << 4) | (_scale(ch3[1]) & 0x0F);
    int ch3_cd = (_scale(ch3[2]) << 4) | (_scale(ch3[3]) & 0x0F);

    // Alles zusammen in die bestehende Verschlüsselung werfen!
    return _encrypt([
      125, 196, 189, 
      ch1_ab, ch1_cd, 
      ch2_ab, ch2_cd, 
      ch3_ab, ch3_cd, 
      130
    ]);
  }
}