
class SmartSwitchProfile {
  static String mainService = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static String relayChar = "0000ffe1-0000-1000-8000-00805f9b34fb";

  static List<int> relayCommand(int id, bool status) {
    /*
    Byte 1 = Sync/Header = A0 (hexadecimal) = 160 (decimal)
    Byte 2 = Relay Number : 01 = first relay, 02 = second relay (and etc for > 2 relays, presumably)
    Byte 3 = Relay State : 00 = off, 01 = on
    Byte 4 = Checksum = sum of preceding bytes (eg, Channel 2 OFF = A0 + 02 + 00 = A2)
    */
    int sync = 0xA0;
    int statInt = status ? 0x01 : 0x00;
    int checksum = sync + id + statInt;
    return [sync, id, statInt, checksum];
  }
}

main() {
  SmartSwitchProfile.relayCommand(1, true);
}
