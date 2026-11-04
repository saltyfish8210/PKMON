"""Run with Python 3.9+: python account_smoke.py path/to/pkmon-server.jar.
Starts and stops only its own localhost processes, using a disposable H2 file.
"""
from contextlib import contextmanager
from http.client import HTTPConnection
from pathlib import Path
from tempfile import TemporaryDirectory
from concurrent.futures import ThreadPoolExecutor
import json
import os
import re
import secrets
import subprocess
import sys
import time
import uuid


@contextmanager
def server(jar, directory):
    java_home = os.environ.get("JAVA_HOME")
    java = str(Path(java_home) / "bin/java") if java_home else "java"
    log = directory / "startup.log"
    with log.open("wb") as out:
        process = subprocess.Popen([
            java, "-jar", str(jar), "--server.address=127.0.0.1", "--server.port=0",
            "--spring.profiles.active=dev", "--pkmon.capture.dev-user-header=false",
            "--spring.datasource.url=jdbc:h2:file:./accounts;WRITE_DELAY=0",
        ], cwd=directory, stdout=out, stderr=subprocess.STDOUT,
           creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            deadline = time.monotonic() + 75
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError("Test server exited before becoming ready")
                match = re.search(rb"Tomcat started on port (\d+)", log.read_bytes())
                if match:
                    yield int(match[1])
                    return
                time.sleep(0.2)
            raise RuntimeError("Timed out starting private test server")
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


def call(port, method, path, body=None, token=None, want=(200, 0), extra=None, also=(), sample=False):
    connection = HTTPConnection("127.0.0.1", port, timeout=15)
    headers = {"Content-Type": "application/json", **(extra or {})}
    if token is not None:
        headers["Authorization"] = "Bearer " + token
    try:
        connection.request(method, "/api/v1" + path,
                           json.dumps(body).encode() if body is not None else None, headers)
        response = connection.getresponse()
        envelope = json.loads(response.read())
        actual = (response.status, envelope.get("code"))
        if actual not in (want, *also):
            raise AssertionError(f"{method} {path}: expected {want}, received {actual}")
        if sample:
            public = dict(envelope)
            if isinstance(public.get("data"), dict) and "token" in public["data"]:
                public["data"] = {**public["data"], "token": "[REDACTED]"}
            print(f"{method} {path} HTTP {response.status} " + json.dumps(public), flush=True)
        return envelope["data"]
    finally:
        connection.close()


def check(condition, label):
    if not condition:
        raise AssertionError(label)
    print("PASS " + label, flush=True)


def run(jar, directory):
    password = secrets.token_urlsafe(24)
    a = {"username": "player_a", "password": password}
    b = {"username": "player_b", "password": secrets.token_urlsafe(24)}
    with server(jar, directory) as port:
        def register_a(_):
            user = call(port, "POST", "/auth/register", {**a, "nickname": "A"}, also=((409, 40901),))
            return user is not None
        with ThreadPoolExecutor(max_workers=2) as workers:
            results = list(workers.map(register_a, range(2)))
        check(sorted(results) == [False, True], "concurrent same-name registration")
        call(port, "POST", "/auth/register", {**b, "nickname": "B"})
        call(port, "POST", "/auth/login", {**a, "password": b["password"]}, want=(401, 40101), sample=True)
        alice = call(port, "POST", "/auth/login", a, sample=True)
        old = alice["token"]
        live = call(port, "POST", "/auth/login", a)["token"]
        bob = call(port, "POST", "/auth/login", b)["token"]
        check(call(port, "GET", "/users/me", token=live) == alice["user"], "real login and public user fields")
        forged = {"X-Dev-User": alice["user"]["userId"]}
        call(port, "GET", "/collection/summary", extra=forged, want=(401, 40101))
        call(port, "GET", "/collection/summary", token="invalid", extra=forged, want=(401, 40101))

        task = call(port, "POST", "/study/tasks", {"regionId":"library_entrance",
                    "requestId": str(uuid.uuid4()), "locationSource":"SIMULATED"}, token=live)
        call(port, "POST", "/study/tasks/"+task["taskId"]+"/end",
             {"requestId":str(uuid.uuid4())}, token=bob, want=(404, 40401))
        check(call(port, "GET", "/study/tasks/current", token=bob)["task"] is None,
              "B cannot read or end A's study task")

        spawn = call(port, "POST", "/dev/spawns", {"regionId":"library_entrance","speciesId":"siege_lion"}, token=live)
        spawn_body = {"spawnId":spawn["spawnId"]}
        call(port, "POST", "/capture/challenge", spawn_body, token=bob, want=(404, 40401))
        challenge = call(port, "POST", "/capture/challenge", spawn_body, token=live)
        cid = challenge["challengeId"]
        call(port, "GET", "/capture/challenges/"+cid, token=bob, want=(404, 40401))
        answer = {"challengeId":cid, "requestId":str(uuid.uuid4()), "optionId":"A"}
        call(port, "POST", "/capture/answer", answer, token=bob, want=(404, 40401))
        call(port, "POST", "/capture/answer", answer, token=live)
        check(call(port, "GET", "/collection/summary", token=live)["captureCount"] == 1 and
              call(port, "GET", "/collection/summary", token=bob)["captureCount"] == 0,
              "spawn, challenge, answer and collection isolated across real accounts")

        call(port, "POST", "/auth/logout", {}, token=old)
        call(port, "POST", "/auth/logout", token=old)
        call(port, "GET", "/collection/summary", token=old, extra=forged, want=(401, 40101))
        check(call(port, "GET", "/users/me", token=live)["username"] == a["username"],
              "logout is idempotent, claimed identity cannot revive it, second session survives")

    with server(jar, directory) as port:
        call(port, "GET", "/users/me", token=old, want=(401, 40101))
        check(call(port, "GET", "/users/me", token=live) == alice["user"],
              "restart preserves active session and revoked session remains rejected")
        check(call(port, "POST", "/auth/login", a)["user"] == alice["user"],
              "same persisted account can log in after process restart")


if __name__ == "__main__":
    with TemporaryDirectory(prefix="pkmon-auth-") as tmp:
        run(Path(sys.argv[1]).resolve(strict=True), Path(tmp))
