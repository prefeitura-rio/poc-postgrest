"""Async HTTP client that talks to PostgREST."""

from dataclasses import dataclass, field

from httpx2 import AsyncClient

from poc.models import TaskList, TaskRead
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
    """Thin async wrapper over the PostgREST tasks endpoint."""

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
        self, title: str, description: str | None, tags: list[str]
    ) -> TaskRead:
        response = await self.client.post(
            "/tasks",
            json={"title": title, "description": description, "tags": tags},
            headers={"Prefer": "return=representation"},
        )

        response = response.raise_for_status()
        rows = TaskList.model_validate_json(response.content).root
        return rows[0]

    async def complete_task(self, task_id: str) -> TaskRead | None:
        response = await self.client.patch(
            "/tasks",
            params={"id": f"eq.{task_id}"},
            json={"status": "completed", "updated_at": "now()"},
            headers={"Prefer": "return=representation"},
        )

        response = response.raise_for_status()
        rows = TaskList.model_validate_json(response.content).root
        return rows[0] if rows else None
