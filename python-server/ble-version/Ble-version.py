# app.py ? Flask + queue worker + job-status + epd lock
from flask import Flask, request, jsonify
import os
from datetime import datetime
import time
import uuid
from PIL import Image, ImageEnhance
import threading
import queue
from waveshare_epd import epd7in3f
 
# ---------- Config ----------
SAVE_DIR = os.path.expanduser('~/images_wifi_artframe')
os.makedirs(SAVE_DIR, exist_ok=True)
EPD_WIDTH = 800
EPD_HEIGHT = 480
 
# ---------- Flask app ----------
app = Flask(__name__)
 
job_status = {}
status_lock = threading.Lock()
 
# Queue for display jobs
job_queue = queue.Queue()
 
# Locks for e-Paper device operations
epd_lock = threading.Lock()
 
# Initialize e-Paper (single instance)
epd = epd7in3f.EPD()
 
# Optional flag to force error for testing
app.force_error = False
 
# ---------- Helper functions ----------
def make_error_payload(code, message, stage):
    cid = str(uuid.uuid4())
    return {
        "error_code": code,
        "message": str(message)[:200],
        "stage": stage,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "correlation_id": cid
    }
 
def update_job(job_id, **kwargs):
    with status_lock:
        if job_id in job_status:
            job_status[job_id].update(kwargs)
 
# The actual display worker function
def display_worker_loop():
    app.logger.info("Display worker starting...")
    while True:
        job = job_queue.get()  # blocks until job available
        if job is None:
            # sentinel for shutdown
            break
 
        job_id = job['job_id']
        filepath = job['filepath']
        with status_lock:
            job_status[job_id]['status'] = 'processing'
            job_status[job_id]['started_at'] = time.time()
        app.logger.info(f"Worker started job {job_id} -> {filepath}")
 
        start_time = time.time()
        try:
            # For robustness, wrap e-Paper use in a lock so no concurrent epd ops
            with epd_lock:
                # optional: check hardware presence
                if getattr(app, 'force_error', False):
                    raise RuntimeError("forced error (app.force_error=True)")
 
                if not os.path.exists('/dev/spidev0.0'):
                    raise RuntimeError("e-Paper device not connected")
 
                # Open image and display ? ensure size/mode as needed
                img = Image.open(filepath).convert("RGB")
                # If the driver expects a specific size, ensure it
                if img.size != (EPD_WIDTH, EPD_HEIGHT):
                    img = img.resize((EPD_WIDTH, EPD_HEIGHT))
 
                # Do epd sequence
                epd.init()
                # Note: the driver may need specific buffer conversion; original used epd.getbuffer(img)
                epd.display(epd.getbuffer(img))
                epd.sleep()
 
            elapsed = time.time() - start_time
            update_job(job_id, status='done', finished_at=time.time(), elapsed=elapsed)
            app.logger.info(f"Job {job_id} done in {elapsed:.2f}s")
        except Exception as e:
            err = make_error_payload("DISPLAY_FAILED", str(e), "display")
            update_job(job_id, status='error', finished_at=time.time(), elapsed=(time.time()-start_time), error=err)
            app.logger.error(f"Job {job_id} failed: {e}")
        finally:
            # Mark queue task done
            job_queue.task_done()
 
# Start worker thread at import time
worker_thread = threading.Thread(target=display_worker_loop, daemon=True)
worker_thread.start()

# ---------- Routes ----------
@app.route('/status', methods=['GET'])
def status():
    """
    GET /status?job_id=<uuid>
    If job_id provided, return that job's status.
    If not, return summary (pending_count, processing_count).
    """
    job_id = request.args.get('job_id')
    if job_id:
        with status_lock:
            info = job_status.get(job_id)
            if not info:
                return jsonify({'error': 'job_id not found'}), 404
            # safe copy
            resp = {
                'job_id': job_id,
                'status': info.get('status'),
                'filename': info.get('filename'),
                'created_at': info.get('created_at'),
                'started_at': info.get('started_at'),
                'finished_at': info.get('finished_at'),
                'elapsed': info.get('elapsed'),
                'error': info.get('error')
            }
        return jsonify(resp), 200
    else:
        # summary
        with status_lock:
            counts = {'queued': 0, 'processing': 0, 'done': 0, 'error': 0}
            for v in job_status.values():
                counts[v['status']] = counts.get(v['status'], 0) + 1
        return jsonify({'summary': counts}), 200
 
@app.route('/debug/force_error', methods=['POST'])
def set_force_error():
    data = request.get_json() or {}
    app.force_error = bool(data.get('on', False))
    return jsonify({'force_error': app.force_error}), 200
 
@app.route('/upload', methods=['POST'])
def upload_image():
    if 'image' not in request.files:
        return jsonify({'error': 'No image part'}), 400
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400
 
    # Create filename and save BMP after processing
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f'image_{timestamp}.bmp'
    filepath = os.path.join(SAVE_DIR, filename)
 
    try:
        img = Image.open(file.stream).convert("RGB")
        img = img.resize((EPD_WIDTH, EPD_HEIGHT))
        img = ImageEnhance.Brightness(img).enhance(1.3)
        img = ImageEnhance.Color(img).enhance(1.5)
        img = ImageEnhance.Sharpness(img).enhance(2.0)
 
        # create simple palette and dither as before (if desired)
        palette = [
            0,0,0,       # black
            255,255,255, # white
            0,255,0,     # green
            0,0,255,     # blue
            255,0,0,     # red
            255,255,0,   # yellow
            255,128,0    # orange
        ] + [0] * (256*3 - 7*3)
        palette_img = Image.new("P", (1,1))
        palette_img.putpalette(palette)
 
        dithered = img.quantize(palette=palette_img, dither=Image.FLOYDSTEINBERG)
        # Save final BMP
        dithered.save(filepath, format="BMP")
        app.logger.info(f"Saved BMP: {filepath}")
 
        # create job
        job_id = str(uuid.uuid4())
        now_ts = time.time()
        with status_lock:
            job_status[job_id] = {
                'status': 'queued',
                'filename': filename,
                'created_at': now_ts,
                'started_at': None,
                'finished_at': None,
                'elapsed': None,
                'error': None,
                'filepath': filepath
            }
 
        # push to queue
        job_queue.put({'job_id': job_id, 'filepath': filepath})
 
        return jsonify({'message': 'Upload accepted', 'job_id': job_id, 'filename': filename}), 200
 
    except Exception as e:
        app.logger.error(f"Processing failed: {e}")
        return jsonify({'error': 'Image processing failed', 'detail': str(e)}), 500
 
# Graceful shutdown endpoint (optional)
@app.route('/debug/shutdown_worker', methods=['POST'])
def shutdown_worker():
    # Put sentinel None to stop worker (for maintenance)
    job_queue.put(None)
    return jsonify({'message': 'worker shutdown requested'}), 200
 
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
