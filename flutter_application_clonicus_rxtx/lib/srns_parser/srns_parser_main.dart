import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'srns_parser_other_func.dart';
import 'srns_parser_structure.dart';

class ProtocolSRNS {
  Uint8List totalBuffer = Uint8List(0); // Буфер всего файла
  Uint8List preambleBuffer = Uint8List(0); // Буфер, начиная с преамбулы
  int totalBytesRead = 0; // Общий счетчик прочитанных байтов
  int totalPreamblesCount = 0;
  List<Uint8List> packets = [];

  final StreamController<Map<String, dynamic>> packetStreamController = StreamController.broadcast();

  // Стрим для передачи данных о пакете
  Stream<Map<String, dynamic>> get packetStream => packetStreamController.stream;

  // Проверка и обработка пакета
  void checkPacket(Uint8List data) {
    totalBuffer = Uint8List.fromList(totalBuffer + data); // Добавляем данные в общий буфер

    while (totalBuffer.length >= 12) {
      // Ищем преамбулу пакета
      int preambleIndex = findPreamble(totalBuffer);
      if (preambleIndex == -1) {
        // Если преамбула не найдена, выходим
        return;
      }

      // Создаём буфер для пакета с преамбулой
      preambleBuffer = totalBuffer.sublist(preambleIndex);
      totalBytesRead += preambleIndex;

      // Пытаемся извлечь данные пакета
      PacketData? packetData = extractPacketData(preambleBuffer);

      // Если данных недостаточно для формирования полного пакета, выходим
      if (packetData == null) {
        // print('Bad data length');
        return;
      }

      // Если CRC совпадает, обрабатываем пакет
      if (packetData.crcPos == packetData.crcCalc) {
        // Обрабатываем пакет и сразу отправляем данные
        List<Map<String, dynamic>> parsedData = processPacket(packetData);
        for (var data in parsedData) {
          // print('packetStreamController: $parsedData');
          packetStreamController.add(data); // Отправляем данные пакета в поток
        }

        // Очищаем буфер до конца пакета
        totalBuffer = totalBuffer.sublist(preambleIndex + packetData.getSize);
        totalBytesRead += packetData.getSize;
        totalPreamblesCount++;
      } else {
        // Если CRC не совпадает, пропускаем пару байтов и продолжаем
        totalBuffer = totalBuffer.sublist(preambleIndex + 2);
        totalBytesRead += 2;
      }
    }
  }

  void dispose() {
    packetStreamController.close();
  }
}

class SRNSParser {
  final File _file;
  final ProtocolSRNS _protocol = ProtocolSRNS(); // Протокол для обработки данных
  late RandomAccessFile _raf; // Для работы с файлом
  int _filePosition = 0; // Позиция текущего чтения в файле
  late Timer _timer; // Таймер для считывания байтов
  static const int _readDelay = 1; // Задержка в миллисекундах (раз в секунду)
  late int _chunkSize; // Размер блока для чтения данных (определяется динамически)
  bool _isReading = false; // Флаг для блокировки выполнения асинхронной операции
  bool _fileEndReached = false; // Флаг для остановки, когда файл прочитан
  late int _totalRecordingTime; // Общее время записи файла

  final StreamController<List<Map<String, dynamic>>> _streamController = StreamController.broadcast();
  Stream<List<Map<String, dynamic>>> get stream => _streamController.stream;

  SRNSParser(String filePath) : _file = File(filePath);

  Future<void> readAndParse() async {
    try {
      _raf = await _file.open();
      int fileSize = await _file.length();

      if (fileSize == 0) {
        return;
      }

      _totalRecordingTime = determineRecordingTime(fileSize);
      _chunkSize = (fileSize / _totalRecordingTime).ceil();

      print('Total recording time: $_totalRecordingTime seconds, Chunk size: $_chunkSize bytes');

      _protocol.packetStream.listen((packetData) {
        _streamController.add([
          packetData
        ]);
      });

      _timer = Timer.periodic(const Duration(seconds: _readDelay), (timer) async {
        int currentFileSize = await _file.length();

        if (_filePosition >= currentFileSize) {
          if (!_fileEndReached) {
            print('File fully read. Total preambles found: ${_protocol.totalPreamblesCount}');
            _fileEndReached = true;

            // Закрываем поток данных после завершения чтения файла
            await _streamController.close();
            _timer.cancel();
          }
        } else {
          if (!_isReading) {
            await _readChunk(currentFileSize);
          }
        }
      });
    } catch (e, stackTrace) {
      print('Error: $e');
      print('StackTrace: $stackTrace');
      _timer.cancel();
    }
  }

  Future<void> _readChunk(int fileSize) async {
    try {
      _isReading = true;

      if (_filePosition < fileSize) {
        await _raf.setPosition(_filePosition);

        int bytesLeft = fileSize - _filePosition;
        int bytesToRead = bytesLeft >= _chunkSize ? _chunkSize : bytesLeft;

        Uint8List chunk = await _raf.read(bytesToRead);

        if (chunk.isNotEmpty) {
          _filePosition += chunk.length;

          // print('Reading chunk: $chunk');
          _protocol.checkPacket(chunk);
          // print('File position after reading: $_filePosition');
        } else {}
      }

      _isReading = false;
    } catch (e, stackTrace) {
      // print('Error during file parsing: $e');
      print('StackTrace: $stackTrace');
      _timer.cancel();
    }
  }

  int determineRecordingTime(int fileSizeInBytes) {
    const int bytesPerSecond = 10000;
    return (fileSizeInBytes / bytesPerSecond).ceil();
  }

  Future<void> stop() async {
    _timer.cancel();
    await _raf.close();
    await _streamController.close();
    _protocol.dispose();
  }
}

class SRNSParserContinious {
  final StreamController<List<Map<String, dynamic>>> _streamController = StreamController.broadcast();
  final ProtocolSRNS _protocol = ProtocolSRNS(); // Протокол для обработки данных
  Uint8List _buffer = Uint8List(0); // Буфер для данных
  final int maxBufferSize = 10000; // Максимальный размер буфера (10000 байт)
  final List<Map<String, dynamic>> _currentParsedData = []; // Список текущих распарсенных данных
  Timer? _timer;

  Stream<List<Map<String, dynamic>>> get stream => _streamController.stream;

  SRNSParserContinious() {
    // Подписываемся на поток данных из протокола только один раз при инициализации
    _protocol.packetStream.listen((packetData) {
      _currentParsedData.add(packetData);
    });
  }

  Future<void> start() async {
    // Запускаем таймер для отправки распарсенных данных раз в секунду
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentParsedData.isNotEmpty) {
        // print('Sending parsed data: $_currentParsedData');
        _streamController.add(List.from(_currentParsedData));
        _currentParsedData.clear();
      } else {
        print('No new data to send...');
      }
    });
  }

  Future<void> addData(Uint8List newData) async {
    _buffer = Uint8List.fromList(_buffer + newData);
    // print('Data length in isolate before check: ${_buffer.length}');

    // Проверяем размер буфера
    if (_buffer.length > maxBufferSize) {
      int excessSize = _buffer.length - maxBufferSize;
      _buffer = _buffer.sublist(excessSize);
      // print('Buffer trimmed 2: NEW size is ${_buffer.length}');
    }

    // Обрабатываем данные сразу, без задержек
    _protocol.checkPacket(_buffer);
  }

  void dispose() {
    _timer?.cancel();
    _streamController.close();
    _protocol.dispose();
  }
}
