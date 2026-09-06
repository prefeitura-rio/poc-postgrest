FROM ghcr.io/astral-sh/uv:python3.14-alpine

WORKDIR /app

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_SYNC_FROZEN=1

COPY pyproject.toml uv.lock ./
COPY src ./src

RUN uv sync --frozen --no-dev

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["granian", "--interface", "asgi", "poc.main:app", "--host", "0.0.0.0", "--port", "8000"]
