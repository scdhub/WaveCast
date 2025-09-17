# -*- coding: utf-8 -*-

import os
import time
import threading
import uuid
import logging
import json
import binascii
from bluezero import adapter as bz_adapter
from bluezero import peripheral
from io import BytesIO
from datetime import datetime
from flask import Flask
from PIL import Image, ImageEnhance

#保存する場所
SAVE_DIR = os.path.expanduser('~/images_ble_artframe')
os.makedirs(SAVE_DIR, exist_ok=True)

#EOF 
JPEG_EOI = b'\xff\xd9'
PNG_IEND = b'\x00\x00\x00\x00IEND\xaeB`\x82'

#パレット定義
PALETTE_LIST = [
    0, 0, 0,        # black
    255, 255, 255,  # white
    0, 255, 0,      # green
    0, 0, 255,      # blue
    255, 0, 0,      # red
    255, 255, 0,    # yellow
    255, 128, 0     # orange
] + [0] * (256 * 3 - 7 * 3)

#ログ情報
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ble-epaper")

app = Flask(__name__)
app.display_status = 'idle'
app.display_count = 0
app.last_elapsed = None

#状態
status_notify_char = None
ble_peripheral_global = None
client_ready = False


receive_buffer = bytearray()
buffer_lock = threading.Lock()
receive_start_time = None

#モジュールがない場合はここでエラーを出す。
try:
    from waveshare_epd import epd7in3f
    epd = epd7in3f.EPD()
except Exception:
    epd = None
    logger.warning("waveshare_epd not available or e-Paper not connected. Display will be skipped.")

#画像の読み込みから編集
def process_and_save_image_from_bytes(image_bytes: bytes) -> str:
    #RGBに変換し、リサイズ+明るさ+色+シャープネスの調整を行う
    try:
        buf = BytesIO(image_bytes)
        img = Image.open(buf).convert("RGB")
        img = img.resize((800, 480))
        img = ImageEnhance.Brightness(img).enhance(1.3)
        img = ImageEnhance.Color(img).enhance(1.5)
        img = ImageEnhance.Sharpness(img).enhance(2.0)

        pal_img = Image.new("P", (1, 1))
        pal_img.putpalette(PALETTE_LIST)
        dithered = img.quantize(palette=pal_img, dither=Image.FLOYDSTEINBERG)
        processed = dithered.convert("RGB")

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"image_{timestamp}.bmp"
        filepath = os.path.join(SAVE_DIR, filename)
        #BMPに変換
        processed.save(filepath, format='BMP')
        logger.info("Saved processed BMP: %s", filepath)
        return filepath
    except Exception:
        logger.exception("Image processing failed")
        raise


#書き込み時のハンドラ　スマホから書き込みが来たら呼ばれる　
def on_write(value, options):
    global receive_start_time, receive_buffer, client_ready
    logger.info("on_write called with value=%r", value)

    chunk = bytes(value) if isinstance(value, list) else bytes(value)

    if chunk == b'READY':
        client_ready = True
        logger.info("on_write: Received READY from central; client_ready=True")
        return

    if chunk == b'TEST_NOTIFY':
        logger.info("on_write: Received TEST_NOTIFY; sending test notify")
        try:
            send_notify_bytes(b'HelloFromPi')
        except Exception:
            logger.exception("Failed to send test notify")
        return

    with buffer_lock:
        if receive_start_time is None:
            receive_start_time = time.time()

        receive_buffer.extend(chunk)
        logger.debug("Received chunk: %d bytes (total: %d)", len(chunk), len(receive_buffer))

        if receive_buffer.endswith(JPEG_EOI) or receive_buffer.endswith(PNG_IEND):
            logger.info("Image terminator detected (total bytes: %d). Starting processing...", len(receive_buffer))
            assembled = bytes(receive_buffer)
            receive_buffer.clear()
            threading.Thread(target=_handle_complete_image, args=(assembled,), daemon=True).start()


def _handle_complete_image(image_bytes: bytes):
    try:
        filepath = process_and_save_image_from_bytes(image_bytes)
        #　e-paper表示用スレッド作成
        threading.Thread(target=display_on_epaper, args=(filepath,), daemon=True).start()
    except Exception:
        logger.exception("Failed to handle complete image")


#　エラー情報をJSONで返す。
def make_error_payload(error_code: str, message: str, source: str) -> dict:
    return {
        "error_code": error_code,
        "message": message,
        "source": source,
        "correlation_id": str(uuid.uuid4())
    }

def display_on_epaper(image_path: str):
    try:
        if getattr(app, 'force_display_error', False):
            raise RuntimeError("Forced display error for test")

        if epd is None or not os.path.exists('/dev/spidev0.0'):
            raise RuntimeError("e-Paper device not ready")

        start_time = time.time()
        epd.init()
        img = Image.open(image_path)
        # 画像配信
        epd.display(epd.getbuffer(img))
        epd.sleep()

        elapsed = time.time() - start_time
        app.last_elapsed = elapsed
        app.display_count += 1

        #成功時は通知がいく・・・
        send_notify_bytes(b'1')
        logger.info("display_on_epaper: success notify sent")

    except Exception as e:
        err = make_error_payload("DISPLAY_FAILED", str(e), "display")
        app.last_error = err
        logger.exception("e-Paper display failed (cid=%s)", err['correlation_id'])
        
        # クライアントへ伝えるための通知
        notify_obj = {
            "callbackName": "onSendImageToDeviceFailed",
            "message": "e-paper not found",
            "error": {
                "code": err['error_code'],
                "correlation_id": err['correlation_id']
            }
        }
        payload = json.dumps(notify_obj).encode('utf-8')
        send_notify_bytes(payload)

#　BLEID
SERVICE_UUID = '12345678-1234-5678-1234-56789abcdef0'
#　書き込み用
CHAR_UUID    = '12345678-1234-5678-1234-55555abcdef1'
# 通知用
STATUS_NOTIFY_UUID = '12345678-1234-5678-1234-55555abcdef2'


def setup_ble_and_advertise():
    global ble_peripheral_global, status_notify_char

    adapter_addr = None
    try:
        adapters = list(bz_adapter.Adapter.available())
        if adapters:
            adapter_addr = adapters[0].address
            logger.info("Using Bluetooth adapter: %s", adapter_addr)
        else:
            adapter_addr = os.environ.get('BLE_ADAPTER_ADDR')
    except Exception as ex:
        logger.exception("Failed to list adapters: %s", ex)
        adapter_addr = os.environ.get('BLE_ADAPTER_ADDR')

    if not adapter_addr:
        raise RuntimeError("Bluetooth adapter not found. Set BLE_ADAPTER_ADDR.")

    ble_peripheral = peripheral.Peripheral(
        adapter_address=adapter_addr,
        local_name='PiBLE-Bluezero'
    )

    ble_peripheral.add_service(srv_id=1, uuid=SERVICE_UUID, primary=True)

    ble_peripheral.add_characteristic(
        srv_id=1,
        chr_id=2,
        uuid=CHAR_UUID,
        value=bytearray(),
        notifying=False,
        flags=['write', 'write-without-response'],
        write_callback=on_write
    )

    status_notify_char = ble_peripheral.add_characteristic(
        srv_id=1,
        chr_id=1,
        uuid=STATUS_NOTIFY_UUID,
        value=bytearray(),
        notifying=True,
        flags=['notify']
        #flags=['notify','read']　
    )

    logger.info("Notify characteristic added with UUID=%s", STATUS_NOTIFY_UUID)
    ble_peripheral_global = ble_peripheral

    logger.info("Starting BLE Peripheral (advertising)...")
    ble_peripheral.publish()

    while True:
        time.sleep(1)


def send_notify_bytes(payload: bytes) -> bool:
    global status_notify_char

    if status_notify_char is None:
        logger.warning("send_notify_bytes: status_notify_char is None; cannot notify")
        return False
        # notifyはリスト形式のバイト列で送信する必要があるので変換
    try:
        if hasattr(status_notify_char, 'set_value'):
            payload_list = list(payload)
            status_notify_char.set_value(payload_list)
            logger.info("send_notify_bytes: sent %d bytes", len(payload))
            return True
            
    except Exception:
        logger.exception("send_notify_bytes failed")
    return False


def main():
    setup_ble_and_advertise()

if __name__ == '__main__':
    main()

