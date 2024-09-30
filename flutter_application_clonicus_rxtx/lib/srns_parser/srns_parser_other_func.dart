import 'dart:typed_data';
import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_crc_calc.dart';
import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_packets_packet.dart';
import 'package:flutter_application_clonicus_rxtx/srns_parser/srns_parser_structure.dart';

int findPreamble(Uint8List data) {
  for (int i = 0; i < data.length - 1; i++) {
    if (data[i] == 0x53 && data[i + 1] == 0x52) {
      return i;
    }
  }
  return -1;
}

PacketData? extractPacketData(Uint8List preambleBuffer) {
  if (preambleBuffer.length < 12) {
    // print('Buffer is too small to contain a valid packet');
    return null; // Недостаточно данных для пакета
  }

  int pktPreamble = (preambleBuffer[0] << 8) | preambleBuffer[1];
  int pktSender = (preambleBuffer[2] << 8) | preambleBuffer[3];
  int pktSize = preambleBuffer[4] | (preambleBuffer[5] << 8);
  int pktID = (preambleBuffer[6]) | ((preambleBuffer[7] & 0xF) << 8);
  int pktCnt = (preambleBuffer[7] >> 4) & 0x0F;
  int getPktSize = (pktSize * 4) + 12;

  // Проверяем, что в буфере достаточно данных для пакета
  if (preambleBuffer.length < getPktSize) {
    // print('Not enough data in buffer for full packet. Expected size: $getPktSize, but got: ${preambleBuffer.length}');
    return null; // Пакет неполный
  }

  int pktCrcCalc = computeCRC(preambleBuffer.sublist(0, 8 + pktSize * 4));
  int pktCrc = 8 + pktSize * 4;
  Uint8List packet = preambleBuffer.sublist(0, getPktSize);
  int pktCrcPos = (packet[pktCrc]) | (packet[pktCrc + 1] << 8) | (packet[pktCrc + 2] << 16) | (packet[pktCrc + 3] << 24);

  Uint8List dataBuffer = preambleBuffer.sublist(8, pktCrc);

  return PacketData(
    preamble: pktPreamble,
    sender: pktSender,
    size: pktSize,
    getSize: getPktSize,
    id: pktID,
    counter: pktCnt,
    crcCalc: pktCrcCalc,
    crcPos: pktCrcPos,
    data: dataBuffer,
  );
}

List<Map<String, dynamic>> processPacket(PacketData packetData) {
  String pktIDnew = packetData.id.toRadixString(16).padLeft(4, '0').toLowerCase();

  List<Map<String, dynamic>> parsedPacketData = [];

  switch (pktIDnew) {
    case '00f5':
      // print('F5 packet found');
      parsedPacketData = packetParserF5(packetData.data); // F5 пакет
      break;
    case '0055':
      // print('55 packet found');
      parsedPacketData = packetParser55(packetData.data); // Для пакета 55
      break;
    case '0050':
      // print('50 packet found');
      parsedPacketData = packetParser50(packetData.data); // 50 пакет
      break;
    default:
      // Обработка неизвестного пакета
      break;
  }

  return parsedPacketData;
}
