"""Run inside the ARM64 RAGFlow image; no external services are needed."""
import importlib
import os
import pathlib
import platform
import struct
import subprocess

assert platform.machine() == "aarch64", platform.machine()
assert os.environ["API_PROXY_SCHEME"] == "python"
if os.environ.get("EXPECTED_VERSION"):
    assert pathlib.Path("/ragflow/VERSION").read_text().strip() == os.environ["EXPECTED_VERSION"]
for binary in ("/opt/chrome/chrome", "/usr/local/bin/chromedriver"):
    header = pathlib.Path(binary).read_bytes()[:20]
    assert header[:4] == b"\x7fELF" and struct.unpack("<H", header[18:20])[0] == 183, binary
chrome = subprocess.check_output(["/opt/chrome/chrome", "--version"], text=True).split()[-1]
driver = subprocess.check_output(["chromedriver", "--version"], text=True).split()[1]
assert chrome == driver == "153.0.8010.52", (chrome, driver)
for module in ("onnxruntime", "pypdfium2", "pdfplumber", "zlib_state", "pandas", "akshare"):
    importlib.import_module(module)
from py_mini_racer import MiniRacer

with MiniRacer() as js:
    assert js.eval("21 * 2") == 42

from api.utils.web_utils import html2pdf

pdf = html2pdf("data:text/html,<html><body>ARM64 browser verification</body></html>", timeout=1)
assert pdf.startswith(b"%PDF-"), pdf[:50]
print("ARM64 native libraries, matching browser/driver and HTML-to-PDF passed.")
