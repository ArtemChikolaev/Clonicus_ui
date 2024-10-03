class FiftyFivePacketData {
  final String navSysType;
  final int satID;
  final double elevation;
  final double azimuth;

  FiftyFivePacketData({required this.navSysType, required this.satID, required this.elevation, required this.azimuth});

  @override
  String toString() {
    return 'Type: $navSysType, SatID: $satID, El: $elevation, Az: $azimuth';
  }
}

List<FiftyFivePacketData> filterFiftyFivePacketData(List<String> dataList) {
  List<FiftyFivePacketData> fiftyFivePacketDataList = [];

  for (String data in dataList) {
    // Проверяем, содержит ли строка ключевые слова для 55 пакета
    if (data.contains('Type') && data.contains('SatID') && data.contains('El') && data.contains('Az')) {
      try {
        RegExp regExp = RegExp(r'Type: (\w+), SatID: (\d+), El: ([\d\.]+), Az: ([\d\.]+)');
        Match? match = regExp.firstMatch(data);

        if (match != null) {
          fiftyFivePacketDataList.add(FiftyFivePacketData(
            navSysType: match.group(1)!,
            satID: int.parse(match.group(2)!),
            elevation: double.parse(match.group(3)!),
            azimuth: double.parse(match.group(4)!),
          ));
        }
      } catch (e) {
        // print('Ошибка декодирования данных 55 пакета: $e');
      }
    }
  }

  return fiftyFivePacketDataList;
}

Future<List<String>> processFiftyFivePacketData(List<String> rawData) async {
  List<FiftyFivePacketData> packetDataList = filterFiftyFivePacketData(rawData);

  // Хранилища данных для каждой навигационной системы с мапингом по satID
  Map<int, FiftyFivePacketData> gpsSatellites = {};
  Map<int, FiftyFivePacketData> glnSatellites = {};
  Map<int, FiftyFivePacketData> galSatellites = {};
  Map<int, FiftyFivePacketData> bdsSatellites = {};

  // Наборы актуальных спутников, чтобы отслеживать обновления
  Set<int> currentGpsSatellites = {};
  Set<int> currentGlnSatellites = {};
  Set<int> currentGalSatellites = {};
  Set<int> currentBdsSatellites = {};

  // Обрабатываем данные из пакета
  for (var packet in packetDataList) {
    switch (packet.navSysType) {
      case 'GPS':
        gpsSatellites[packet.satID] = packet; // Обновляем или добавляем спутник
        currentGpsSatellites.add(packet.satID); // Добавляем в текущий набор
        break;
      case 'GLN':
        glnSatellites[packet.satID] = packet;
        currentGlnSatellites.add(packet.satID);
        break;
      case 'GAL':
        galSatellites[packet.satID] = packet;
        currentGalSatellites.add(packet.satID);
        break;
      case 'BDS':
        bdsSatellites[packet.satID] = packet;
        currentBdsSatellites.add(packet.satID);
        break;
    }
  }

  // Удаляем спутники, данные по которым не пришли (если их нет в текущем наборе)
  gpsSatellites.removeWhere((satID, _) => !currentGpsSatellites.contains(satID));
  glnSatellites.removeWhere((satID, _) => !currentGlnSatellites.contains(satID));
  galSatellites.removeWhere((satID, _) => !currentGalSatellites.contains(satID));
  bdsSatellites.removeWhere((satID, _) => !currentBdsSatellites.contains(satID));

  // Список строк для возврата
  List<String> result = [];

  // Формируем строки для каждой системы и добавляем их в список
  result.add('GPS Satellites:');
  gpsSatellites.values.forEach((packet) {
    result.add(packet.toString());
  });

  result.add('GLN Satellites:');
  glnSatellites.values.forEach((packet) {
    result.add(packet.toString());
  });

  result.add('GAL Satellites:');
  galSatellites.values.forEach((packet) {
    result.add(packet.toString());
  });

  result.add('BDS Satellites:');
  bdsSatellites.values.forEach((packet) {
    result.add(packet.toString());
  });

  // Возвращаем список строк как Future
  return result;
}
