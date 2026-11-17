#!/usr/bin/env python3
"""Health endpoint for Railway: GET /healthz on $PORT (default 8080).

Answers 200 once PostgreSQL accepts TCP connections on 127.0.0.1:5432
(pg_isready), 503 before that. It reads no data and returns no details.
"""
import http.server
import os
import socket
import subprocess


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?")[0] not in ("/", "/healthz"):
            self._reply(404, b"not found\n")
            return
        ready = subprocess.run(
            ["pg_isready", "-q", "-h", "127.0.0.1", "-p", "5432", "-t", "3",
             "-U", os.environ.get("POSTGRES_USER") or "postgres", "-d", "postgres"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        ).returncode == 0
        self._reply(200 if ready else 503, b"ok\n" if ready else b"starting\n")

    do_HEAD = do_GET

    def _reply(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def log_message(self, *args):
        pass


class DualStackServer(http.server.ThreadingHTTPServer):
    address_family = socket.AF_INET6
    daemon_threads = True

    def server_bind(self):
        self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        super().server_bind()


port = int(os.environ.get("PORT") or 8080)
try:
    server = DualStackServer(("::", port), Handler)
except OSError:
    http.server.ThreadingHTTPServer.daemon_threads = True
    server = http.server.ThreadingHTTPServer(("0.0.0.0", port), Handler)
server.serve_forever()
