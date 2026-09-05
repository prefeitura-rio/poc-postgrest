"""Pydantic models for the tasks API."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, RootModel


class TaskCreate(BaseModel):
    """Payload to create a task."""

    title: str = Field(min_length=1, description="Task title, must not be empty.")


class TaskRead(BaseModel):
    """A task as stored in the database and returned by the API."""

    id: UUID
    title: str
    status: str
    created_at: datetime
    updated_at: datetime


class TaskComplete(BaseModel):
    """Response after completing a task."""

    id: UUID
    title: str
    status: str
    updated_at: datetime


class TaskList(RootModel[list[TaskRead]]):
    """A list of tasks as returned by PostgREST."""

    root: list[TaskRead]
