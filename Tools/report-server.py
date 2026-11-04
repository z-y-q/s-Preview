#!/usr/bin/env python3
# 自报告接收服务器：把预览页面的渲染结果记入日志供断言
import http.server
import socketserver
import sys
from urllib.parse import urlparse, unquote

PORT = 47719
LOG = sys.argv[1] if len(sys.argv) > 1 else "TestResults/report.log"

class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        u = urlparse(self.path)
        if u.path.startswith("/report"):
            with open(LOG, "a") as f:
                f.write("REPORT " + unquote(u.query) + "\n")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *a):
        pass

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", PORT), H) as httpd:
    httpd.serve_forever()
