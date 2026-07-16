import 'dart:typed_data';

class MouldKingRwyProtocol {
  
  static List<int> _hexToBytes(String hex) {
    hex = hex.replaceAll(" ", "").trim();
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  // Handshake für diese spezifische Golden Session
  static Uint8List getHandshake() {
    return Uint8List.fromList(_hexToBytes("6db643cf7e8f47114fa9c9b851fa2ae101e6131415161718"));
  }

  // Das ultimative hochauflösende Ramping (45 Stufen Vorwärts, 32 Stufen Rückwärts)
  static Uint8List getDrive(int power) {
    
    if (power == 0) {
      // STOP
      return Uint8List.fromList(_hexToBytes("6db643cf7e8f471183a9c938d17aaa2d0b58131415161718"));
    }

    if (power > 0) {
      // 45 feinste Zwischenstufen für VORWÄRTS
      const List<String> fwdSteps = [
        "6db643cf7e8f471183a9c9382f7aaa2d6281131415161718",
        "6db643cf7e8f471183a9c9382a7aaa2d35ef131415161718",
        "6db643cf7e8f471183a9c9382b7aaa2d8ef3131415161718",
        "6db643cf7e8f471183a9c938277aaa2dba64131415161718",
        "6db643cf7e8f471183a9c938237aaa2d5616131415161718",
        "6db643cf7e8f471183a9c9383d7aaa2db57b131415161718",
        "6db643cf7e8f471183a9c9383a7aaa2d942c131415161718",
        "6db643cf7e8f471183a9c9383b7aaa2d2f30131415161718",
        "6db643cf7e8f471183a9c938347aaa2dd682131415161718",
        "6db643cf7e8f471183a9c938357aaa2d6d9e131415161718",
        "6db643cf7e8f471183a9c9380d7aaa2d4737131415161718",
        "6db643cf7e8f471183a9c938097aaa2dab45131415161718",
        "6db643cf7e8f471183a9c938077aaa2de9eb131415161718",
        "6db643cf7e8f471183a9c938037aaa2d0599131415161718",
        "6db643cf7e8f471183a9c938017aaa2d73a0131415161718",
        "6db643cf7e8f471183a9c9381c7aaa2d5de8131415161718",
        "6db643cf7e8f471183a9c9381a7aaa2dc7a3131415161718",
        "6db643cf7e8f471183a9c938177aaa2d4828131415161718",
        "6db643cf7e8f471183a9c938147aaa2d850d131415161718",
        "6db643cf7e8f471183a9c9386e7aaa2d6e8b131415161718",
        "6db643cf7e8f471183a9c9386d7aaa2da3ae131415161718",
        "6db643cf7e8f471183a9c9386a7aaa2d82f9131415161718",
        "6db643cf7e8f471183a9c938677aaa2d0d72131415161718",
        "6db643cf7e8f471183a9c938617aaa2d9739131415161718",
        "6db643cf7e8f471183a9c9387e7aaa2dcf48131415161718",
        "6db643cf7e8f471183a9c9387c7aaa2db971131415161718",
        "6db643cf7e8f471183a9c938787aaa2d5503131415161718",
        "6db643cf7e8f471183a9c938767aaa2d17ad131415161718",
        "6db643cf7e8f471183a9c938757aaa2dda88131415161718",
        "6db643cf7e8f471183a9c938707aaa2d8de6131415161718",
        "6db643cf7e8f471183a9c938717aaa2d36fa131415161718",
        "6db643cf7e8f471183a9c9384f7aaa2d8618131415161718",
        "6db643cf7e8f471183a9c9384c7aaa2d4b3d131415161718",
        "6db643cf7e8f471183a9c9384d7aaa2df021131415161718",
        "6db643cf7e8f471183a9c9384b7aaa2d6a6a131415161718",
        "6db643cf7e8f471183a9c938497aaa2d1c53131415161718",
        "6db643cf7e8f471183a9c938477aaa2d5efd131415161718",
        "6db643cf7e8f471183a9c938457aaa2d28c4131415161718",
        "6db643cf7e8f471183a9c938437aaa2db28f131415161718",
        "6db643cf7e8f471183a9c938407aaa2d7faa131415161718",
        "6db643cf7e8f471183a9c938567aaa2d4422131415161718",
        "6db643cf7e8f471183a9c938547aaa2d321b131415161718",
        "6db643cf7e8f471183a9c938527aaa2da850131415161718",
        "6db643cf7e8f471183a9c938537aaa2d134c131415161718",
        "6db643cf7e8f471183a9c938517aaa2d6575131415161718", // 100% Vorwärts
      ];
      
      // Lineares Mapping von [1 bis 100] auf Array-Index [0 bis 44]
      int index = ((power / 100.0) * (fwdSteps.length - 1)).round();
      index = index.clamp(0, fwdSteps.length - 1);
      return Uint8List.fromList(_hexToBytes(fwdSteps[index]));
      
    } else {
      // 32 feinste Zwischenstufen für RÜCKWÄRTS
      const List<String> bwdSteps = [
        "6db643cf7e8f471183a9c938d07aaa2db044131415161718",
        "6db643cf7e8f471183a9c938d47aaa2d5c36131415161718",
        "6db643cf7e8f471183a9c938d87aaa2d68a1131415161718",
        "6db643cf7e8f471183a9c938c17aaa2daa9b131415161718",
        "6db643cf7e8f471183a9c938c57aaa2d46e9131415161718",
        "6db643cf7e8f471183a9c938ca7aaa2dbf5b131415161718",
        "6db643cf7e8f471183a9c938ff7aaa2d1a79131415161718",
        "6db643cf7e8f471183a9c938ed7aaa2dcd83131415161718",
        "6db643cf7e8f471183a9c938ec7aaa2d769f131415161718",
        "6db643cf7e8f471183a9c938ef7aaa2dbbba131415161718",
        "6db643cf7e8f471183a9c938917aaa2dbc4e131415161718",
        "6db643cf7e8f471183a9c938907aaa2d0752131415161718",
        "6db643cf7e8f471183a9c938937aaa2dca77131415161718",
        "6db643cf7e8f471183a9c938957aaa2d503c131415161718",
        "6db643cf7e8f471183a9c938987aaa2ddfb7131415161718",
        "6db643cf7e8f471183a9c9389d7aaa2d88d9131415161718",
        "6db643cf7e8f471183a9c9389c7aaa2d33c5131415161718",
        "6db643cf7e8f471183a9c9389e7aaa2d45fc131415161718",
        "6db643cf7e8f471183a9c938867aaa2d3cda131415161718",
        "6db643cf7e8f471183a9c9388a7aaa2d084d131415161718",
        "6db643cf7e8f471183a9c938b37aaa2d99f8131415161718",
        "6db643cf7e8f471183a9c938b27aaa2d22e4131415161718",
        "6db643cf7e8f471183a9c938b57aaa2d03b3131415161718",
        "6db643cf7e8f471183a9c938b67aaa2dce96131415161718",
        "6db643cf7e8f471183a9c938bc7aaa2d604a131415161718",
        "6db643cf7e8f471183a9c938bf7aaa2dad6f131415161718",
        "6db643cf7e8f471183a9c938be7aaa2d1673131415161718",
        "6db643cf7e8f471183a9c938a07aaa2df51e131415161718",
        "6db643cf7e8f471183a9c938a87aaa2d2dfb131415161718",
        "6db643cf7e8f471183a9c938ab7aaa2de0de131415161718",
        "6db643cf7e8f471183a9c938ac7aaa2dc189131415161718",
        "6db643cf7e8f471183a9c938ae7aaa2db7b0131415161718", // 100% Rückwärts
      ];
      
      // Lineares Mapping von [1 bis 100] auf Array-Index [0 bis 31]
      int index = ((power.abs() / 100.0) * (bwdSteps.length - 1)).round();
      index = index.clamp(0, bwdSteps.length - 1);
      return Uint8List.fromList(_hexToBytes(bwdSteps[index]));
    }
  }
}