"""Typed application state for FastAPI request injection."""

from typing import TypedDict

from fastapi import Request

from poc.client import PostgrestClient


class AppState(TypedDict):
    """Application state attached to the FastAPI app at startup."""

    postgrest: PostgrestClient


class AppRequest(Request[AppState]):
    """Request with typed application state."""
