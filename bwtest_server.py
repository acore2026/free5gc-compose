#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse
import time


INDEX = b"""<!doctype html>
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Bandwidth Test</title>
<style>
body{font-family:system-ui,sans-serif;margin:24px;max-width:640px}
button,input{font:inherit;padding:10px;margin:6px 0}
button{display:block;width:100%}
.row{margin:14px 0}
#log{white-space:pre-wrap;background:#111;color:#eee;padding:12px;border-radius:6px}
</style>
<h1>Bandwidth Test</h1>
<div class="row">Size MB <input id="mb" type="number" value="100" min="10" max="1000"></div>
<button onclick="downloadTest()">Download: server to phone</button>
<button onclick="uploadTest()">Upload: phone to server</button>
<pre id="log"></pre>
<script>
const log = (s) => document.getElementById('log').textContent += s + "\\n";
function mbps(bytes, ms) { return (bytes * 8 / 1e6) / (ms / 1000); }
async function downloadTest() {
  const mb = document.getElementById('mb').value || 100;
  log(`download ${mb} MB starting`);
  const start = performance.now();
  const res = await fetch(`/download?mb=${mb}&t=${Date.now()}`, {cache: "no-store"});
  const reader = res.body.getReader();
  let bytes = 0;
  while (true) {
    const {done, value} = await reader.read();
    if (done) break;
    bytes += value.length;
  }
  const ms = performance.now() - start;
  log(`download ${(bytes/1048576).toFixed(1)} MB in ${(ms/1000).toFixed(2)} s = ${mbps(bytes, ms).toFixed(2)} Mbps`);
}
async function uploadTest() {
  const mb = document.getElementById('mb').value || 100;
  log(`upload ${mb} MB starting`);
  const bytes = mb * 1024 * 1024;
  const blob = new Blob([new Uint8Array(bytes)]);
  const start = performance.now();
  const res = await fetch(`/upload?mb=${mb}&t=${Date.now()}`, {method: "POST", body: blob});
  const text = await res.text();
  const ms = performance.now() - start;
  log(`upload ${mb} MB in ${(ms/1000).toFixed(2)} s = ${mbps(bytes, ms).toFixed(2)} Mbps`);
  log(text.trim());
}
</script>
"""


class Handler(BaseHTTPRequestHandler):
    chunk = b"\0" * (256 * 1024)

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(INDEX)))
            self.end_headers()
            self.wfile.write(INDEX)
            return
        if parsed.path == "/download":
            mb = int(parse_qs(parsed.query).get("mb", ["100"])[0])
            total = max(1, min(mb, 2000)) * 1024 * 1024
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(total))
            self.end_headers()
            sent = 0
            start = time.time()
            while sent < total:
                n = min(len(self.chunk), total - sent)
                self.wfile.write(self.chunk[:n])
                sent += n
            elapsed = time.time() - start
            print(f"download {self.client_address[0]} {sent} bytes {sent * 8 / 1e6 / elapsed:.2f} Mbps", flush=True)
            return
        self.send_error(404)

    def do_POST(self):
        if urlparse(self.path).path != "/upload":
            self.send_error(404)
            return
        remaining = int(self.headers.get("Content-Length", "0"))
        total = remaining
        start = time.time()
        while remaining:
            data = self.rfile.read(min(256 * 1024, remaining))
            if not data:
                break
            remaining -= len(data)
        elapsed = max(time.time() - start, 0.001)
        rate = total * 8 / 1e6 / elapsed
        body = f"server saw upload from {self.client_address[0]}: {total} bytes, {rate:.2f} Mbps\n".encode()
        print(body.decode().strip(), flush=True)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", 5201), Handler)
    print("bandwidth test server listening on 0.0.0.0:5201", flush=True)
    server.serve_forever()
