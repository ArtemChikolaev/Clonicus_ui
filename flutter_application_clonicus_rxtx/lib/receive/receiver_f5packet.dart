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
    return 'Type: $type, sgnID: $sgnID, lit: $lit, q: $q';
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
    if (data.contains('GlnL1OF') || data.contains('GpsL1CA') || data.contains('GalE1B') || data.contains('BdsB1I')) {
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
