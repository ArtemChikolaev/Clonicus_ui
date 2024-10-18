import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'receiver_50packet_widget_coord.dart';
import 'receiver_50packet_widget_map.dart';
import 'receiver_50packet_widget_marker.dart';
import 'receiver_50packet_widget_speed.dart';
import 'receiver_55packet_widget_skyplot.dart';
import 'receiver_f5packet_widget_histogramm.dart';
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
  int _resetKey = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = Provider.of<ReceiverNotifier>(context, listen: false);
      notifier.resumeParsingDisplay();
    });
  }

  // Метод для сброса состояния UI
  void _resetUI() {
    setState(() {
      _resetKey++; // Обновляем ключ, чтобы пересоздать виджет
    });
  }

  // Показ сообщения через SnackBar
  void _showSnackBar(BuildContext context, String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // void _resetUIAndStartParsingFile(ReceiverNotifier notifier) {
  //   // Сначала запускаем парсер
  //   notifier.startParsingFile();
  //   _resetUI();
  // }

  // void _resetUIAndStartParsingTcp(ReceiverNotifier notifier, bool parse) {
  //   // Сначала запускаем парсер
  //   notifier.startContinuousParsingTcp(parse);
  //   // _resetUI();
  // }

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
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(),
              Expanded(
                child: Row(
                  children: [
                    // Левый столбец
                    Expanded(
                      child: Column(
                        children: [
                          // Карта занимает всё оставшееся пространство
                          // const Expanded(child: Receiver50PacketMap()),

                          // Виджеты с расстояниями и координатами занимают только минимальное пространство
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Consumer<ReceiverNotifier>(
                                builder: (context, notifier, _) {
                                  return MarkerDistanceDisplay(
                                    markerLocation: notifier.markerLocation,
                                    markerHeight: notifier.markerHeight,
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
                              const Divider(),
                              const Receiver50PacketCoord(),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(
                      thickness: 1.5,
                      indent: 0,
                      endIndent: 0,
                    ),
                    // Правый столбец
                    Expanded(
                      child: Column(
                        children: [
                          ReceiverF5PacketData(),
                          const Divider(),
                          ReceiverF5PacketSatellites(),
                        ],
                      ),
                    ),
                    const VerticalDivider(
                      thickness: 1.5,
                      indent: 0,
                      endIndent: 0,
                    ),
                    const Expanded(
                      child: Column(
                        children: [
                          Expanded(child: Receiver55PacketData()),
                          Divider(),
                          Receiver50PacketAbsV(),
                          Divider(),
                          Receiver50PacketTow(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Consumer<ReceiverNotifier>(
                    builder: (context, notifier, _) => ElevatedButton(
                      onPressed: notifier.isParserActive
                          ? null // Отключаем кнопку, если парсер активен
                          : () async {
                              final isStarted = await notifier.startParsingFile(context); // Передаем context
                              _showSnackBar(context, isStarted ? 'Started parsing file' : 'Parsing failed: file not found');
                            },
                      child: notifier.isParserActive ? const Text('Parsing file...') : const Text('Start Parsing file'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Consumer<ReceiverNotifier>(
                    builder: (context, notifier, _) => ElevatedButton(
                      onPressed: notifier.isParserActive
                          ? () async {
                              bool success = await notifier.stopParsingFile();
                              _showSnackBar(context, success ? 'Stopped parsing file' : 'Parser was not running');
                            }
                          : null, // Отключаем кнопку, если парсер не активен
                      child: const Text('Stop Parsing file'),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Consumer<ReceiverNotifier>(
                    builder: (context, notifier, _) {
                      return ElevatedButton(
                        onPressed: notifier.isParserActive
                            ? null
                            : () async {
                                bool parse = true;
                                final result = await notifier.startContinuousParsingTcp(parse, context); // передача context

                                if (result == 1) {
                                  _showSnackBar(context, 'Started parsing TCP-port successfully');
                                } else if (result == -1) {
                                  bool parse = false;
                                  bool stopResult = await notifier.stopContinuousParsingTcp(parse, context);
                                  _showSnackBar(context, 'Parsing failed or manually stopped');
                                  if (stopResult) {
                                    print('Parsing stopped automatically due to error or timeout');
                                  }
                                }
                              },
                        child: notifier.isParserActive ? const Text('Parsing TCP-port...') : const Text('Start Parsing TCP-port'),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  Consumer<ReceiverNotifier>(
                    builder: (context, notifier, _) {
                      return ElevatedButton(
                        onPressed: notifier.isParserActive
                            ? () async {
                                bool parse = false;
                                bool stopResult = await notifier.stopContinuousParsingTcp(parse, context);
                                _showSnackBar(context, stopResult ? 'Parsing TCP-port stopped successfully' : 'Failed to stop TCP-port parsing');
                              }
                            : null, // Делаем кнопку неактивной, если парсер не запущен
                        child: const Text('Stop Parsing TCP-port'),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      _resetUI();
                      _showSnackBar(context, 'UI rebuilt');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 252, 149, 142),
                    ),
                    child: const Text('Reset UI (After Parse)'),
                  ),
                  const SizedBox(width: 20),
                  const CopyCoordinatesButton(),
                  const SizedBox(width: 20),
                  const RemoveMarkerButton(),
                ],
              ),
              const Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Divider(),
                ReceiverWidgetMarkerTextField(),
              ]))
            ],
          ),
        ),
      ),
    );
  }
}
