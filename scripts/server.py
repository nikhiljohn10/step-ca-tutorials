#!/usr/bin/env python3

import ssl
import argparse
from socketserver import ThreadingMixIn
from http.server import BaseHTTPRequestHandler, HTTPServer

parser = argparse.ArgumentParser(prog="server", description="Python HTTPS Server")
parser.add_argument(
    "-m",
    "--mtls",
    dest="mtls",
    action="store_true",
    help="Enable mTLS server requirement",
)
parser.add_argument(
    "-d",
    "--domain",
    dest="domain",
    type=str,
    help="Domain name",
)
parser.add_argument(
    "-p",
    "--port",
    dest="port",
    type=int,
    help="Port number",
    default=443,
)
parser.add_argument(
    "-r",
    "--cacert",
    dest="cacert",
    type=str,
    help="Provide custom CA Root Certificate",
)
parser.add_argument(
    "-c",
    "--cert",
    dest="cert",
    type=str,
    help="Provide your domain certificate",
)
parser.add_argument(
    "-k",
    "--key",
    dest="key",
    type=str,
    help="Provide your domain certificate's private key",
)
args = parser.parse_args()
MTLS: bool = args.mtls
MTLS_ACTIVE_STRING: str = MTLS and "with" or "without"


class SimpleServer(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("content-type", "text/html; charset=utf-8")
        self.end_headers()
        if MTLS:
            message = b"\xf0\x9f\x91\x8b Hello, world with mTLS!\n"
        else:
            message = b"\xf0\x9f\x91\x8b Hello, world!\n"
        self.wfile.write(message)


class ThreadingSimpleServer(ThreadingMixIn, HTTPServer):
    ...


if __name__ == "__main__":

    server = ThreadingSimpleServer(("", args.port), SimpleServer)
    DOMAIN: str = args.domain or server.socket.gethostname()
    PORT: str = args.port != 443 and f":{args.port}" or ""

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_verify_locations(cafile=args.cacert)
    context.load_cert_chain(certfile=args.cert, keyfile=args.key)
    context.verify_mode = MTLS and ssl.CERT_REQUIRED or ssl.CERT_OPTIONAL

    with context.wrap_socket(sock=server.socket, server_side=True) as sock:
        try:
            server.socket = sock
            print(f"Server started https://{DOMAIN}{PORT} {MTLS_ACTIVE_STRING} mTLS")
            server.serve_forever()
        except KeyboardInterrupt:
            pass

    print("\rServer exited")
