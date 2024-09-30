import 'package:flutter/material.dart';
import 'package:flutter_application_clonicus_rxtx/tcp_client/tcp_provider.dart';
import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_service.dart';
import 'package:latlong2/latlong.dart';

class ReceiverNotifier extends ChangeNotifier {
  final ParsingService _parsingService;
  final ScrollController scrollController = ScrollController();

  // Координаты для разных навигационных систем
  LatLng? _gpsLocation;
  double? _gpsHeight;

  LatLng? _glnLocation;
  double? _glnHeight;

  LatLng? _galLocation;
  double? _galHeight;

  LatLng? _bdsLocation;
  double? _bdsHeight;

  ReceiverNotifier(TCPProvider tcpProvider) : _parsingService = ParsingService(tcpProvider) {
    _parsingService.parsedDataNotifier.addListener(notifyListeners);
    _parsingService.isParsingNotifier.addListener(notifyListeners);
    _parsingService.isContinuousParsingNotifier.addListener(notifyListeners);
  }

  // Геттеры для координат навигационных систем
  LatLng? get gpsLocation => _gpsLocation;
  double? get gpsHeight => _gpsHeight;

  LatLng? get glnLocation => _glnLocation;
  double? get glnHeight => _glnHeight;

  LatLng? get galLocation => _galLocation;
  double? get galHeight => _galHeight;

  LatLng? get bdsLocation => _bdsLocation;
  double? get bdsHeight => _bdsHeight;

  // Методы для установки координат GPS
  void setGPSLocation(LatLng location, double height) {
    _gpsLocation = location;
    _gpsHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners(); // Уведомляем слушателей об изменении после завершения сборки
    });
  }

  // Методы для установки координат GLONASS
  void setGLNLocation(LatLng location, double height) {
    _glnLocation = location;
    _glnHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners(); // Уведомляем слушателей об изменении после завершения сборки
    });
  }

  // Методы для установки координат Galileo
  void setGALLocation(LatLng location, double height) {
    _galLocation = location;
    _galHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners(); // Уведомляем слушателей об изменении после завершения сборки
    });
  }

  // Методы для установки координат BeiDou
  void setBDSLocation(LatLng location, double height) {
    _bdsLocation = location;
    _bdsHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners(); // Уведомляем слушателей об изменении после завершения сборки
    });
  }

  List<String> get parsedDataList => _parsingService.parsedDataList;
  bool get isParsing => _parsingService.isParsing;
  bool get isContinuousParsing => _parsingService.isContinuousParsing;

  void toggleParsingFile() async {
    if (_parsingService.isParsing) {
      await _parsingService.stopParsingFile(); // Остановка парсинга
    } else {
      final outputFile = _parsingService.tcpProvider.outputFile;
      if (outputFile.existsSync()) {
        await _parsingService.startParsingFile(outputFile.path); // Запуск парсинга
      }
    }
    notifyListeners(); // Уведомляем UI о смене состояния
  }

  void toggleContinuousParsingFile() async {
    if (_parsingService.isContinuousParsing) {
      await _parsingService.stopContinuousParsingFile();
    } else {
      await _parsingService.startContinuousParsingFile();
    }
  }

  void resumeParsingDisplay() {
    // Уведомляем о наличии данных при возврате
    notifyListeners();
  }

  LatLng? _markerLocation;
  double? _markerHeight;

  // Геттеры для доступа к координатам маркера и высоте
  LatLng? get markerLocation => _markerLocation;
  double? get markerHeight => _markerHeight;

  void setMarkerLocation(LatLng location) {
    _markerLocation = location;
    notifyListeners(); // Уведомляем слушателей об изменении
  }

  void setMarkerHeight(double height) {
    _markerHeight = height;
    notifyListeners(); // Уведомляем слушателей об изменении
  }

  @override
  void dispose() {
    _parsingService.parsedDataNotifier.removeListener(notifyListeners);
    _parsingService.isParsingNotifier.removeListener(notifyListeners);
    _parsingService.isContinuousParsingNotifier.removeListener(notifyListeners);
    scrollController.dispose();
    super.dispose();
  }
}
