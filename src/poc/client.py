"""Async HTTP client that talks to PostgREST."""

from dataclasses import dataclass, field

from httpx2 import AsyncClient

from poc.models import (
    CompleteAllCount,
    ProjectList,
    ProjectRead,
    ProjectWithTasks,
    ProjectWithTasksList,
    TaskList,
    TaskRead,
)
from poc.settings import settings


def build_client() -> AsyncClient:
    """Build the httpx2 async client from application settings."""

    return AsyncClient(
        base_url=settings.postgrest_url,
        timeout=settings.postgrest_timeout,
        headers={"Accept": "application/json"},
    )


@dataclass
class PostgrestClient:
    """Thin async wrapper over the PostgREST tasks and projects endpoints."""

    client: AsyncClient = field(default_factory=build_client)

    async def aclose(self) -> None:
        await self.client.aclose()

    async def list_tasks(self, tag: str | None = None) -> list[TaskRead]:
        params: dict[str, str] = {"order": "created_at.asc"}
        if tag is not None:
            params["tags"] = f'cs.["{tag}"]'
        response = await self.client.get("/tasks", params=params)
        response = response.raise_for_status()
        return TaskList.model_validate_json(response.content).root

    async def search_tasks(self, query: str) -> list[TaskRead]:
        response = await self.client.get(
            "/tasks",
            params={"search_vector": f"fts.{query}", "order": "created_at.asc"},
        )
        response = response.raise_for_status()
        return TaskList.model_validate_json(response.content).root

    async def get_task(self, task_id: str) -> TaskRead | None:
        response = await self.client.get("/tasks", params={"id": f"eq.{task_id}"})
        response = response.raise_for_status()
        rows = TaskList.model_validate_json(response.content).root
        return rows[0] if rows else None

    async def create_task(
        self,
        title: str,
        description: str | None,
        tags: list[str],
        project_id: str | None,
    ) -> TaskRead:
        response = await self.client.post(
            "/tasks",
            json={
                "title": title,
                "description": description,
                "tags": tags,
                "project_id": project_id,
            },
            headers={"Prefer": "return=representation"},
        )
        response = response.raise_for_status()
        rows = TaskList.model_validate_json(response.content).root
        return rows[0]

    async def complete_task(self, task_id: str) -> TaskRead | None:
        response = await self.client.patch(
            "/tasks",
            params={"id": f"eq.{task_id}"},
            json={"status": "completed"},
            headers={"Prefer": "return=representation"},
        )

        response = response.raise_for_status()
        rows = TaskList.model_validate_json(response.content).root
        return rows[0] if rows else None

    async def complete_all_tasks(self, project_id: str) -> int:
        response = await self.client.post(
            "/rpc/complete_all_tasks",
            json={"p_project_id": project_id},
        )
        response = response.raise_for_status()
        return CompleteAllCount.model_validate_json(response.content).root

    async def list_projects(self) -> list[ProjectRead]:
        response = await self.client.get(
            "/projects", params={"order": "created_at.asc"}
        )
        response = response.raise_for_status()
        return ProjectList.model_validate_json(response.content).root

    async def list_projects_with_tasks(self) -> list[ProjectWithTasks]:
        response = await self.client.get(
            "/projects", params={"select": "*,tasks(*)", "order": "created_at.asc"}
        )
        response = response.raise_for_status()
        return ProjectWithTasksList.model_validate_json(response.content).root

    async def create_project(self, name: str) -> ProjectRead:
        response = await self.client.post(
            "/projects",
            json={"name": name},
            headers={"Prefer": "return=representation"},
        )
        response = response.raise_for_status()
        rows = ProjectList.model_validate_json(response.content).root
        return rows[0]

    async def get_project(self, project_id: str) -> ProjectRead | None:
        response = await self.client.get("/projects", params={"id": f"eq.{project_id}"})
        response = response.raise_for_status()
        rows = ProjectList.model_validate_json(response.content).root
        return rows[0] if rows else None

    async def list_tasks_by_project(self, project_id: str) -> list[TaskRead]:
        response = await self.client.get(
            "/tasks",
            params={"project_id": f"eq.{project_id}", "order": "created_at.asc"},
        )
        response = response.raise_for_status()
        return TaskList.model_validate_json(response.content).root
