import 'package:flutter/material.dart';
import 'package:dartssh2_plus/dartssh2.dart';

class SSHProvider with ChangeNotifier {
  SSHClient? client;
  SSHSession? receiverSession;
  String output = '';
  bool isConnected = false;
  bool isReceiverRunning = false;
  TextEditingController ipController = TextEditingController();
  ScrollController scrollController = ScrollController();

  SSHProvider();

  void connectSSH() async {
    try {
      final socket = await SSHSocket.connect('192.168.0.${ipController.text}', 22);
      client = SSHClient(
        socket,
        username: 'root',
        onPasswordRequest: () => 'root',
      );
      isConnected = true;
      output += 'Connected to 192.168.0.${ipController.text}\n';
      notifyListeners();
    } catch (e) {
      output += 'Error: $e\n';
      notifyListeners();
    }
  }

  void disconnectSSH() {
    client?.close();
    client = null;
    isConnected = false;
    output += 'Disconnected from 192.168.0.${ipController.text}\n';
    notifyListeners();
  }

  void startReceiver() async {
    if (client != null) {
      receiverSession = await client!.execute('/tmp/receiver');
      isReceiverRunning = true;
      receiverSession!.stdout.listen((data) {
        output += String.fromCharCodes(data);
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        notifyListeners();
      });
      receiverSession!.stderr.listen((data) {
        output += 'Error: ${String.fromCharCodes(data)}';
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        notifyListeners();
      });
    }
  }

  void stopReceiver() async {
    if (client != null) {
      try {
        final findPidSession = await client!.execute('pidof receiver');
        String pidOutput = '';
        await for (var data in findPidSession.stdout) {
          pidOutput += String.fromCharCodes(data);
        }
        final pid = pidOutput.trim();

        if (pid.isNotEmpty) {
          final killSession = await client!.execute('kill -9 $pid');
          await killSession.done;

          final checkPidSession = await client!.execute('pidof receiver');
          String checkPidOutput = '';
          await for (var data in checkPidSession.stdout) {
            checkPidOutput += String.fromCharCodes(data);
          }
          final checkPid = checkPidOutput.trim();

          if (checkPid.isEmpty) {
            output += '\nReceiver stopped successfully\n';
          } else {
            output += '\nFailed to stop receiver. Process is still running (PID: $checkPid)\n';
          }
        } else {
          output += '\nFailed to find receiver process. PID not found.\n';
        }
        isReceiverRunning = false;
        notifyListeners();
      } catch (e) {
        output += '\nError stopping receiver: $e\n';
        notifyListeners();
      }
    }
  }

  void readLogFile() async {
    if (client != null) {
      try {
        final logSession = await client!.execute('cat /tmp/receiver.log');
        String logContent = '';
        await for (var data in logSession.stdout) {
          logContent += String.fromCharCodes(data);
        }
        output += '\nReceiver Log:\n$logContent\n';
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        notifyListeners();
      } catch (e) {
        output += '\nError reading log: $e\n';
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        notifyListeners();
      }
    }
  }

  void clearOutput() {
    output = '';
    notifyListeners();
  }

  @override
  void dispose() {
    client?.close();
    super.dispose();
  }
}
