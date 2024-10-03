import 'dart:async';
import 'package:flutter/foundation.dart';
import 'srns_isolate.manager.dart';
import 'package:flutter_application_clonicus_rxtx/tcp_client/tcp_provider.dart';

class ParsingService {
  final ValueNotifier<List<String>> parsedDataNotifier = ValueNotifier<List<String>>([]);
  final TCPProvider _tcpProvider;
  StreamSubscription? _subscription;

  // Флаг, указывающий на то, был ли объект уничтожен
  bool _isDisposed = false;

  // Состояние парсинга
  final ValueNotifier<bool> isParsingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isContinuousParsingNotifier = ValueNotifier<bool>(false);

  ParsingService(this._tcpProvider) {
    _initializeContinuousSubscription();
  }

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

  Future<void> startParsingFile(String filePath) async {
    if (IsolateManager.isParsing || _isDisposed) return; // Добавлена проверка на уничтожение

    if (!_isDisposed) {
      isParsingNotifier.value = true;
    }

    await IsolateManager.startParsingFile(filePath);

    IsolateManager.parsingCompleteNotifier.addListener(() {
      if (!IsolateManager.isParsing && !_isDisposed) {
        _completeParsing();
      }
    });

    _addParsedData([
      'Parsing started'
    ]);
  }

  Future<void> stopParsingFile() async {
    if (IsolateManager.isParsing && !_isDisposed) {
      await IsolateManager.stopParsingFile();
      isParsingNotifier.value = false;

      _addParsedData([
        'Parsing stopped'
      ]);
    }
  }

  Future<void> startContinuousParsingFile() async {
    if (IsolateManager.isContinuousParsing || _isDisposed) return; // Добавлена проверка на уничтожение

    if (!_isDisposed) {
      isContinuousParsingNotifier.value = true;
    }

    await IsolateManager.startContinuousParsingFile(_tcpProvider.outputFile.path);

    _addParsedData([
      'Continuous parsing started'
    ]);
  }

  Future<void> stopContinuousParsingFile() async {
    if (IsolateManager.isContinuousParsing && !_isDisposed) {
      await IsolateManager.stopContinuousParsingFile();
      isContinuousParsingNotifier.value = false;

      _addParsedData([
        'Continuous parsing stopped'
      ]);
    }
  }

  void _addParsedData(List<String> data) {
    if (_isDisposed) return; // Проверка на уничтожение
    final updatedData = List<String>.from(parsedDataNotifier.value)..addAll(data);
    parsedDataNotifier.value = updatedData;
  }

  void _completeParsing() {
    if (_isDisposed) return; // Проверка на уничтожение
    isParsingNotifier.value = false;
    IsolateManager.cleanUpParsing();
  }

  void dispose() {
    _subscription?.cancel();
    parsedDataNotifier.dispose();
    isParsingNotifier.dispose();
    isContinuousParsingNotifier.dispose();
    _isDisposed = true; // Устанавливаем флаг при уничтожении
  }
}
