import 'dart:convert';
import 'dart:typed_data';

/// pbbp2 Frame codec — matches the cofly backend's proto.py / pbbp2.proto
///
/// Frame fields (proto3):
///   1: SeqID   (uint64, varint)
///   2: LogID   (uint64, varint)
///   3: service (int32,  varint)
///   4: method  (int32,  varint)
///   5: headers (repeated Header submessage, length-delimited)
///   6: payloadEncoding (string)
///   7: payloadType     (string)
///   8: payload (bytes, length-delimited)
///   9: LogIDNew (string, length-delimited)
///
/// Header submessage:
///   1: key   (string)
///   2: value (string)

class PbbpHeader {
  final String key;
  final String value;
  PbbpHeader(this.key, this.value);
}

class PbbpFrame {
  final int seqId;
  final int logId;
  final int service;
  final int method;
  final List<PbbpHeader> headers;
  final Uint8List payload;
  final String logIdNew;

  PbbpFrame({
    this.seqId = 0,
    this.logId = 0,
    this.service = 0,
    this.method = 0,
    this.headers = const [],
    Uint8List? payload,
    this.logIdNew = '',
  }) : payload = payload ?? Uint8List(0);

  String? getHeader(String key) {
    for (final h in headers) {
      if (h.key == key) return h.value;
    }
    return null;
  }

  String get payloadString => utf8.decode(payload);
}

// ==================== Encoding ====================

Uint8List _encodeVarint(int value) {
  if (value < 0) value = 0;
  final bytes = <int>[];
  do {
    int b = value & 0x7F;
    value >>= 7;
    if (value > 0) b |= 0x80;
    bytes.add(b);
  } while (value > 0);
  return Uint8List.fromList(bytes);
}

Uint8List _encodeFieldVarint(int fieldNumber, int value) {
  final tag = (fieldNumber << 3) | 0; // wire type 0
  return Uint8List.fromList([..._encodeVarint(tag), ..._encodeVarint(value)]);
}

Uint8List _encodeFieldBytes(int fieldNumber, List<int> data) {
  final tag = (fieldNumber << 3) | 2; // wire type 2
  return Uint8List.fromList([
    ..._encodeVarint(tag),
    ..._encodeVarint(data.length),
    ...data,
  ]);
}

Uint8List _encodeFieldString(int fieldNumber, String s) {
  return _encodeFieldBytes(fieldNumber, utf8.encode(s));
}

Uint8List _encodeHeader(String key, String value) {
  // Header submessage: field 1 = key, field 2 = value
  return Uint8List.fromList([
    ..._encodeFieldString(1, key),
    ..._encodeFieldString(2, value),
  ]);
}

/// Encode a pbbp2.Frame to binary, matching proto.py's make_frame.
Uint8List makeFrame({
  int seqId = 0,
  int method = 0,
  Map<String, String>? headers,
  List<int>? payload,
  int service = 1,
}) {
  final logId = DateTime.now().millisecondsSinceEpoch;
  final buf = BytesBuilder();

  buf.add(_encodeFieldVarint(1, seqId));    // SeqID
  buf.add(_encodeFieldVarint(2, logId));    // LogID
  buf.add(_encodeFieldVarint(3, service));  // service
  buf.add(_encodeFieldVarint(4, method));   // method

  if (headers != null) {
    for (final entry in headers.entries) {
      final headerBytes = _encodeHeader(entry.key, entry.value);
      buf.add(_encodeFieldBytes(5, headerBytes));
    }
  }

  if (payload != null && payload.isNotEmpty) {
    buf.add(_encodeFieldBytes(8, payload));
  }

  buf.add(_encodeFieldString(9, logId.toString())); // LogIDNew

  return buf.toBytes();
}

/// Build a ping frame.
Uint8List makePingFrame({int seqId = 1}) {
  return makeFrame(
    seqId: seqId,
    method: 0,
    headers: {'type': 'ping'},
  );
}

// ==================== Decoding ====================

class _VarintResult {
  final int value;
  final int bytesRead;
  _VarintResult(this.value, this.bytesRead);
}

_VarintResult _decodeVarint(Uint8List data, int offset) {
  int result = 0;
  int shift = 0;
  int bytesRead = 0;
  while (offset < data.length) {
    final b = data[offset];
    result |= (b & 0x7F) << shift;
    offset++;
    bytesRead++;
    shift += 7;
    if ((b & 0x80) == 0) break;
  }
  return _VarintResult(result, bytesRead);
}

/// Parse a pbbp2.Frame from binary data.
PbbpFrame parseFrame(Uint8List data) {
  int seqId = 0;
  int logId = 0;
  int service = 0;
  int method = 0;
  final headers = <PbbpHeader>[];
  Uint8List payload = Uint8List(0);
  String logIdNew = '';

  int offset = 0;
  while (offset < data.length) {
    final tagResult = _decodeVarint(data, offset);
    offset += tagResult.bytesRead;
    final fieldNumber = tagResult.value >> 3;
    final wireType = tagResult.value & 0x07;

    if (wireType == 0) {
      // Varint
      final valResult = _decodeVarint(data, offset);
      offset += valResult.bytesRead;
      switch (fieldNumber) {
        case 1: seqId = valResult.value; break;
        case 2: logId = valResult.value; break;
        case 3: service = valResult.value; break;
        case 4: method = valResult.value; break;
      }
    } else if (wireType == 2) {
      // Length-delimited
      final lenResult = _decodeVarint(data, offset);
      offset += lenResult.bytesRead;
      final fieldData = data.sublist(offset, offset + lenResult.value);
      offset += lenResult.value;

      switch (fieldNumber) {
        case 5: // headers (repeated Header submessage)
          final h = _parseHeader(Uint8List.fromList(fieldData));
          if (h != null) headers.add(h);
          break;
        case 6: // payloadEncoding (ignored)
          break;
        case 7: // payloadType (ignored)
          break;
        case 8: // payload
          payload = Uint8List.fromList(fieldData);
          break;
        case 9: // LogIDNew
          logIdNew = utf8.decode(fieldData);
          break;
      }
    } else {
      // Unknown wire type — skip (best effort)
      break;
    }
  }

  return PbbpFrame(
    seqId: seqId,
    logId: logId,
    service: service,
    method: method,
    headers: headers,
    payload: payload,
    logIdNew: logIdNew,
  );
}

PbbpHeader? _parseHeader(Uint8List data) {
  String key = '';
  String value = '';
  int offset = 0;
  while (offset < data.length) {
    final tagResult = _decodeVarint(data, offset);
    offset += tagResult.bytesRead;
    final fieldNumber = tagResult.value >> 3;
    final wireType = tagResult.value & 0x07;

    if (wireType == 2) {
      final lenResult = _decodeVarint(data, offset);
      offset += lenResult.bytesRead;
      final fieldData = data.sublist(offset, offset + lenResult.value);
      offset += lenResult.value;
      if (fieldNumber == 1) {
        key = utf8.decode(fieldData);
      } else if (fieldNumber == 2) {
        value = utf8.decode(fieldData);
      }
    } else {
      break;
    }
  }
  if (key.isNotEmpty) return PbbpHeader(key, value);
  return null;
}
