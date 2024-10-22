import 'package:flutter/material.dart';
import 'package:flutter_application_clonicus_rxtx/tcp_client/tcp_provider.dart';
import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_service.dart';
import 'package:latlong2/latlong.dart';

class ReceiverNotifier extends ChangeNotifier {
  final ParsingService _parsingService;
  final ScrollController scrollController = ScrollController();
  bool _isParserActive = false; // Переменная для отслеживания активного парсера
  bool get isParserActive => _isParserActive; // Геттер для состояния парсера

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
  Future<bool> startParsingFile(BuildContext context) async {
    if (_isDisposed) return false;

    if (!_parsingService.isParsing) {
      final outputFile = _parsingService.tcpProvider.outputFile;
      if (outputFile.existsSync()) {
        await _parsingService.startParsingFile(outputFile.path);
        _isParserActive = true;
        _notifyIfNotDisposed();

        // Подписываемся на уведомление о завершении парсинга через экземпляр
        _parsingService.parsingCompleteNotifier.addListener(() {
          _isParserActive = false;
          _notifyIfNotDisposed();

          // Показываем SnackBar по завершению парсинга
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parsing file complete')),
          );
        });

        return true;
      } else {
        _isParserActive = false;
        return false;
      }
    }
    return true;
  }

  // Метод для остановки парсера

  Future<bool> stopParsingFile() async {
    if (_isDisposed) return false;

    if (_parsingService.isParsing) {
      await _parsingService.stopParsingFile();
      _isParserActive = false; // Парсер больше не активен
      _notifyIfNotDisposed(); // Уведомляем слушателей о остановке парсера
      return true; // Успешно остановлен
    }
    return false; // Парсер не был запущен
  }

  // Запуск парсера с отслеживанием таймера
  Future<int> startContinuousParsingTcp(bool parse, BuildContext context) async {
    if (_isDisposed) return -1;

    try {
      int result = await _parsingService.startContinuousParsingTcp(parse);

      if (result == -1) {
        _isParserActive = false;
        // print('Parser stopped due to timeout or error, stopping parsing...');
      } else {
        _isParserActive = true;
      }

      _notifyIfNotDisposed();

      // Подписываемся на уведомление о завершении парсинга
      _parsingService.parsingCompleteNotifier.addListener(() async {
        _isParserActive = false;
        _notifyIfNotDisposed();

        // Показываем SnackBar, если парсинг остановился из-за таймаута
        if (!_isParserActive) {
          // Показываем SnackBar при тайм-ауте или иных проблемах со стороны TCP-порта
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Parser stopped due to timeout or error')),
          );
        }
      });

      return result;
    } catch (e) {
      // print('Error during TCP parsing: $e');
      _isParserActive = false;
      _notifyIfNotDisposed();
      return -1;
    }
  }

// Метод для остановки постоянного парсинга TCP
  Future<bool> stopContinuousParsingTcp(bool parse, BuildContext context) async {
    if (_isDisposed) return false;

    try {
      // Передаем false для остановки парсинга
      int result = await startContinuousParsingTcp(parse, context);

      if (result == -1) {
        _isParserActive = false; // Обновляем флаг активности парсера
        _notifyIfNotDisposed();
        return true; // Парсер успешно остановлен
      } else {
        return false; // Ошибка при остановке
      }
    } catch (e) {
      return false; // Ошибка при остановке
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
