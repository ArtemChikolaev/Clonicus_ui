import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ssh_provider.dart';

class SSHPage extends StatefulWidget {
  const SSHPage({super.key});

  @override
  SSHPageState createState() => SSHPageState();
}

class SSHPageState extends State<SSHPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => false;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Важно для работы AutomaticKeepAliveClientMixin
    final sshProvider = Provider.of<SSHProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Receiver Controller'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: sshProvider.ipController,
              decoration: const InputDecoration(labelText: 'Enter IP (e.g., 125)'),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: sshProvider.isConnected ? null : sshProvider.connectSSH,
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: sshProvider.isConnected ? sshProvider.disconnectSSH : null,
                  child: const Text('Disconnect'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: sshProvider.isConnected && !sshProvider.isReceiverRunning ? sshProvider.startReceiver : null,
                  child: const Text('Start Receiver'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: sshProvider.isConnected && sshProvider.isReceiverRunning ? sshProvider.stopReceiver : null,
                  child: const Text('Stop Receiver'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: sshProvider.isConnected ? sshProvider.readLogFile : null,
                  child: const Text('Read Log'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: sshProvider.clearOutput,
                  child: const Text('Clear Output'),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    sshProvider.scrollController.jumpTo(
                      sshProvider.scrollController.position.maxScrollExtent,
                    );
                  });
                  return SingleChildScrollView(
                    controller: sshProvider.scrollController,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Text(sshProvider.output),
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
}
