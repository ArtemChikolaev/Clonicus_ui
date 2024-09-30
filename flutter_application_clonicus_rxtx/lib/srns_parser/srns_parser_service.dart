import 'dart:async';
import 'package:flutter/foundation.dart';
import 'srns_isolate.manager.dart';
import 'package:flutter_application_clonicus_rxtx/tcp_client/tcp_provider.dart';

class ParsingService {
  // Используем ValueNotifier для списка данных, чтобы UI всегда знал о изменениях.
  final ValueNotifier<List<String>> parsedDataNotifier = ValueNotifier<List<String>>([]);
  final TCPProvider _tcpProvider;
  StreamSubscription? _subscription;

  // Состояние парсинга
  final ValueNotifier<bool> isParsingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isContinuousParsingNotifier = ValueNotifier<bool>(false);

  ParsingService(this._tcpProvider) {
    _initializeContinuousSubscription();
  }

  /// Подписка на поток данных, чтобы она всегда была активна
  void _initializeContinuousSubscription() {
    _subscription?.cancel();
    _subscription = IsolateManager.stream.listen((message) {
      _addParsedData(message.map((data) => data.toString()).toList());
      // print('Parsed data received in srns_parser_service: $message');
    });
  }

  List<String> get parsedDataList => parsedDataNotifier.value;
  bool get isParsing => IsolateManager.isParsing;
  bool get isContinuousParsing => IsolateManager.isContinuousParsing;

  TCPProvider get tcpProvider => _tcpProvider;

  /// Запуск парсинга файла
  Future<void> startParsingFile(String filePath) async {
    if (IsolateManager.isParsing) return;

    isParsingNotifier.value = true;

    await IsolateManager.startParsingFile(filePath);

    IsolateManager.parsingCompleteNotifier.addListener(() {
      if (!IsolateManager.isParsing) {
        _completeParsing(); // Сбрасываем состояние парсинга после завершения
      }
    });

    _addParsedData([
      'Parsing started'
    ]);
  }

  /// Остановка парсинга файла
  Future<void> stopParsingFile() async {
    if (IsolateManager.isParsing) {
      await IsolateManager.stopParsingFile();
      isParsingNotifier.value = false;

      _addParsedData([
        'Parsing stopped'
      ]);
    }
  }

  /// Запуск непрерывного парсинга
  Future<void> startContinuousParsingFile() async {
    if (IsolateManager.isContinuousParsing) return;

    await IsolateManager.startContinuousParsingFile(_tcpProvider.outputFile.path);
    isContinuousParsingNotifier.value = true;

    _addParsedData([
      'Continuous parsing started'
    ]);
  }

  /// Остановка непрерывного парсинга
  Future<void> stopContinuousParsingFile() async {
    if (IsolateManager.isContinuousParsing) {
      await IsolateManager.stopContinuousParsingFile();
      isContinuousParsingNotifier.value = false;

      _addParsedData([
        'Continuous parsing stopped'
      ]);
    }
  }

  /// Добавление данных в список и уведомление UI
  void _addParsedData(List<String> data) {
    // Создаем копию текущего списка, чтобы обновить UI
    final updatedData = List<String>.from(parsedDataNotifier.value)..addAll(data);
    parsedDataNotifier.value = updatedData; // Обновляем ValueNotifier
  }

  // Окончание парсинга файла
  void _completeParsing() {
    isParsingNotifier.value = false;
    IsolateManager.cleanUpParsing();
  }

  /// Очистка ресурсов при уничтожении
  void dispose() {
    _subscription?.cancel();
    parsedDataNotifier.dispose();
    isParsingNotifier.dispose();
    isContinuousParsingNotifier.dispose();
  }
}
