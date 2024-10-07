class SatelliteData {
  final String type;
  final int sgnID;
  final double lit;
  final int q;

  SatelliteData({
    required this.type,
    required this.sgnID,
    required this.lit,
    required this.q,
  });

  @override
  String toString() {
    return 'type: $type, sgnID: $sgnID, lit: $lit, q: $q';
  }
}

class SatelliteQueue {
  final Map<String, Map<int, SatelliteData>> satelliteDataMap = {};
  double currentTime = 0.0;

  void addData(double time, List<SatelliteData> data) {
    // Проверяем, является ли время нового пакета более актуальным
    if (time > currentTime) {
      currentTime = time;
      satelliteDataMap.clear(); // Очищаем данные только при получении более актуального пакета
    }

    // Добавляем или обновляем данные для текущего времени
    for (var satellite in data) {
      if (!satelliteDataMap.containsKey(satellite.type)) {
        satelliteDataMap[satellite.type] = {};
      }
      // Уникально идентифицируем спутник по его идентификатору sgnID
      satelliteDataMap[satellite.type]![satellite.sgnID] = satellite;
    }
  }

  Map<String, List<SatelliteData>> getLatestData() {
    // Преобразуем внутреннюю карту в список для каждого типа спутников
    return satelliteDataMap.map((type, satMap) => MapEntry(type, satMap.values.toList()));
  }
}

List<SatelliteData> filterF5packetData(List<String> dataList) {
  List<SatelliteData> satelliteDataList = [];

  for (String data in dataList) {
    if (data.contains('type') && data.contains('sgnID') && data.contains('lit') && data.contains('q')) {
      // Извлечение данных
      RegExp regExp = RegExp(r'type: (\w+), sgnID: (\d+), lit: ([\-]?\d+), q: (\d+)');
      Match? match = regExp.firstMatch(data);

      if (match != null) {
        satelliteDataList.add(SatelliteData(
          type: match.group(1)!,
          sgnID: int.parse(match.group(2)!),
          lit: double.parse(match.group(3)!),
          q: int.parse(match.group(4)!),
        ));
      }
    }
  }

  return satelliteDataList;
}

Map<String, int> countSatellites(Map<String, List<SatelliteData>> satelliteDataMap) {
  int gpsCount = 0;
  int gpsL2Count = 0;
  int gpsL5Count = 0;
  int glnCount = 0;
  int glnL2Count = 0;
  int galCount = 0;
  int galL5aCount = 0;
  int galL5bCount = 0;
  int bdsCount = 0;
  int bdsL2Count = 0;

  satelliteDataMap.forEach((type, dataList) {
    if (type == 'GpsL1CA') {
      gpsCount = dataList.length;
    } else if (type == 'GpsL2CM') {
      gpsL2Count = dataList.length;
    } else if (type == 'GpsL5I') {
      gpsL5Count = dataList.length;
    } else if (type == 'GlnL1OF') {
      glnCount = dataList.length;
    } else if (type == 'GlnL2OF') {
      glnL2Count = dataList.length;
    } else if (type == 'GalE1B') {
      galCount = dataList.length;
    } else if (type == 'GalE5aI') {
      galL5aCount = dataList.length;
    } else if (type == 'GalE5bI') {
      galL5bCount = dataList.length;
    } else if (type == 'BdsB1I') {
      bdsCount = dataList.length;
    } else if (type == 'BdsB2I') {
      bdsL2Count = dataList.length;
    }
  });

  int totalSatellites = gpsCount + gpsL2Count + gpsL5Count + glnCount + glnL2Count + galCount + galL5aCount + galL5bCount + bdsCount + bdsL2Count;

  return {
    'GPS': gpsCount,
    'GPSL2': gpsL2Count,
    'GPSL5': gpsL5Count,
    'GLN': glnCount,
    'GLNL2': glnL2Count,
    'GAL': galCount,
    'GALL5a': galL5aCount,
    'GALL5b': galL5bCount,
    'BDS': bdsCount,
    'BDSL2': bdsL2Count,
    'TOTAL': totalSatellites,
  };
}

Future<List<Map<String, String>>> processF5PacketData(List<String> rawData) async {
  List<SatelliteData> packetDataList = filterF5packetData(rawData);

  Map<int, SatelliteData> gpsSatellites = {};
  Map<int, SatelliteData> gpsL2Satellites = {};
  Map<int, SatelliteData> gpsL5Satellites = {};
  Map<int, SatelliteData> glnSatellites = {};
  Map<int, SatelliteData> glnL2Satellites = {};
  Map<int, SatelliteData> galSatellites = {};
  Map<int, SatelliteData> galL5aSatellites = {};
  Map<int, SatelliteData> galL5bSatellites = {};
  Map<int, SatelliteData> bdsSatellites = {};
  Map<int, SatelliteData> bdsL2Satellites = {};

  Set<int> currentGpsSatellites = {};
  Set<int> currentL2GpsSatellites = {};
  Set<int> currentL5GpsSatellites = {};
  Set<int> currentGlnSatellites = {};
  Set<int> currentL2GlnSatellites = {};
  Set<int> currentGalSatellites = {};
  Set<int> currentL5aGalSatellites = {};
  Set<int> currentL5bGalSatellites = {};
  Set<int> currentBdsSatellites = {};
  Set<int> currentL2BdsSatellites = {};

  for (var packet in packetDataList) {
    switch (packet.type) {
      case 'GpsL1CA':
        gpsSatellites[packet.sgnID] = packet;
        currentGpsSatellites.add(packet.sgnID);
        break;
      case 'GpsL2CM':
        gpsL2Satellites[packet.sgnID] = packet;
        currentL2GpsSatellites.add(packet.sgnID);
        break;
      case 'GpsL5I':
        gpsL5Satellites[packet.sgnID] = packet;
        currentL5GpsSatellites.add(packet.sgnID);
        break;
      case 'GlnL1OF':
        glnSatellites[packet.sgnID] = packet;
        currentGlnSatellites.add(packet.sgnID);
        break;
      case 'GlnL2OF':
        glnL2Satellites[packet.sgnID] = packet;
        currentL2GlnSatellites.add(packet.sgnID);
        break;
      case 'GalE1B':
        galSatellites[packet.sgnID] = packet;
        currentGalSatellites.add(packet.sgnID);
        break;
      case 'GalE5aI':
        galL5aSatellites[packet.sgnID] = packet;
        currentL5aGalSatellites.add(packet.sgnID);
        break;
      case 'GalE5bI':
        galL5bSatellites[packet.sgnID] = packet;
        currentL5bGalSatellites.add(packet.sgnID);
        break;
      case 'BdsB1I':
        bdsSatellites[packet.sgnID] = packet;
        currentBdsSatellites.add(packet.sgnID);
        break;
      case 'BdsB2I':
        bdsL2Satellites[packet.sgnID] = packet;
        currentL2BdsSatellites.add(packet.sgnID);
        break;
    }
  }

  // Удаляем спутники без обновлений
  gpsSatellites.removeWhere((satID, _) => !currentGpsSatellites.contains(satID));
  gpsL2Satellites.removeWhere((satID, _) => !currentL2GpsSatellites.contains(satID));
  gpsL5Satellites.removeWhere((satID, _) => !currentL5GpsSatellites.contains(satID));
  glnSatellites.removeWhere((satID, _) => !currentGlnSatellites.contains(satID));
  glnL2Satellites.removeWhere((satID, _) => !currentL2GlnSatellites.contains(satID));
  galSatellites.removeWhere((satID, _) => !currentGalSatellites.contains(satID));
  galL5aSatellites.removeWhere((satID, _) => !currentL5aGalSatellites.contains(satID));
  galL5bSatellites.removeWhere((satID, _) => !currentL5bGalSatellites.contains(satID));
  bdsSatellites.removeWhere((satID, _) => !currentBdsSatellites.contains(satID));
  bdsL2Satellites.removeWhere((satID, _) => !currentL2BdsSatellites.contains(satID));

  // Подготовка данных для histogramm
  List<Map<String, String>> result = [];

  // Добавляем данные для каждой системы
  gpsSatellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  gpsL2Satellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  gpsL5Satellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  glnSatellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  glnL2Satellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  galSatellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  galL5aSatellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  galL5bSatellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  bdsSatellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  bdsL2Satellites.values.forEach((packet) {
    result.add({
      'Навигационный сигнал': packet.type.toString(),
      'Номер НКА': packet.sgnID.toString(),
      'ОСШ': packet.q.toString(),
    });
  });

  return result;
}
