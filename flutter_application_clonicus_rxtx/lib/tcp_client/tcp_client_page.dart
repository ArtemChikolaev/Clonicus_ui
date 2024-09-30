import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tcp_provider.dart';

class TCPClientPage extends StatefulWidget {
  const TCPClientPage({super.key});

  @override
  TCPClientPageState createState() => TCPClientPageState();
}

class TCPClientPageState extends State<TCPClientPage> {
  late TextEditingController _ipSuffixController;
  late TextEditingController _portController;
  final ScrollController _scrollController = ScrollController(); // Добавил ScrollController

  @override
  void initState() {
    super.initState();
    final tcpProvider = Provider.of<TCPProvider>(context, listen: false);

    _ipSuffixController = TextEditingController(text: tcpProvider.ipSuffix);
    _portController = TextEditingController(text: tcpProvider.port.toString());

    // Автопрокрутка вниз при обновлении данных
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tcpProvider = Provider.of<TCPProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TCP Client'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _ipSuffixController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter IP (e.g., 125)',
              ),
              onChanged: (value) {
                tcpProvider.setIpSuffix(value);
              },
            ),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter Port (e.g., 3490)',
              ),
              onChanged: (value) {
                tcpProvider.setPort(int.tryParse(value) ?? 8080);
              },
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: tcpProvider.isConnected
                      ? null
                      : () {
                          final ip = '192.168.0.${_ipSuffixController.text}';
                          final port = int.tryParse(_portController.text) ?? 8080;
                          tcpProvider.connect(ip, port);
                        },
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: tcpProvider.isConnected ? tcpProvider.disconnect : null,
                  child: const Text('Disconnect'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: tcpProvider.clearOutput,
                  child: const Text('Clear Output'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: tcpProvider.isRecording
                      ? () {
                          tcpProvider.stopRecording();
                          _showSnackbar('Recording stopped');
                        }
                      : () {
                          tcpProvider.startRecording();
                          _showSnackbar('Recording started');
                        },
                  child: Text(tcpProvider.isRecording ? 'Stop Recording' : 'Start Recording'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    tcpProvider.scrollController.jumpTo(
                      tcpProvider.scrollController.position.maxScrollExtent,
                    );
                  });
                  return SingleChildScrollView(
                    controller: tcpProvider.scrollController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Text(tcpProvider.output),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipSuffixController.dispose();
    _portController.dispose();
    _scrollController.dispose(); // Освобождаем ресурсы ScrollController
    super.dispose();
  }
}
