#!/usr/bin/env python3
"""Seam AI backend using the Codex app-server SDK protocol.

The QML layer passes one JSON request. This client starts an ephemeral Codex
thread through JSON-RPC, waits for its streamed answer, and returns one JSON
result for the UI. Authentication is inherited from ``codex login``.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
from typing import Any


class CodexSdkError(RuntimeError):
    pass


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


class CodexAppServer:
    def __init__(self, executable: str) -> None:
        self.process = subprocess.Popen(
            [executable, "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        self.next_id = 1
        self.stderr_lines: list[str] = []
        threading.Thread(target=self._collect_stderr, daemon=True).start()

    def _collect_stderr(self) -> None:
        assert self.process.stderr is not None
        for line in self.process.stderr:
            self.stderr_lines.append(line.rstrip())

    def send(self, message: dict[str, Any]) -> None:
        if self.process.stdin is None:
            raise CodexSdkError("Codex app-server stdin is unavailable")
        self.process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
        self.process.stdin.flush()

    def request(self, method: str, params: dict[str, Any]) -> int:
        request_id = self.next_id
        self.next_id += 1
        self.send({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params})
        return request_id

    def read(self) -> dict[str, Any]:
        if self.process.stdout is None:
            raise CodexSdkError("Codex app-server stdout is unavailable")
        while True:
            line = self.process.stdout.readline()
            if not line:
                detail = "\n".join(self.stderr_lines[-12:]).strip()
                raise CodexSdkError(detail or "Codex app-server stopped unexpectedly")
            try:
                value = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(value, dict):
                return value

    def wait_for_response(self, request_id: int) -> dict[str, Any]:
        while True:
            event = self.read()
            if event.get("id") != request_id:
                continue
            if "error" in event:
                error = event["error"]
                raise CodexSdkError(error.get("message", str(error)))
            return event.get("result", {})

    def close(self) -> None:
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()


def run_codex(request: dict[str, Any], executable: str) -> str:
    prompt = str(request.get("prompt", "")).strip()
    if not prompt:
        raise CodexSdkError("The Codex prompt is empty")

    server = CodexAppServer(executable)
    try:
        initialize_id = server.request(
            "initialize",
            {
                "clientInfo": {"name": "seam", "title": "Seam AI", "version": "1.0.0"},
                "capabilities": {"experimentalApi": False},
            },
        )
        server.wait_for_response(initialize_id)
        server.send({"jsonrpc": "2.0", "method": "initialized", "params": {}})

        thread_params: dict[str, Any] = {
            "approvalPolicy": "never",
            "sandbox": "read-only",
            "cwd": "/tmp",
            "ephemeral": True,
            "baseInstructions": (
                "You are the AI assistant inside Seam's desktop sidebar. Answer the "
                "user directly. Do not inspect files, execute commands, or modify the system."
                "But You Can help The user with linux"
            ),
        }
        model = str(request.get("model", "")).strip()
        if model:
            thread_params["model"] = model

        thread_id_request = server.request("thread/start", thread_params)
        thread_result = server.wait_for_response(thread_id_request)
        thread_id = thread_result.get("thread", {}).get("id")
        if not thread_id:
            raise CodexSdkError("Codex did not return a thread id")

        inputs: list[dict[str, Any]] = [{"type": "text", "text": prompt, "text_elements": []}]
        image = Path(str(request.get("image", ""))).expanduser()
        if str(request.get("image", "")).strip() and image.is_file():
            inputs.append({"type": "localImage", "path": str(image.resolve())})

        turn_request = server.request("turn/start", {"threadId": thread_id, "input": inputs})
        server.wait_for_response(turn_request)

        chunks: list[str] = []
        transient_errors: list[str] = []
        while True:
            event = server.read()
            method = event.get("method")
            params = event.get("params", {})
            if method == "item/agentMessage/delta" and params.get("threadId") == thread_id:
                chunks.append(str(params.get("delta", "")))
            elif method == "error":
                message = params.get("error", {}).get("message") or params.get("message")
                # The app-server reports retry/reconnect notices through the error
                # notification too. The authoritative terminal state is the turn's
                # completion status, so keep waiting while Codex retries.
                transient_errors.append(str(message or "Codex connection warning"))
            elif method == "turn/completed" and params.get("threadId") == thread_id:
                status = params.get("turn", {}).get("status")
                if status == "failed":
                    error = params.get("turn", {}).get("error", {})
                    detail = error.get("message") or (transient_errors[-1] if transient_errors else "Codex turn failed")
                    raise CodexSdkError(detail)
                break

        answer = "".join(chunks).strip()
        if not answer:
            raise CodexSdkError("Codex returned an empty response")
        return answer
    finally:
        server.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request", required=True, type=Path)
    args = parser.parse_args()
    try:
        request = json.loads(args.request.read_text(encoding="utf-8"))
        executable = shutil.which("codex")
        if not executable:
            raise CodexSdkError("Codex CLI is not installed or is not in PATH")
        emit({"ok": True, "content": run_codex(request, executable)})
        return 0
    except (OSError, json.JSONDecodeError, CodexSdkError) as error:
        emit({"ok": False, "error": str(error)})
        return 1


if __name__ == "__main__":
    sys.exit(main())
