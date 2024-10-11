import 'package:flutter/material.dart';
import 'package:flutter_application_clonicus_rxtx/receive/receiver_notifier.dart';
import 'package:provider/provider.dart';
import 'bash/bash_terminal_page.dart';
import 'tcp_client/tcp_provider.dart';
import 'receive/receiver_page.dart';
import 'ssh/ssh_provider.dart';
import 'ssh/ssh_page.dart';
import 'tcp_client/tcp_client_page.dart';
import 'transceive/transceiver_page.dart';
import 'package:desktop_window/desktop_window.dart'; // фиксированный размер окна приложения
import 'dart:io'; // Для проверки платформы

void main() async {
  // Инициализация WidgetsBinding
  WidgetsFlutterBinding.ensureInitialized();

  // Устанавливаем минимальные размеры окна для десктопных платформ
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await DesktopWindow.setMinWindowSize(const Size(1728, 972));
  }

  runApp(const ClonicusModded());
}

// void main() => runApp(const ClonicusModded());

class ClonicusModded extends StatelessWidget {
  const ClonicusModded({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TCPProvider()),
        ChangeNotifierProvider(create: (_) => SSHProvider()),
        ChangeNotifierProvider(create: (_) => ReceiverNotifier(TCPProvider())),
      ],
      child: const MaterialApp(
        home: HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clonicus GNSS software'),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 211, 186, 253),
              ),
              child: Text(
                'Clonicus GNSS software Navigation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text('Bash terminal'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BashTerminalPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_remote),
              title: const Text('SSH Receiver Controller'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SSHPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('TCP Client'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TCPClientPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.wifi_tethering),
              title: const Text('Clonicus Transceive'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TransceivePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.radio),
              title: const Text('Clonicus Receive'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReceiverPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: const Center(
        child: Text('Welcome to Clonicus GNSS software'),
      ),
    );
  }
}
