from flask import Flask, request, jsonify
import os
from datetime import datetime
import time
from PIL import Image
import threading
from PIL import Image, ImageEnhance
from waveshare_epd import epd7in3f
import uuid

app = Flask(__name__)
app.display_status = 'idle'

# errorを返す
@app.route('/status', methods=['GET'])
def status():
    return jsonify({
        'status': app.display_status,
        'elapsed_time': getattr(app, 'last_elapsed', None),
        'last_error': getattr(app, 'last_error', None)
    }), 200
    
@app.route('/debug/force_error', methods=['POST'])
def set_force_error():
    # curl -X POST http://<pi>:5000/debug/force_error -d '{"on": true}'
    data = request.get_json() or {}
    app.force_error = bool(data.get('on', True))
    #app.force_error = bool(data.get('on', False))
    return jsonify({'force_error': app.force_error}), 200

# 保存場所
SAVE_DIR = os.path.expanduser('~/images_wifi_artframe')
os.makedirs(SAVE_DIR, exist_ok=True)

# Initialize the e-Paper display
epd = epd7in3f.EPD()

# static変数：アップロード回数で処理切り替えも可能
app.display_count = 0

# エラー
def make_error_payload(code, message, stage):
    cid = str(uuid.uuid4())
    return {
        "error_code": code,
        "message": message[:200],
        "stage": stage,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "correlation_id": cid
    }


def resize_and_display_on_epaper(image_path: str):
    app.display_status = 'processing'
    
    #resize nodevice-skip  cleag
    try:
        if getattr(app, 'force_error', False):
            raise RuntimeError("強制エラー")
        if not os.path.exists('/dev/spidev0.0'):
             raise RuntimeError("e-Paper device not connected")
             
        #epd = epaper dusplay 
        start_time = time.time()
        
        #  initが失敗するときのケースを確認するための処理を追加
        epd.init()
        
        # 追加
        #if not ret :　
        #alpp.display_status = 'error'
        #app.logger.error(f"e-Paper display failed: {e}")
        #return
        
        #epd.Clear()
        #3color RGB
        #img = Image.open(image_path).convert("RGB")
        img = Image.open(image_path)
        # Send to display buffer
        epd.display(epd.getbuffer(img))
        epd.sleep()
        #epd.init()
        
        elapsed_time = time.time() - start_time
        app.last_elapsed = elapsed_time
        app.display_status = 'done'
        
    except Exception as e:
        user_msg = "電子ペーパーに配信できませんでした。: " + str(e)
        err = make_error_payload(
            "DISPLAY_FAILED",
            user_msg,
            "display"
        )
        app.last_error = err
        app.display_status = 'error'
        app.logger.error(f"e-Paper display failed: {e}")
        #raise
        return
        
@app.route('/upload', methods=['POST'])
def upload_image():

    if 'image' not in request.files:
        return jsonify({'error': 'No image part'}), 400

    if not hasattr(resize_and_display_on_epaper, "itest"):
        resize_and_display_on_epaper.itest = 0

    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
        
    # ファイル名変更
    ext = '.bmp'
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'image_{timestamp}{ext}'
    filepath = os.path.join(SAVE_DIR, filename)
    app.logger.info(f"Saved BMP: {filepath}")

    try:
        #画像処理を行う

        img = Image.open(file.stream).convert("RGB")
        img = img.resize((800, 480))
        img = ImageEnhance.Brightness(img).enhance(1.3)
        img = ImageEnhance.Color(img).enhance(1.5)
        img = ImageEnhance.Sharpness(img).enhance(2.0)
        app.logger.info(f"Received format: {img.format}, size: {img.size}, mode: {img.mode}")
        img.save(filepath, format="BMP")
        app.logger.info(f"Saved BMP: {filepath}")
        
        # カラーパレット
        palette = [
            0,0,0,       # black
            255,255,255, # white 255,255,255
            0,255,0,     # green
            0,0,255,     # blue
            255,0,0,     # red
            255,255,0,   # yellow
            255,128,0    # orange
        ] + [0] * (256*3 - 7*3)

        palette_img = Image.new("P", (1,1))
        palette_img.putpalette(palette)

        # Quantize and dither, then convert back to RGB
        #dithered = img.quantize(palette=palette_img, dither=Image.FLOYDSTEINBERG).convert("RGB")
        dithered = img.quantize(palette=palette_img, dither=Image.FLOYDSTEINBERG)

        if resize_and_display_on_epaper.itest % 2 == 0:
            print("on")
            #　ここで保存
            dithered.save(filepath, format="BMP")
            app.logger.info(f"Saved BMP: {filename}")
        else:
            print("off")

        resize_and_display_on_epaper.itest += 1

        # 別スレッド
        threading.Thread(target=resize_and_display_on_epaper, args=(filepath,), daemon=True).start()
        return jsonify({'message': 'Processed and display started', 'filename': filename}), 200

    except Exception as e:
        app.logger.error(f"Processing failed: {e}")
        return jsonify({'error': 'Image processing failed'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
