"""FastAPI application with custom logic over PostgREST."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import FastAPI, HTTPException, Query, status

from poc.client import PostgrestClient
from poc.models import (
    CompleteAllResult,
    ProjectCreate,
    ProjectRead,
    ProjectSummary,
    ProjectWithTasks,
    TaskComplete,
    TaskCreate,
    TaskRead,
)
from poc.state import AppRequest, AppState

SearchQuery = Annotated[str, Query(min_length=1, description="Full-text search query.")]


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncGenerator[AppState]:
    client = PostgrestClient()
    try:
        yield {"postgrest": client}
    finally:
        await client.aclose()


app = FastAPI(title="PoC Tasks API", lifespan=lifespan)


@app.get("/tasks")
async def list_tasks(request: AppRequest) -> list[TaskRead]:
    client = request.state["postgrest"]
    tag = request.query_params.get("tag")
    return await client.list_tasks(tag=tag)


@app.get("/tasks/search")
async def search_tasks(
    request: AppRequest,
    q: SearchQuery,
) -> list[TaskRead]:
    client = request.state["postgrest"]
    return await client.search_tasks(q)


@app.post("/tasks", status_code=status.HTTP_201_CREATED)
async def create_task(payload: TaskCreate, request: AppRequest) -> TaskRead:
    client = request.state["postgrest"]
    project_id = str(payload.project_id) if payload.project_id is not None else None
    return await client.create_task(
        payload.title, payload.description, payload.tags, project_id
    )


@app.get("/tasks/{task_id}")
async def get_task(task_id: str, request: AppRequest) -> TaskRead:
    client = request.state["postgrest"]
    task = await client.get_task(task_id)
    if task is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Task not found."
        )
    return task


@app.post("/tasks/{task_id}/complete")
async def complete_task(task_id: str, request: AppRequest) -> TaskComplete:
    client = request.state["postgrest"]
    task = await client.get_task(task_id)
    if task is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Task not found."
        )
    if task.status == "completed":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Task is already completed.",
        )
    completed = await client.complete_task(task_id)
    if completed is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to complete task.",
        )
    return TaskComplete(
        id=completed.id,
        title=completed.title,
        status=completed.status,
        updated_at=completed.updated_at,
    )


@app.get("/projects")
async def list_projects(request: AppRequest) -> list[ProjectWithTasks]:
    client = request.state["postgrest"]
    return await client.list_projects_with_tasks()


@app.post("/projects", status_code=status.HTTP_201_CREATED)
async def create_project(payload: ProjectCreate, request: AppRequest) -> ProjectRead:
    client = request.state["postgrest"]
    return await client.create_project(payload.name)


@app.get("/projects/{project_id}/summary")
async def project_summary(project_id: str, request: AppRequest) -> ProjectSummary:
    client = request.state["postgrest"]
    project = await client.get_project(project_id)
    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Project not found."
        )
    tasks = await client.list_tasks_by_project(project_id)
    total = len(tasks)
    pending = sum(1 for t in tasks if t.status == "pending")
    completed = total - pending
    return ProjectSummary(
        id=project.id,
        name=project.name,
        total=total,
        pending=pending,
        completed=completed,
    )


@app.post("/projects/{project_id}/complete-all")
async def complete_all_tasks(project_id: str, request: AppRequest) -> CompleteAllResult:
    client = request.state["postgrest"]
    project = await client.get_project(project_id)
    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Project not found."
        )
    count = await client.complete_all_tasks(project_id)
    return CompleteAllResult(completed_count=count)
