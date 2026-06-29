"""Custom LiteLLM callback that logs ONLY the request and response payloads.

Why this exists: setting ``LITELLM_LOG=DEBUG`` floods the logs with framework
internals. This callback instead emits one structured line per call containing
just the inbound request (model + messages) and the resulting response (choices
+ usage), which is what you usually want when demoing the gateway.

It is loaded by the proxy via ``litellm_settings.callbacks`` and respects the
``json_logs`` setting because it logs through LiteLLM's own ``verbose_proxy_logger``.
At import time it also quiets the noisy framework loggers (unless the operator
explicitly opted into DEBUG) so the only INFO-level lines you see are the
request/response entries below.
"""

import json
import logging

from litellm._logging import (
    verbose_logger,
    verbose_proxy_logger,
    verbose_router_logger,
)
from litellm.integrations.custom_logger import CustomLogger

# Module name used to identify our own log records (this file, sans .py).
_LOGGER_MODULE = "litellm_request_logger"

# Capture whether the operator opted into DEBUG *before* we touch any levels.
# LiteLLM has already applied LITELLM_LOG to these loggers at import time.
_debugging = (
    verbose_logger.level != logging.NOTSET and verbose_logger.level <= logging.DEBUG
)


class _OnlyRequestResponse(logging.Filter):
    """Drop framework INFO chatter (e.g. "SESSION REUSE") from the proxy logger,
    keeping our request/response entries and any real warnings/errors."""

    def filter(self, record: logging.LogRecord) -> bool:
        return record.levelno >= logging.WARNING or record.module == _LOGGER_MODULE


if not _debugging:
    # Quiet the bulk per-request framework chatter (the "LiteLLM" / "LiteLLM
    # Router" loggers) and the uvicorn HTTP access logs (the constant /health
    # probe lines), then filter the remaining proxy INFO noise so only the
    # request/response entries below are emitted.
    verbose_logger.setLevel(logging.WARNING)
    verbose_router_logger.setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    verbose_proxy_logger.setLevel(logging.INFO)
    verbose_proxy_logger.addFilter(_OnlyRequestResponse())


def _request(kwargs: dict) -> dict:
    return {
        "model": kwargs.get("model"),
        "messages": kwargs.get("messages"),
    }


def _response(response_obj) -> object:
    if response_obj is None:
        return None
    for attr in ("model_dump", "dict"):
        fn = getattr(response_obj, attr, None)
        if callable(fn):
            try:
                return fn()
            except Exception:  # pragma: no cover - best effort serialization
                pass
    return str(response_obj)


def _emit(event: str, payload: dict) -> None:
    verbose_proxy_logger.info(
        "litellm.%s %s", event, json.dumps(payload, default=str)
    )


class RequestResponseLogger(CustomLogger):
    """Logs the request and response (or error) for every completed call."""

    def log_success_event(self, kwargs, response_obj, start_time, end_time):
        _emit(
            "request_response",
            {"request": _request(kwargs), "response": _response(response_obj)},
        )

    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        _emit(
            "request_response",
            {"request": _request(kwargs), "response": _response(response_obj)},
        )

    def log_failure_event(self, kwargs, response_obj, start_time, end_time):
        _emit(
            "request_error",
            {"request": _request(kwargs), "error": str(kwargs.get("exception", response_obj))},
        )

    async def async_log_failure_event(self, kwargs, response_obj, start_time, end_time):
        _emit(
            "request_error",
            {"request": _request(kwargs), "error": str(kwargs.get("exception", response_obj))},
        )


# Referenced from config.yaml as: litellm_request_logger.proxy_handler_instance
proxy_handler_instance = RequestResponseLogger()
