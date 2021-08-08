#!/usr/bin/env python3

from http.server import HTTPServer, BaseHTTPRequestHandler
import ssl, os, sys


class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'Hello, world!')

if __name__ == '__main__':
    try:

        httpd = HTTPServer(('', 443), SimpleHTTPRequestHandler)

        httpd.socket = ssl.wrap_socket (
            httpd.socket, 
            keyfile="/etc/letsencrypt/live/stepsub.multipass/privkey.pem", 
            certfile="/etc/letsencrypt/live/stepsub.multipass/fullchain.pem",
            server_side=True
        )

        httpd.serve_forever()

    except KeyboardInterrupt:
        print('\rServer exited')
        try:
            sys.exit(0)
        except SystemExit:
            os._exit(0)
