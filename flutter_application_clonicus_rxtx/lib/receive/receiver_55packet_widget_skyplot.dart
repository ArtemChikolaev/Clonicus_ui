import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_50packet.dart';
import 'receiver_55packet.dart';
import 'receiver_notifier.dart';

class Receiver55PacketData extends StatelessWidget {
  const Receiver55PacketData({super.key});

// Функция для извлечения и проверки широты
  bool isNonZeroLatitude(String? data, String systemName) {
    if (data == null || data.isEmpty) return false;

    // Ищем строку с широтой с апострофом или без
    final latitudePrefixWithApostrophe = "Широта'($systemName): ";
    final latitudePrefixWithoutApostrophe = "Широта($systemName): ";

    // Определяем, какой вариант строки широты используется
    final startIndexWithApostrophe = data.indexOf(latitudePrefixWithApostrophe);
    final startIndexWithoutApostrophe = data.indexOf(latitudePrefixWithoutApostrophe);

    // Используем найденный индекс для извлечения широты
    int startIndex = startIndexWithApostrophe != -1 ? startIndexWithApostrophe : startIndexWithoutApostrophe;

    // Если широта не найдена, возвращаем false
    if (startIndex == -1) return false;

    // Извлекаем строку с числом широты
    final latitudeString = data.substring(startIndex + (startIndexWithApostrophe != -1 ? latitudePrefixWithApostrophe.length : latitudePrefixWithoutApostrophe.length)).split(' ')[0];

    final latitude = double.tryParse(latitudeString);

    // Проверяем, что широта корректная и не равна 0.0
    return latitude != null && latitude != 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReceiverNotifier>(
      builder: (context, notifier, _) {
        final receiverNotifier = Provider.of<ReceiverNotifier>(context);
        final List<String> rawData = receiverNotifier.parsedDataList;

        // Получаем координаты с помощью readLastCoordinates
        return FutureBuilder<Map<String, String>>(
          future: readLastCoordinates(rawData),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('Ошибка: ${snapshot.error}');
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('Нет данных');
            } else {
              final Map<String, String> coordinates = snapshot.data!;

              // Устанавливаем флаги наличия решения на основе данных и проверки широты
              final hasSolutionGPS = coordinates['GPS'] != null && coordinates['GPS']!.isNotEmpty && isNonZeroLatitude(coordinates['GPS'], 'GPS');

              final hasSolutionGLN = coordinates['GLN'] != null && coordinates['GLN']!.isNotEmpty && isNonZeroLatitude(coordinates['GLN'], 'GLN');

              final hasSolutionGAL = coordinates['GAL'] != null && coordinates['GAL']!.isNotEmpty && isNonZeroLatitude(coordinates['GAL'], 'GAL');

              final hasSolutionBDS = coordinates['BDS'] != null && coordinates['BDS']!.isNotEmpty && isNonZeroLatitude(coordinates['BDS'], 'BDS');

              // После проверки координат строим SkyPlot
              return FutureBuilder<List<Map<String, String>>>(
                future: processFiftyFivePacketData(rawData),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Ошибка: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('Нет данных');
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SkyPlotWidget(
                            data: snapshot.data!,
                            hasSolutionGPS: hasSolutionGPS,
                            hasSolutionGLN: hasSolutionGLN,
                            hasSolutionGAL: hasSolutionGAL,
                            hasSolutionBDS: hasSolutionBDS,
                          ),
                        ),
                      ],
                    );
                  }
                },
              );
            }
          },
        );
      },
    );
  }
}

class SkyPlotPainter extends CustomPainter {
  final List<Map<String, String>> data;
  final bool hasSolutionGPS;
  final bool hasSolutionGLN;
  final bool hasSolutionGAL;
  final bool hasSolutionBDS;

  SkyPlotPainter({
    required this.data,
    required this.hasSolutionGPS,
    required this.hasSolutionGLN,
    required this.hasSolutionGAL,
    required this.hasSolutionBDS,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double radius = (size.width < size.height ? size.width : size.height) / 2 * 0.8; // Динамический радиус
    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    double centerX = size.width / 2;
    double centerY = size.height / 2;

    // Разметка полярных осей
    _drawPolarGrid(canvas, centerX, centerY, radius);

    for (var item in data) {
      double elevation = double.tryParse(item['Угол места'] ?? '0') ?? 0;
      double azimuth = double.tryParse(item['Азимут'] ?? '0') ?? 0;

      // Преобразование углов в радианы
      double radAzimuth = (azimuth - 90) * pi / 180;

      // Вычисление координат
      double r = radius * (1 - elevation / 90); // Преобразование угла места в радиус
      double x = centerX + r * cos(radAzimuth);
      double y = centerY + r * sin(radAzimuth);

      Color color;
      String prefix;
      switch (item['Система ГНСС']) {
        case 'GPS':
          color = hasSolutionGPS ? Colors.red : Colors.grey;
          prefix = 'G';
          break;
        case 'GLN':
          color = hasSolutionGLN ? Colors.blue : Colors.grey;
          prefix = 'R';
          break;
        case 'GAL':
          color = hasSolutionGAL ? Colors.orange : Colors.grey;
          prefix = 'E';
          break;
        case 'BDS':
          color = hasSolutionBDS ? Colors.green : Colors.grey;
          prefix = 'B';
          break;
        default:
          color = Colors.grey;
          prefix = '';
          break;
      }

      // Сдвигаем крайние значения внутрь графика
      x = x.clamp(20, size.width - 20);
      y = y.clamp(20, size.height - 20);

      paint.color = color;
      canvas.drawCircle(Offset(x, y), 15, paint);

      TextSpan span = TextSpan(
        style: const TextStyle(color: Colors.white, fontSize: 12),
        text: '$prefix${item['Номер НКА']}',
      );
      TextPainter textPainter = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
    }
  }

  void _drawPolarGrid(Canvas canvas, double centerX, double centerY, double radius) {
    Paint gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Разметка по углу места
    for (int i = 0; i <= 90; i += 15) {
      double r = radius * (i / 90); // Преобразование угла места
      canvas.drawCircle(Offset(centerX, centerY), r, gridPaint);

      // Добавляем числовую разметку для угла места, кроме 0 градусов
      if (i < 90) {
        TextSpan span = TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 12),
          text: '${90 - i}°', // Инвертируем значения угла места
        );
        TextPainter textPainter = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(centerX + r, centerY - textPainter.height / 2));
      }
    }

    // Разметка по азимуту
    for (int i = 0; i < 360; i += 30) {
      double rad = (i - 90) * pi / 180;
      double x = centerX + radius * cos(rad);
      double y = centerY + radius * sin(rad);
      canvas.drawLine(Offset(centerX, centerY), Offset(x, y), gridPaint);

      // Добавляем числовую разметку для азимута
      TextSpan span = TextSpan(
        style: const TextStyle(color: Colors.black, fontSize: 12),
        text: '$i°',
      );
      TextPainter textPainter = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      double labelX = centerX + (radius + 20) * cos(rad);
      double labelY = centerY + (radius + 20) * sin(rad);
      textPainter.paint(canvas, Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class SkyPlotWidget extends StatefulWidget {
  final List<Map<String, String>> data;
  final bool hasSolutionGPS;
  final bool hasSolutionGLN;
  final bool hasSolutionGAL;
  final bool hasSolutionBDS;

  const SkyPlotWidget({
    super.key,
    required this.data,
    required this.hasSolutionGPS,
    required this.hasSolutionGLN,
    required this.hasSolutionGAL,
    required this.hasSolutionBDS,
  });

  @override
  SkyPlotWidgetState createState() => SkyPlotWidgetState();
}

class SkyPlotWidgetState extends State<SkyPlotWidget> {
  bool showGPS = true;
  bool showGLN = true;
  bool showGAL = true;
  bool showBDS = true;
  bool showSettings = false;

  @override
  Widget build(BuildContext context) {
    List<Map<String, String>> filteredData = widget.data.where((item) {
      switch (item['Система ГНСС']) {
        case 'GPS':
          return showGPS;
        case 'GLN':
          return showGLN;
        case 'GAL':
          return showGAL;
        case 'BDS':
          return showBDS;
        default:
          return false;
      }
    }).toList();

    return Column(
      children: [
        if (showSettings)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color.fromARGB(255, 211, 186, 253)),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Настройки отображения навигационных систем на SkyPlot',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color.fromARGB(255, 252, 149, 142)),
                      onPressed: () {
                        setState(() {
                          showSettings = false;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: showGPS,
                      onChanged: (bool? value) {
                        setState(() {
                          showGPS = value!;
                        });
                      },
                    ),
                    const Text(
                      'GPS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 211, 186, 253)),
                    ),
                    Checkbox(
                      value: showGLN,
                      onChanged: (bool? value) {
                        setState(() {
                          showGLN = value!;
                        });
                      },
                    ),
                    const Text(
                      'GLN',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 211, 186, 253)),
                    ),
                    Checkbox(
                      value: showGAL,
                      onChanged: (bool? value) {
                        setState(() {
                          showGAL = value!;
                        });
                      },
                    ),
                    const Text(
                      'GAL',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 211, 186, 253)),
                    ),
                    Checkbox(
                      value: showBDS,
                      onChanged: (bool? value) {
                        setState(() {
                          showBDS = value!;
                        });
                      },
                    ),
                    const Text(
                      'BDS',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 211, 186, 253)),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Center(
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  showSettings = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 211, 186, 253),
              ),
              child: const Text('Настроить SkyPlot'),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: SkyPlotPainter(
                  data: filteredData,
                  hasSolutionGPS: widget.hasSolutionGPS,
                  hasSolutionGLN: widget.hasSolutionGLN,
                  hasSolutionGAL: widget.hasSolutionGAL,
                  hasSolutionBDS: widget.hasSolutionBDS,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
