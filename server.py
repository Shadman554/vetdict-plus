import http.server
import urllib.request
import urllib.error
import urllib.parse
import os

STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')
API_TARGET = 'https://vetdict.space'
PORT = 5000

# Allowed domains for the media proxy (whitelist to prevent open-proxy abuse)
PROXY_ALLOWED_HOSTS = (
    'drive.google.com',
    'lh3.googleusercontent.com',
    'lh4.googleusercontent.com',
    'lh5.googleusercontent.com',
    'lh6.googleusercontent.com',
    'docs.google.com',
)


class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=STATIC_DIR, **kwargs)

    def log_message(self, format, *args):
        print(format % args)

    def do_GET(self):
        if self.path.startswith('/api'):
            self._proxy_api()
        elif self.path.startswith('/media-proxy'):
            self._proxy_media()
        else:
            super().do_GET()

    def do_POST(self):
        if self.path.startswith('/api'):
            self._proxy_api()
        else:
            self.send_error(404)

    def do_PUT(self):
        if self.path.startswith('/api'):
            self._proxy_api()
        else:
            self.send_error(404)

    def do_DELETE(self):
        if self.path.startswith('/api'):
            self._proxy_api()
        else:
            self.send_error(404)

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors()
        self.end_headers()

    def _cors(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept')

    def _proxy_api(self):
        target_url = API_TARGET + self.path
        try:
            length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(length) if length > 0 else None

            forward_headers = {}
            for h in ('Authorization', 'Content-Type', 'Accept'):
                if h in self.headers:
                    forward_headers[h] = self.headers[h]

            req = urllib.request.Request(
                target_url, data=body, headers=forward_headers, method=self.command
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self._cors()
                self.send_header('Content-Type', resp.headers.get('Content-Type', 'application/json'))
                self.send_header('Content-Length', str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self._cors()
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except BrokenPipeError:
            pass
        except Exception as e:
            self.send_error(502, f'Proxy error: {e}')

    def _proxy_media(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        url_list = params.get('url', [])
        if not url_list:
            self.send_error(400, 'Missing url parameter')
            return

        target_url = urllib.parse.unquote(url_list[0])

        # Validate host against whitelist
        try:
            target_parsed = urllib.parse.urlparse(target_url)
            if target_parsed.hostname not in PROXY_ALLOWED_HOSTS:
                self.send_error(403, 'Host not allowed')
                return
        except Exception:
            self.send_error(400, 'Invalid url')
            return

        try:
            req = urllib.request.Request(
                target_url,
                headers={
                    'User-Agent': 'Mozilla/5.0 (compatible; VetDict/1.0)',
                    'Accept': '*/*',
                },
            )
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = resp.read()
                content_type = resp.headers.get('Content-Type', 'application/octet-stream')
                self.send_response(200)
                self._cors()
                self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(data)))
                self.send_header('Cache-Control', 'public, max-age=86400')
                self.end_headers()
                self.wfile.write(data)
        except BrokenPipeError:
            pass
        except Exception as e:
            self.send_error(502, f'Media proxy error: {e}')


if __name__ == '__main__':
    with http.server.ThreadingHTTPServer(('0.0.0.0', PORT), ProxyHandler) as httpd:
        print(f'Serving Flutter web + API proxy on port {PORT}')
        httpd.serve_forever()
