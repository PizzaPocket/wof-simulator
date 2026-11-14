"""Preview the precompressed Vercel build with the same binary encoding headers."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse


class WebHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        path = Path(self.translate_path(self.path))
        if path.suffix in (".wasm", ".pck") and path.is_file():
            with path.open("rb") as stream:
                if stream.read(2) == b"\x1f\x8b":
                    self.send_header("Content-Encoding", "gzip")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    directory = Path(__file__).resolve().parents[1] / "game/exports/web"
    handler = partial(WebHandler, directory=str(directory))
    print(f"Preview: http://127.0.0.1:{args.port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", args.port), handler).serve_forever()
