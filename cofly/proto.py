import json
import struct
import time
import uuid

import pbbp2_pb2


def _encode_varint(value):
    """Encode an unsigned integer as a protobuf varint."""
    parts = []
    while value > 0x7F:
        parts.append((value & 0x7F) | 0x80)
        value >>= 7
    parts.append(value & 0x7F)
    return bytes(parts)


def _encode_field_varint(field_number, value):
    """Encode a varint field (wire type 0)."""
    tag = (field_number << 3) | 0
    return _encode_varint(tag) + _encode_varint(value)


def _encode_field_bytes(field_number, data):
    """Encode a length-delimited field (wire type 2)."""
    if isinstance(data, str):
        data = data.encode()
    tag = (field_number << 3) | 2
    return _encode_varint(tag) + _encode_varint(len(data)) + data


def _encode_header(key, value):
    """Encode a pbbp2.Header submessage."""
    inner = _encode_field_bytes(1, key) + _encode_field_bytes(2, str(value))
    return inner


def make_frame(*, seq_id=0, method=0, headers=None, payload=b"", service=1):
    """Manually encode a pbbp2.Frame to ensure zero-valued fields are present.
    Proto3 omits zero values, but the Lark SDK uses proto2 and requires them."""
    log_id = int(time.time() * 1000)

    buf = b""
    buf += _encode_field_varint(1, seq_id)       # SeqID (uint64, required by SDK)
    buf += _encode_field_varint(2, log_id)        # LogID (uint64, required by SDK)
    buf += _encode_field_varint(3, service)       # service (int32, required by SDK)
    buf += _encode_field_varint(4, method)        # method (int32, required by SDK)
    if headers:
        for k, v in headers.items():
            header_bytes = _encode_header(k, v)
            buf += _encode_field_bytes(5, header_bytes)  # headers (repeated Header)
    if isinstance(payload, str):
        payload = payload.encode()
    if payload:
        buf += _encode_field_bytes(8, payload)    # payload (bytes)
    buf += _encode_field_bytes(9, str(log_id))    # LogIDNew (string)
    return buf


def parse_frame(data: bytes) -> pbbp2_pb2.Frame:
    frame = pbbp2_pb2.Frame()
    frame.ParseFromString(data)
    return frame


def get_header(frame: pbbp2_pb2.Frame, key: str) -> str:
    for h in frame.headers:
        if h.key == key:
            return h.value
    return ""


def make_pong_frame(ping_frame: pbbp2_pb2.Frame) -> bytes:
    # SDK parses pong payload as JSON to update ClientConfig
    pong_payload = json.dumps({
        "PingInterval": 120,
        "ReconnectCount": 10,
        "ReconnectInterval": 3,
        "ReconnectNonce": 5,
    })
    return make_frame(
        seq_id=ping_frame.SeqID,
        method=0,
        headers={"type": "pong"},
        payload=pong_payload,
        service=ping_frame.service,
    )


def make_event_frame(event_json: dict, seq_id: int = 0) -> bytes:
    message_id = event_json.get("event", {}).get("message", {}).get("message_id", "")
    payload = json.dumps(event_json).encode()
    return make_frame(
        seq_id=seq_id,
        method=1,
        headers={
            "type": "event",
            "message_id": message_id,
            "sum": "1",
            "seq": "0",
        },
        payload=payload,
    )
