"""FastAPI application with custom logic over PostgREST."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import FastAPI, HTTPException, Query, status

from poc.client import PostgrestClient
from poc.models import TaskComplete, TaskCreate, TaskRead
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


@app.get("/tasks", response_model=list[TaskRead])
async def list_tasks(request: AppRequest) -> list[TaskRead]:
    client = request.state["postgrest"]
    tag = request.query_params.get("tag")
    return await client.list_tasks(tag=tag)


@app.get("/tasks/search", response_model=list[TaskRead])
async def search_tasks(
    request: AppRequest,
    q: SearchQuery,
) -> list[TaskRead]:
    client = request.state["postgrest"]
    return await client.search_tasks(q)


@app.post(
    "/tasks",
    response_model=TaskRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_task(payload: TaskCreate, request: AppRequest) -> TaskRead:
    client = request.state["postgrest"]
    return await client.create_task(payload.title, payload.description, payload.tags)


@app.get("/tasks/{task_id}", response_model=TaskRead)
async def get_task(task_id: str, request: AppRequest) -> TaskRead:
    client = request.state["postgrest"]
    task = await client.get_task(task_id)

    if task is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Task not found."
        )
    return task


@app.post("/tasks/{task_id}/complete", response_model=TaskComplete)
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
