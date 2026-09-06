"""Pydantic models for the tasks API."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, RootModel


class TaskCreate(BaseModel):
    """Payload to create a task."""

    title: str = Field(min_length=1, description="Task title, must not be empty.")
    description: str | None = Field(
        default=None, description="Optional task description."
    )
    tags: list[str] = Field(default_factory=list, description="Optional task tags.")
    project_id: UUID | None = Field(
        default=None, description="Optional project to assign the task to."
    )


class TaskRead(BaseModel):
    """A task as stored in the database and returned by the API."""

    id: UUID
    title: str
    description: str | None
    status: str
    tags: list[str]
    project_id: UUID | None
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


class ProjectCreate(BaseModel):
    """Payload to create a project."""

    name: str = Field(min_length=1, description="Project name, must not be empty.")


class ProjectRead(BaseModel):
    """A project as stored in the database."""

    id: UUID
    name: str
    created_at: datetime


class ProjectWithTasks(ProjectRead):
    """A project with its tasks nested via PostgREST embedded resources."""

    tasks: list[TaskRead] = Field(default_factory=list)


class ProjectSummary(BaseModel):
    """Aggregated task counts for a project, computed by FastAPI."""

    id: UUID
    name: str
    total: int
    pending: int
    completed: int


class CompleteAllResult(BaseModel):
    """Result of atomically completing all pending tasks in a project."""

    completed_count: int


class ProjectList(RootModel[list[ProjectRead]]):
    """A list of projects as returned by PostgREST."""

    root: list[ProjectRead]


class ProjectWithTasksList(RootModel[list[ProjectWithTasks]]):
    """A list of projects with embedded tasks."""

    root: list[ProjectWithTasks]


class CompleteAllCount(RootModel[int]):
    """The integer count returned by the complete_all_tasks RPC."""

    root: int
