import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_50packet_widget_coord.dart';
// import 'receiver_55packet.dart';
import 'receiver_50packet_widget_map.dart';
import 'receiver_50packet_widget_marker.dart';
import 'receiver_50packet_widget_speed.dart';
import 'receiver_notifier.dart';
import 'package:flutter_application_clonicus_rxtx/tcp_client/tcp_provider.dart';
import 'receiver_f5packet_widget_sumsat.dart';
import 'receiver_widget_copy_coord_button.dart';
import 'receiver_widget_delete_marker.dart';
import 'receiver_widget_market_texfield.dart';
import 'receiver_widget_time.dart';

class ReceiverPage extends StatefulWidget {
  const ReceiverPage({super.key});

  @override
  ReceiverPageState createState() => ReceiverPageState();
}

class ReceiverPageState extends State<ReceiverPage> with AutomaticKeepAliveClientMixin {
  ReceiverNotifier? _receiverNotifier;
  int _resetKey = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Используем addPostFrameCallback, чтобы избежать вызова notifyListeners во время сборки
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = Provider.of<ReceiverNotifier>(context, listen: false);
      notifier.resumeParsingDisplay();
    });
  }

  // Метод для сброса состояния UI
  void _resetUI() {
    setState(() {
      _resetKey++;
    });
  }

  // Пересоздаём notifier
  void _rebuildNotifier() {
    setState(() {
      _receiverNotifier = ReceiverNotifier(Provider.of<TCPProvider>(context, listen: false));
      _resetKey++; // Обновляем ключ для полного пересоздания
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tcpProvider = Provider.of<TCPProvider>(context);

    return ChangeNotifierProvider(
      key: ValueKey(_resetKey), // Обновляем ключ для полного пересоздания
      create: (_) => ReceiverNotifier(tcpProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Receiver Page'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Consumer<ReceiverNotifier>(
                    builder: (context, notifier, _) => ElevatedButton(
                      onPressed: notifier.isParsing
                          ? null
                          : () {
                              _resetUI(); // Сначала сбрасываем UI
                              notifier.toggleParsingFile(); // Затем запускаем парсинг
                              _rebuildNotifier(); // Пересоздаём notifier для сброса состояния
                            },
                      child: Text(
                        notifier.isParsing ? 'Processing file...' : 'Start Parsing file',
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Consumer<ReceiverNotifier>(
                    builder: (context, notifier, _) => ElevatedButton(
                      onPressed: notifier.isParsing
                          ? () {
                              notifier.toggleParsingFile();
                            }
                          : null,
                      child: const Text('Stop Parsing file'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Consumer<ReceiverNotifier>(
                    builder: (context, notifier, _) => ElevatedButton(
                      onPressed: notifier.isContinuousParsing
                          ? null
                          : () {
                              _resetUI(); // Сначала сбрасываем UI
                              notifier.toggleContinuousParsingFile(); // Затем запускаем парсинг
                              _rebuildNotifier(); // Пересоздаём notifier для сброса состояния
                            },
                      child: Text(notifier.isContinuousParsing ? 'Parsing tcp-port...' : 'Start Parsing tcp-port'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Consumer<ReceiverNotifier>(
                    builder: (context, notifier, _) => ElevatedButton(
                      onPressed: notifier.isContinuousParsing
                          ? () {
                              notifier.toggleContinuousParsingFile();
                            }
                          : null,
                      child: const Text('Stop Parsing tcp-port'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _resetUI,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 252, 149, 142),
                    ),
                    child: const Text('Reset UI'),
                  ),
                  const SizedBox(width: 20),
                  const CopyCoordinatesButton(),
                  const SizedBox(width: 20),
                  const RemoveMarkerButton(),
                ],
              ),
              const SizedBox(height: 20),
              ReceiverF5PacketSatellites(),

              const SizedBox(height: 20),
              const Receiver50PacketCoord(),

              const SizedBox(height: 20),
              const Receiver50PacketTow(),

              const SizedBox(height: 20),
              const Receiver50PacketAbsV(),

              const SizedBox(height: 20),
              const Receiver50PacketMap(),

              const SizedBox(height: 20),
              Consumer<ReceiverNotifier>(
                builder: (context, notifier, _) {
                  return MarkerDistanceDisplay(
                    markerLocation: notifier.markerLocation, // Предполагается, что есть свойство markerLocation
                    markerHeight: notifier.markerHeight, // Предполагается, что есть свойство markerHeight
                    currentLocationGPS: notifier.gpsLocation,
                    currentHeightGPS: notifier.gpsHeight,
                    currentLocationGLN: notifier.glnLocation,
                    currentHeightGLN: notifier.glnHeight,
                    currentLocationGAL: notifier.galLocation,
                    currentHeightGAL: notifier.galHeight,
                    currentLocationBDS: notifier.bdsLocation,
                    currentHeightBDS: notifier.bdsHeight,
                  );
                },
              ),
              const SizedBox(height: 20),
              const ReceiverWidgetMarkerTextField(),
              // const SizedBox(height: 20),
              // const ReceiverF5Packet(),
              // const SizedBox(height: 20),
              // const Receiver50PacketCoord(),
            ],
          ),
        ),
      ),
    );
  }
}
