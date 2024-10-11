import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'srns_parser_main.dart';

class IsolateManager {
  static Isolate? _parsingIsolate;
  static ReceivePort? _receivePort;
  static bool isContinuousParsing = false;
  static bool isParsing = false;
  static bool isListening = false; // Флаг для отслеживания состояния слушателя
  static bool shouldContinue = true; // Флаг для продолжения работы

  static StreamController<List<Map<String, dynamic>>>? _streamController;
  static final ValueNotifier<bool> isParsingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> parsingCompleteNotifier = ValueNotifier<bool>(false);

  // Метод для получения данных из парсинга
  static Stream<List<Map<String, dynamic>>> get stream {
    if (_streamController == null || _streamController!.isClosed) {
      _streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
    }
    return _streamController!.stream;
  }

  static ReceivePort? get receivePort => _receivePort;

// Запуск парсинга файла
  static Future<void> startParsingFile(String filePath) async {
    if (isParsing) return;

    isParsing = true;
    isParsingNotifier.value = true; // Устанавливаем состояние парсинга в true
    _receivePort = ReceivePort(); // Создаем новый ReceivePort

    _parsingIsolate = await Isolate.spawn(
      _startParsingFromFile,
      {
        'filePath': filePath,
        'sendPort': _receivePort!.sendPort, // Передаем SendPort
      },
    );

    _receivePort!.listen((message) {
      if (message == 'done') {
        isParsing = false; // Завершаем процесс парсинга
        isParsingNotifier.value = false; // Обновляем состояние парсинга
        parsingCompleteNotifier.value = true; // Уведомляем об окончании парсинга
        cleanUpParsing();
      } else if (message is List<Map<String, dynamic>>) {
        // print('Received parsed data: $message');
        _streamController?.add(message); // Передаем данные через StreamController
      } else if (message is Map<String, dynamic>) {
        if (message.containsKey('error')) {
          print('Error during parsing: ${message['error']}');
        } else {
          print('Other message: $message');
        }
      }
    });
  }

  // Остановка парсинга файла
  static Future<void> stopParsingFile() async {
    if (isParsing) {
      isParsing = false;

      // Отправляем сигнал на остановку парсинга
      _receivePort?.sendPort.send('stop');

      // Очищаем ресурсы
      cleanUpParsing();
    }
  }

  // Статические поля для изоляторов и портов
  static List<Isolate> isolatePool = [];
  static List<ReceivePort> receivePorts = []; // Для управления портами

  // Метод для отправки данных в изолятор
  Future<void> sendDataToIsolate(Uint8List data) async {
    // Запускаем новый изолятор для обработки порции данных
    ReceivePort receivePort = ReceivePort();
    Isolate isolate = await Isolate.spawn(
      _startContinuousParsingInIsolate,
      {
        'dataStream': data,
        'sendPort': receivePort.sendPort,
      },
    );

    isolatePool.add(isolate); // Добавляем изолятор в пул
    receivePorts.add(receivePort); // Сохраняем порт

    // Таймер для принудительного завершения, если изолятор зависнет
    Timer timer = Timer(const Duration(seconds: 3), () {
      if (isolatePool.contains(isolate)) {
        // print('Force killing isolate due to timeout.');
        isolate.kill(priority: Isolate.immediate);
        receivePort.close();
        isolatePool.remove(isolate);
        receivePorts.remove(receivePort);
      }
    });

    receivePort.listen((message) {
      if (message == 'done') {
        // Изолятор завершил работу
        // print('Isolate completed parsing.');
        timer.cancel(); // Останавливаем таймер, так как изолятор завершил работу
        receivePort.close(); // Закрываем порт после завершения
        isolate.kill(priority: Isolate.immediate); // Уничтожаем изолятор
        isolatePool.remove(isolate); // Удаляем из пула
        receivePorts.remove(receivePort); // Удаляем порт
      } else if (message is List<Map<String, dynamic>>) {
        // Обрабатываем данные
        _streamController?.add(message);
      } else if (message is Map<String, dynamic>) {
        if (message.containsKey('error')) {
          print('Error during parsing: ${message['error']}');
        }
      }
    });
  }

  // Метод для остановки всех изоляторов
  static Future<void> stopAllIsolates() async {
    for (var isolate in isolatePool) {
      isolate.kill(priority: Isolate.immediate); // Останавливаем изолятор
    }
    isolatePool.clear(); // Очищаем пул изоляторов
    print('All isolates stopped.');
  }

  // Остановка постоянного парсинга
  static Future<void> stopContinuousParsingFile() async {
    if (isContinuousParsing) {
      isContinuousParsing = false;

      // Отправляем сигнал на остановку для каждого изолята в пуле
      for (var port in receivePorts) {
        port.sendPort.send('stop');
      }

      // Ожидание завершения всех изоляторов
      await Future.wait(isolatePool.map((isolate) async {
        // Ждем завершения каждого изолятора
        await isolate;
        isolate.kill(priority: Isolate.immediate); // Уничтожаем изолятор
      }));

      // Очищаем ресурсы
      cleanUpParsing();
    } else {
      print('Continuous parsing is not running.');
    }
  }

  static Future<void> _startParsingFromFile(Map<String, dynamic> params) async {
    String filePath = params['filePath'];
    SendPort sendPort = params['sendPort']; // Получаем SendPort

    final srnsParser = SRNSParser(filePath);

    // Запуск процесса парсинга
    await srnsParser.readAndParse(); // Убедимся, что парсер стартует

    // Подписываемся на поток данных из парсера
    srnsParser.stream.listen((data) {
      if (data.isNotEmpty) {
        // print('isolate_manager: $data');
        sendPort.send(data); // Отправляем данные в главный изолят
      }
    }, onDone: () {
      print('Stream completed, sending done message...');
      sendPort.send('done'); // Отправляем сообщение о завершении
    }, onError: (error) {
      print('Stream error: $error');
      sendPort.send({
        'error': error.toString()
      });
    });
  }

// Метод для выполнения парсинга в изоляторе
  static Future<void> _startContinuousParsingInIsolate(Map<String, dynamic> params) async {
    Uint8List dataStream = params['dataStream'];
    SendPort sendPort = params['sendPort'];

    final srnsParser = SRNSParserContinious();
    await srnsParser.start();
    // print('Parsing 10000 bytes of data.');

    srnsParser.addData(dataStream);

    srnsParser.stream.listen((data) {
      if (data.isNotEmpty) {
        sendPort.send(data); // Отправляем данные обратно в основной поток
      }
    }, onDone: () {
      sendPort.send('done'); // Сообщаем о завершении работы
    }, onError: (error) {
      sendPort.send({
        'error': error.toString()
      });
    });
  }

  // Метод для остановки изолятора
  static Future<void> stopIsolate() async {
    if (_parsingIsolate != null && _receivePort != null) {
      print('Stopping isolate...');

      // Отправляем сигнал в изолятор на остановку
      _receivePort!.sendPort.send('stop');

      // Устанавливаем флаг остановки парсинга
      isParsing = false;

      // Ожидаем завершение изолятора
      _parsingIsolate!.kill(priority: Isolate.immediate);
      _parsingIsolate = null;

      // Закрываем ReceivePort
      _receivePort?.close();
      _receivePort = null;

      // Закрываем StreamController
      if (_streamController != null && !_streamController!.isClosed) {
        await _streamController!.close();
        _streamController = null;
      }

      print('Isolate stopped successfully.');
    } else {
      print('No active isolate to stop.');
    }
  }

  static void cleanUpParsing() {
    _receivePort?.close();
    _receivePort = null;
    // Устанавливаем значение в false, если парсинг завершен
    _parsingIsolate?.kill(priority: Isolate.immediate);
    _parsingIsolate = null;
    _streamController?.close();
    _streamController = null; // Очищаем контроллер, чтобы он мог быть пересоздан
  }
}
