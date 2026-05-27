package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"time"
)

const index = `<!doctype html>
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
const log = (s) => document.getElementById('log').textContent += s + "\n";
function mbps(bytes, ms) { return (bytes * 8 / 1e6) / (ms / 1000); }
async function downloadTest() {
  const mb = document.getElementById('mb').value || 100;
  log("download " + mb + " MB starting");
  const start = performance.now();
  const res = await fetch("/download?mb=" + mb + "&t=" + Date.now(), {cache: "no-store"});
  const reader = res.body.getReader();
  let bytes = 0;
  while (true) {
    const {done, value} = await reader.read();
    if (done) break;
    bytes += value.length;
  }
  const ms = performance.now() - start;
  log("download " + (bytes/1048576).toFixed(1) + " MB in " + (ms/1000).toFixed(2) + " s = " + mbps(bytes, ms).toFixed(2) + " Mbps");
}
async function uploadTest() {
  const mb = document.getElementById('mb').value || 100;
  log("upload " + mb + " MB starting");
  const bytes = mb * 1024 * 1024;
  const blob = new Blob([new Uint8Array(bytes)]);
  const start = performance.now();
  const res = await fetch("/upload?mb=" + mb + "&t=" + Date.now(), {method: "POST", body: blob});
  const text = await res.text();
  const ms = performance.now() - start;
  log("upload " + mb + " MB in " + (ms/1000).toFixed(2) + " s = " + mbps(bytes, ms).toFixed(2) + " Mbps");
  log(text.trim());
}
</script>
`

var chunk = make([]byte, 256*1024)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(w, index)
		log.Printf("%s GET /", r.RemoteAddr)
	})
	http.HandleFunc("/download", func(w http.ResponseWriter, r *http.Request) {
		mb, _ := strconv.Atoi(r.URL.Query().Get("mb"))
		if mb < 1 {
			mb = 100
		}
		if mb > 2000 {
			mb = 2000
		}
		total := int64(mb) * 1024 * 1024
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Content-Length", strconv.FormatInt(total, 10))
		start := time.Now()
		var sent int64
		for sent < total {
			n := int64(len(chunk))
			if total-sent < n {
				n = total - sent
			}
			if _, err := w.Write(chunk[:n]); err != nil {
				log.Printf("%s download stopped: %v", r.RemoteAddr, err)
				return
			}
			sent += n
		}
		mbps := float64(sent*8) / 1e6 / time.Since(start).Seconds()
		log.Printf("%s download %d bytes %.2f Mbps", r.RemoteAddr, sent, mbps)
	})
	http.HandleFunc("/upload", func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		n, err := io.Copy(io.Discard, r.Body)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		mbps := float64(n*8) / 1e6 / time.Since(start).Seconds()
		msg := fmt.Sprintf("server saw upload from %s: %d bytes, %.2f Mbps\n", r.RemoteAddr, n, mbps)
		log.Print(msg)
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprint(w, msg)
	})
	log.Print("bandwidth test server listening on 0.0.0.0:5201")
	log.Fatal(http.ListenAndServe(":5201", nil))
}
