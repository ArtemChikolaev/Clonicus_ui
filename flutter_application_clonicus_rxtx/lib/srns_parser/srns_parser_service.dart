import 'dart:async';
import 'package:flutter/foundation.dart';
import 'srns_isolate.manager.dart';
import 'package:flutter_application_clonicus_rxtx/tcp_client/tcp_provider.dart';

class ParsingService {
  final ValueNotifier<List<String>> parsedDataNotifier = ValueNotifier<List<String>>([]);
  final TCPProvider _tcpProvider;
  StreamSubscription? _subscription;

  bool _isDisposed = false;

  final ValueNotifier<bool> isParsingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isContinuousParsingNotifier = ValueNotifier<bool>(false);

  ParsingService(this._tcpProvider) {
    _initializeContinuousSubscription();
  }

  void _initializeContinuousSubscription() {
    _subscription?.cancel();
    _subscription = IsolateManager.stream.listen((message) {
      _addParsedData(message.map((data) => data.toString()).toList());
    });
  }

  List<String> get parsedDataList => parsedDataNotifier.value;
  bool get isParsing => IsolateManager.isParsing;
  bool get isContinuousParsing => IsolateManager.isContinuousParsing;

  TCPProvider get tcpProvider => _tcpProvider;

  ValueNotifier<void> get parsingCompleteNotifier => IsolateManager.parsingCompleteNotifier;

  Future<void> startParsingFile(String filePath) async {
    if (isParsingNotifier.value || _isDisposed) return;

    isParsingNotifier.value = true;

    await IsolateManager.startParsingFile(filePath);

    // Добавляем слушателя на завершение парсинга
    parsingCompleteNotifier.addListener(_onParsingComplete);

    _addParsedData([
      'Parsing started'
    ]);
  }

  void _onParsingComplete() {
    if (!_isDisposed) {
      _completeParsing(); // Завершение парсинга
    }
  }

  Future<void> stopParsingFile() async {
    if (IsolateManager.isParsing && !_isDisposed) {
      await IsolateManager.stopParsingFile();
      isParsingNotifier.value = false;

      _addParsedData([
        'Parsing stopped'
      ]);
      _completeParsing();
    }
  }

  Future<void> startContinuousParsingFile() async {
    if (IsolateManager.isContinuousParsing || _isDisposed) return;

    isContinuousParsingNotifier.value = true;

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
    if (_isDisposed) return;
    final updatedData = List<String>.from(parsedDataNotifier.value)..addAll(data);
    parsedDataNotifier.value = updatedData;
  }

  void _completeParsing() {
    if (_isDisposed) return;

    // Обновляем состояние парсинга
    isParsingNotifier.value = false;
    parsingCompleteNotifier.value = true;

    _addParsedData([
      'Parsing completed'
    ]);
    IsolateManager.cleanUpParsing();

    // Удаляем слушателя завершения
    parsingCompleteNotifier.removeListener(_onParsingComplete);
  }

  void dispose() {
    _subscription?.cancel();
    parsedDataNotifier.dispose();
    isParsingNotifier.dispose();
    isContinuousParsingNotifier.dispose();
    _isDisposed = true;
  }
}
