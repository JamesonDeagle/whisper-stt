#!/usr/bin/env python3
"""Whisper STT Daemon — local speech-to-text with pre-loaded MLX model.

HTTP server on 127.0.0.1:19876:
  POST /toggle  — start/stop recording; returns transcribed text on stop
  POST /cancel  — cancel recording without transcription
  GET  /status  — current state + active model
  GET  /models  — list available models
  POST /model   — switch model (body: {"model": "short_name"})
"""

import json
import logging
import sys
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

import numpy as np
import sounddevice as sd

MODELS = {
    "turbo": "mlx-community/whisper-large-v3-turbo",
    "medium": "mlx-community/whisper-medium-mlx",
    "large": "mlx-community/whisper-large-v3-mlx",
}

DEFAULT_MODEL = "turbo"
SAMPLE_RATE = 16000
PORT = 19876
HOST = "127.0.0.1"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    stream=sys.stderr,
)
log = logging.getLogger("whisper-stt")

lock = threading.Lock()
state = {
    "status": "loading",
    "recording": False,
    "audio_chunks": [],
    "active_model": DEFAULT_MODEL,
}


def load_model(name=None):
    if name is None:
        name = state["active_model"]
    repo = MODELS[name]
    log.info("Loading model: %s (%s)", name, repo)
    with lock:
        state["status"] = "loading"
    import mlx_whisper
    silence = np.zeros(SAMPLE_RATE, dtype=np.float32)
    try:
        mlx_whisper.transcribe(silence, path_or_hf_repo=repo)
        with lock:
            state["active_model"] = name
            state["status"] = "idle"
        log.info("Model '%s' loaded", name)
        return True
    except Exception as e:
        log.error("Failed to load model '%s': %s", name, e)
        with lock:
            state["status"] = "idle"
        return False


def audio_callback(indata, frames, time_info, status):
    if status:
        log.warning("sounddevice: %s", status)
    if state["recording"]:
        state["audio_chunks"].append(indata[:, 0].copy())


audio_stream = sd.InputStream(
    samplerate=SAMPLE_RATE,
    channels=1,
    dtype="float32",
    callback=audio_callback,
    blocksize=1024,
)


def transcribe(audio):
    import mlx_whisper
    repo = MODELS[state["active_model"]]
    result = mlx_whisper.transcribe(audio, path_or_hf_repo=repo)
    return result.get("text", "").strip()


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/toggle":
            self._toggle()
        elif self.path == "/cancel":
            self._cancel()
        elif self.path == "/model":
            self._switch_model()
        else:
            self.send_error(404)

    def do_GET(self):
        if self.path == "/status":
            self._respond({
                "status": state["status"],
                "model": state["active_model"],
            })
        elif self.path == "/models":
            self._respond({
                "active": state["active_model"],
                "available": list(MODELS.keys()),
            })
        else:
            self.send_error(404)

    def _switch_model(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode() if length else ""
        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            self._respond({"error": "Invalid JSON"})
            return

        name = data.get("model", "")
        if name not in MODELS:
            self._respond({"error": f"Unknown model: {name}", "available": list(MODELS.keys())})
            return

        if name == state["active_model"]:
            self._respond({"status": "ok", "model": name, "message": "Already active"})
            return

        if state["status"] != "idle":
            self._respond({"error": "Cannot switch while " + state["status"]})
            return

        ok = load_model(name)
        if ok:
            self._respond({"status": "ok", "model": name})
        else:
            self._respond({"error": f"Failed to load {name} (not downloaded?)", "model": state["active_model"]})

    def _toggle(self):
        with lock:
            if state["status"] == "loading":
                self._respond({"status": "loading", "error": "Model still loading"})
                return
            if state["status"] == "transcribing":
                self._respond({"status": "transcribing", "error": "Busy"})
                return

            if not state["recording"]:
                state["audio_chunks"] = []
                state["recording"] = True
                state["status"] = "recording"
                log.info("Recording started")
                self._respond({"status": "recording"})
                return
            else:
                state["recording"] = False
                state["status"] = "transcribing"
                chunks = state["audio_chunks"]
                state["audio_chunks"] = []

        if not chunks:
            log.warning("No audio captured")
            with lock:
                state["status"] = "idle"
            self._respond({"status": "done", "text": ""})
            return

        audio = np.concatenate(chunks)
        duration = len(audio) / SAMPLE_RATE
        log.info("Transcribing %.1fs of audio...", duration)

        t0 = time.time()
        text = transcribe(audio)
        elapsed = time.time() - t0
        log.info("Done in %.2fs: %s", elapsed, text[:120])

        with lock:
            state["status"] = "idle"
        self._respond({"status": "done", "text": text})

    def _cancel(self):
        with lock:
            state["recording"] = False
            state["audio_chunks"] = []
            state["status"] = "idle"
        log.info("Cancelled")
        self._respond({"status": "idle"})

    def _respond(self, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    audio_stream.start()
    log.info("Audio stream started (device=%s, rate=%d)", sd.default.device[0], SAMPLE_RATE)
    threading.Thread(target=load_model, daemon=True).start()
    server = HTTPServer((HOST, PORT), Handler)
    log.info("Listening on %s:%d", HOST, PORT)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Shutting down")
    finally:
        audio_stream.stop()
        server.server_close()
