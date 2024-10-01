import 'dart:collection';
import 'package:latlong2/latlong.dart';

class FiftyPacketData {
  final int wn;
  final double tow;
  final String navSys;
  final int status; // Добавляем параметр status
  final double latitude;
  final double longitude;
  final double height;
  final double vx;
  final double vy;
  final double vz;
  final double absV;
  final double rms;
  final double pdop;

  FiftyPacketData({
    required this.wn,
    required this.tow,
    required this.navSys,
    required this.status, // Передаем параметр status
    required this.latitude,
    required this.longitude,
    required this.height,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.absV,
    required this.rms,
    required this.pdop,
  });

  @override
  String toString() {
    return 'WN: $wn, TOW: $tow, NavSys: $navSys, Latitude: $latitude, Longitude: $longitude, Height: $height, AbsV: $absV, Status: $status';
  }
}

List<FiftyPacketData> filterFiftyPacketData(List<String> dataList) {
  List<FiftyPacketData> fiftyPacketDataList = [];

  for (String data in dataList) {
    // Проверяем, содержит ли строка ключевые слова для 50 пакета
    if (data.contains('WN') && data.contains('NavSys') && data.contains('Latitude') && data.contains('Longitude')) {
      try {
        RegExp regExp = RegExp(r'WN: (\d+), TOW: ([\d\.]+), NavSys: (\w+), Status: (\d+), Latitude: ([\d\.\-]+), Longitude: ([\d\.\-]+), Height: ([\d\.]+), Vx: ([\d\.\-]+), Vy: ([\d\.\-]+), Vz: ([\d\.\-]+), AbsV: ([\d\.]+), RMS: ([\d\.]+), PDOP: ([\d\.]+)');
        Match? match = regExp.firstMatch(data);

        if (match != null) {
          fiftyPacketDataList.add(FiftyPacketData(
            wn: int.parse(match.group(1)!),
            tow: double.parse(match.group(2)!),
            navSys: match.group(3)!,
            status: int.parse(match.group(4)!), // Добавляем парсинг статуса
            latitude: double.parse(match.group(5)!),
            longitude: double.parse(match.group(6)!),
            height: double.parse(match.group(7)!),
            vx: double.parse(match.group(8)!),
            vy: double.parse(match.group(9)!),
            vz: double.parse(match.group(10)!),
            absV: double.parse(match.group(11)!),
            rms: double.parse(match.group(12)!),
            pdop: double.parse(match.group(13)!),
          ));
        }
      } catch (e) {
        print('Ошибка декодирования данных 50 пакета: $e');
      }
    }
  }

  return fiftyPacketDataList;
}

Future<Map<String, String>> readLastCoordinates(List<String> rawData) async {
  List<FiftyPacketData> packetDataList = filterFiftyPacketData(rawData);

  bool showAllPoints = false; // сначала не показывать

  final Queue<LatLng> recentLocationsGPS = Queue();
  final Queue<LatLng> allPointsGPS = Queue();
  final List<double> latitudesGPS = [];
  final List<double> longitudesGPS = [];
  final List<double> heightsGPS = [];
  final List<double> skoGPS = [];
  final List<double> pdopGPS = [];

  final Queue<LatLng> recentLocationsGLN = Queue();
  final Queue<LatLng> allPointsGLN = Queue();
  final List<double> latitudesGLN = [];
  final List<double> longitudesGLN = [];
  final List<double> heightsGLN = [];
  final List<double> skoGLN = [];
  final List<double> pdopGLN = [];

  final Queue<LatLng> recentLocationsGAL = Queue();
  final Queue<LatLng> allPointsGAL = Queue();
  final List<double> latitudesGAL = [];
  final List<double> longitudesGAL = [];
  final List<double> heightsGAL = [];
  final List<double> skoGAL = [];
  final List<double> pdopGAL = [];

  final Queue<LatLng> recentLocationsBDS = Queue();
  final Queue<LatLng> allPointsBDS = Queue();
  final List<double> latitudesBDS = [];
  final List<double> longitudesBDS = [];
  final List<double> heightsBDS = [];
  final List<double> skoBDS = [];
  final List<double> pdopBDS = [];

  // Храним последние координаты для каждой навигационной системы
  Map<String, String> lastCoordinates = {
    'GPS': '',
    'GLN': '',
    'GAL': '',
    'BDS': ''
  };

  // Проходим по каждому объекту класса FiftyPacketData
  for (var packet in packetDataList) {
    LatLng location = LatLng(packet.latitude, packet.longitude);

    switch (packet.navSys) {
      case 'GPS':
        _processNavSystemData(
          recentLocationsGPS,
          latitudesGPS,
          longitudesGPS,
          heightsGPS,
          skoGPS,
          pdopGPS,
          location,
          packet.latitude,
          packet.longitude,
          packet.height,
          packet.absV,
          packet.rms,
          packet.pdop,
          'GPS',
          lastCoordinates,
          showAllPoints,
          allPointsGPS,
        );
        break;
      case 'GLN':
        _processNavSystemData(
          recentLocationsGLN,
          latitudesGLN,
          longitudesGLN,
          heightsGLN,
          skoGLN,
          pdopGLN,
          location,
          packet.latitude,
          packet.longitude,
          packet.height,
          packet.absV,
          packet.rms,
          packet.pdop,
          'GLN',
          lastCoordinates,
          showAllPoints,
          allPointsGLN,
        );
        break;
      case 'GAL':
        _processNavSystemData(
          recentLocationsGAL,
          latitudesGAL,
          longitudesGAL,
          heightsGAL,
          skoGAL,
          pdopGAL,
          location,
          packet.latitude,
          packet.longitude,
          packet.height,
          packet.absV,
          packet.rms,
          packet.pdop,
          'GAL',
          lastCoordinates,
          showAllPoints,
          allPointsGAL,
        );
        break;
      case 'BDS':
        _processNavSystemData(
          recentLocationsBDS,
          latitudesBDS,
          longitudesBDS,
          heightsBDS,
          skoBDS,
          pdopBDS,
          location,
          packet.latitude,
          packet.longitude,
          packet.height,
          packet.absV,
          packet.rms,
          packet.pdop,
          'BDS',
          lastCoordinates,
          showAllPoints,
          allPointsBDS,
        );
        break;
    }
  }

  return lastCoordinates;
}

void _processNavSystemData(
  Queue<LatLng> recentLocations,
  List<double> latitudes,
  List<double> longitudes,
  List<double> heights,
  List<double> skoList,
  List<double> pdopList,
  LatLng location,
  double latitude,
  double longitude,
  double height,
  double velocity,
  double skoNew,
  double pdopNew,
  String systemName,
  Map<String, String> lastCoordinates,
  bool showAllPoints,
  Queue<LatLng> allPoints,
) {
  // Проверяем размер очереди, удаляем старые данные, если превышен лимит
  if (recentLocations.length >= 20) {
    recentLocations.removeFirst();
    latitudes.removeAt(0);
    longitudes.removeAt(0);
    heights.removeAt(0);
    skoList.removeAt(0);
    pdopList.removeAt(0);
  }

  // Добавляем новые данные
  recentLocations.add(location);
  latitudes.add(latitude);
  longitudes.add(longitude);
  heights.add(height);
  skoList.add(skoNew);
  pdopList.add(pdopNew);

  // Добавляем в общий список точек для отображения всей траектории
  if (showAllPoints) {
    allPoints.add(location);
  }

  // Если скорость меньше 1, выводим усредненные данные
  if (velocity < 1) {
    // LatLng averageLocation = _calculateAverageLatLng(recentLocations.toList());
    double averageLatitude = _calculateAverage(latitudes);
    double averageLongitude = _calculateAverage(longitudes);
    double averageHeight = _calculateAverage(heights);
    double sko = _calculateAverage(skoList);
    double pdop = _calculateAverage(pdopList);

    // Формируем строку с данными
    lastCoordinates[systemName] = ('Широта\'($systemName): ${averageLatitude.toStringAsFixed(9)} °, '
        'Долгота\'($systemName): ${averageLongitude.toStringAsFixed(9)} °, '
        'Высота\'($systemName): ${averageHeight.toStringAsFixed(3)} м, '
        'СКО\'($systemName): ${sko.toStringAsFixed(2)} м, '
        'PDOP\'($systemName): ${pdop.toStringAsFixed(2)}');
  } else {
    // Выводим реальные данные, если скорость больше 1
    lastCoordinates[systemName] = ('Широта($systemName): ${latitude.toStringAsFixed(9)} °, '
        'Долгота($systemName): ${longitude.toStringAsFixed(9)} °, '
        'Высота($systemName): ${height.toStringAsFixed(3)} м, '
        'СКО($systemName): ${skoNew.toStringAsFixed(2)} м, '
        'PDOP($systemName): ${pdopNew.toStringAsFixed(2)}');
  }
}

Future<String?> readLastTowFromFiftyPacket(List<String> rawData) async {
  List<FiftyPacketData> packetDataList = filterFiftyPacketData(rawData);

  String? lastTow;

  // Проходим по каждому объекту класса FiftyPacketData
  for (var packet in packetDataList) {
    if (lastTow == null || packet.tow.toString() != lastTow) {
      // Если нашли новое значение TOW, обновляем
      lastTow = packet.tow.toString();
      // print('Новое значение TOW: $lastTow');
    }
  }

  return lastTow;
}

double _calculateAverage(List<double> values) {
  double sum = 0.0;
  for (var value in values) {
    sum += value;
  }
  return sum / values.length;
}

// LatLng _calculateAverageLatLng(List<LatLng> locations) {
//   double sumLat = 0.0;
//   double sumLng = 0.0;
//   for (var location in locations) {
//     sumLat += location.latitude;
//     sumLng += location.longitude;
//   }
//   double avgLat = sumLat / locations.length;
//   double avgLng = sumLng / locations.length;
//   return LatLng(avgLat, avgLng);
// }

// Очереди для хранения последних значений скорости для каждой системы
final Queue<double> absVGPSQueue = Queue();
final Queue<double> absVGLNQueue = Queue();
final Queue<double> absVGALQueue = Queue();
final Queue<double> absVBDSQueue = Queue();

// Максимальный размер очереди (например, 10 последних значений)
const int maxQueueSize = 10;

void updateAbsVQueues(FiftyPacketData packet) {
  switch (packet.navSys) {
    case 'GPS':
      _updateQueue(absVGPSQueue, packet.absV);
      break;
    case 'GLN':
      _updateQueue(absVGLNQueue, packet.absV);
      break;
    case 'GAL':
      _updateQueue(absVGALQueue, packet.absV);
      break;
    case 'BDS':
      _updateQueue(absVBDSQueue, packet.absV);
      break;
  }
}

void _updateQueue(Queue<double> queue, double newValue) {
  // Если очередь заполнена, удаляем самое старое значение
  if (queue.length >= maxQueueSize) {
    queue.removeFirst();
  }
  // Добавляем новое значение
  queue.add(newValue);
}

Future<void> velocityFiftyPacketData(List<String> rawData) async {
  List<FiftyPacketData> packetDataList = filterFiftyPacketData(rawData);

  // Проходим по каждому объекту класса FiftyPacketData и обновляем очереди
  for (var packet in packetDataList) {
    updateAbsVQueues(packet);
  }
}
