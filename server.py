#!/usr/bin/env python3
import http.server
import socketserver
import os
import mimetypes

PORT = int(os.environ.get("PORT", 8080))
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web_build")

mimetypes.init()
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("image/svg+xml", ".svg")

class WebAssemblyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

if __name__ == "__main__":
    with ThreadingHTTPServer(("0.0.0.0", PORT), WebAssemblyHandler) as httpd:
        print("=================================================")
        print("🚀 WRAP · 星际远征 Web版 (Python) 本地服务已启动!")
        print(f"🎮 本地游玩地址: http://localhost:{PORT}")
        print(f"🌐 局域网地址:   http://0.0.0.0:{PORT}")
        print("=================================================")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n服务已停止。")
