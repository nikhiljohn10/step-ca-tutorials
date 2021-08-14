#!/usr/bin/env python3

import ssl
import argparse
from socketserver import ThreadingMixIn
from http.server import BaseHTTPRequestHandler, HTTPServer

parser = argparse.ArgumentParser(prog='server', description='Python HTTPS Server')
parser.add_argument(
    '-m', '--mtls',
    dest='mtls',
    action='store_true',
    help='Enable mTLS server requirement'
)
parser.add_argument(
    '-r', '--cacert',
    dest='cacert',
    type=str,
    help='Provide custom CA Root Certificate',
    default='/home/ubuntu/.step/certs/root_ca.crt',
)
parser.add_argument(
    '-c', '--cert',
    dest='cert',
    type=str,
    help='Provide your domain certificate',
    default='/etc/letsencrypt/live/stepsub.multipass/privkey.pem',
)
parser.add_argument(
    '-k', '--key',
    dest='key',
    type=str,
    help='Provide your domain certificate\'s private key',
    default='/etc/letsencrypt/live/stepsub.multipass/fullchain.pem',
)
args = parser.parse_args()
MTLS: bool = args.mtls

class SimpleServer(BaseHTTPRequestHandler):

    def do_GET(self):
        self.send_response(200)
        self.send_header('content-type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(b'\xf0\x9f\x91\x8b Hello, world!\n')


class ThreadingSimpleServer(ThreadingMixIn,HTTPServer):
    pass


if __name__ == '__main__':
    server = ThreadingSimpleServer(('', 443), SimpleServer)

    server.socket = ssl.wrap_socket(
        sock=server.socket, 
        cert_reqs=MTLS and ssl.CERT_REQUIRED or ssl.CERT_OPTIONAL,
        ca_certs=args.cacert,
        keyfile=args.cert, 
        certfile=args.key,
        server_side=True,
    )
    print("Server started https://stepsub.multipass")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass

    server.server_close()
    print('\rServer exited')
