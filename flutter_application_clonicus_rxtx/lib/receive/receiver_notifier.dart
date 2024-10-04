import 'package:flutter/material.dart';
import 'package:flutter_application_clonicus_rxtx/tcp_client/tcp_provider.dart';
import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_service.dart';
import 'package:latlong2/latlong.dart';

class ReceiverNotifier extends ChangeNotifier {
  final ParsingService _parsingService;
  final ScrollController scrollController = ScrollController();
  // ignore: unused_field
  bool _isParserActive = false; // Переменная для отслеживания активного парсера

  bool _isDisposed = false; // Флаг для отслеживания, уничтожен ли объект

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
    _parsingService.parsedDataNotifier.addListener(_notifyIfNotDisposed);
    _parsingService.isParsingNotifier.addListener(_notifyIfNotDisposed);
    _parsingService.isContinuousParsingNotifier.addListener(_notifyIfNotDisposed);
  }

  // Проверка на то, уничтожен ли объект, перед уведомлением слушателей
  void _notifyIfNotDisposed() {
    if (!_isDisposed) {
      notifyListeners();
    }
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
      _notifyIfNotDisposed(); // Уведомляем слушателей об изменении после завершения сборки
    });
  }

  // Методы для установки координат GLONASS
  void setGLNLocation(LatLng location, double height) {
    _glnLocation = location;
    _glnHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyIfNotDisposed(); // Уведомляем слушателей об изменении после завершения сборки
    });
  }

  // Методы для установки координат Galileo
  void setGALLocation(LatLng location, double height) {
    _galLocation = location;
    _galHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyIfNotDisposed(); // Уведомляем слушателей об изменении после завершения сборки
    });
  }

  // Методы для установки координат BeiDou
  void setBDSLocation(LatLng location, double height) {
    _bdsLocation = location;
    _bdsHeight = height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyIfNotDisposed(); // Уведомляем слушателей об изменении после завершения сборки
    });
  }

  List<String> get parsedDataList => _parsingService.parsedDataList;
  bool get isParsing => _parsingService.isParsing;
  bool get isContinuousParsing => _parsingService.isContinuousParsing;

  // Метод для запуска парсера
  Future<bool> startParsingFile() async {
    if (_isDisposed) return false;

    if (!_parsingService.isParsing) {
      final outputFile = _parsingService.tcpProvider.outputFile;
      if (outputFile.existsSync()) {
        await _parsingService.startParsingFile(outputFile.path);
        _notifyIfNotDisposed(); // Уведомляем слушателей о запуске парсера
        return true; // Успешно запущен
      } else {
        return false; // Файл не найден
      }
    }
    return true; // Парсер уже запущен
  }

  // Метод для остановки парсера
  Future<bool> stopParsingFile() async {
    if (_isDisposed) return false;

    if (_parsingService.isParsing) {
      await _parsingService.stopParsingFile();
      _notifyIfNotDisposed(); // Уведомляем слушателей о остановке парсера
      return true; // Успешно остановлен
    }
    return false; // Парсер не был запущен
  }

  void toggleContinuousParsingFile() async {
    if (_isDisposed) return; // Проверяем, не уничтожен ли объект
    if (_parsingService.isContinuousParsing) {
      await _parsingService.stopContinuousParsingFile();
      _clearData();
      _isParserActive = false;
      _notifyIfNotDisposed();
    } else {
      _isParserActive = true;
      await _parsingService.startContinuousParsingFile();
      _notifyIfNotDisposed();
    }
  }

  void _clearData() {
    _gpsLocation = null;
    _gpsHeight = null;
    _glnLocation = null;
    _glnHeight = null;
    _galLocation = null;
    _galHeight = null;
    _bdsLocation = null;
    _bdsHeight = null;
    if (!_isDisposed) {
      notifyListeners(); // Обновляем состояние после очистки данных
    }
  }

  void resumeParsingDisplay() {
    // Уведомляем о наличии данных при возврате
    _notifyIfNotDisposed();
  }

  LatLng? _markerLocation;
  double? _markerHeight;

  // Геттеры для доступа к координатам маркера и высоте
  LatLng? get markerLocation => _markerLocation;
  double? get markerHeight => _markerHeight;

  // Установка маркера с координатами
  void setMarkerLocation(LatLng location, {double? height}) {
    _markerLocation = location;
    _markerHeight = height;
    _notifyIfNotDisposed();
  }

  // Удаление маркера
  void removeMarker() {
    _markerLocation = null;
    _markerHeight = null;
    _notifyIfNotDisposed(); // Уведомляем слушателей об изменении
  }

  void resetUI() {
    // Логика сброса состояния UI
    notifyListeners(); // Оповещаем слушателей об изменении
  }

  @override
  void dispose() {
    _isDisposed = true; // Устанавливаем флаг уничтожения
    _parsingService.parsedDataNotifier.removeListener(_notifyIfNotDisposed);
    _parsingService.isParsingNotifier.removeListener(_notifyIfNotDisposed);
    _parsingService.isContinuousParsingNotifier.removeListener(_notifyIfNotDisposed);
    _parsingService.dispose(); // Удаляем возможные оставшиеся задачи
    scrollController.dispose();
    super.dispose();
  }
}
