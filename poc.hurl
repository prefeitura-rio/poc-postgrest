# PoC acceptance tests for the Postgres + PostgREST + FastAPI stack.
# Run: hurl poc.hurl  (stack must be up: docker compose up --build)

### Create a project via FastAPI
POST http://localhost:8000/projects
Content-Type: application/json
{"name":"Home"}

HTTP 201
[Asserts]
jsonpath "$.name" == "Home"
[Captures]
projectId: jsonpath "$.id"

### Create a task assigned to the project, with description and tags
POST http://localhost:8000/tasks
Content-Type: application/json
{"title":"Buy milk","description":"Pick up two liters of whole milk from the corner store","tags":["urgent","home"],"project_id":"{{projectId}}"}

HTTP 201
[Asserts]
jsonpath "$.title" == "Buy milk"
jsonpath "$.status" == "pending"
jsonpath "$.project_id" == "{{projectId}}"
jsonpath "$.tags" count == 2
[Captures]
taskId: jsonpath "$.id"

### Create a second task in the same project
POST http://localhost:8000/tasks
Content-Type: application/json
{"title":"Water plants","tags":["home"],"project_id":"{{projectId}}"}

HTTP 201
[Asserts]
jsonpath "$.title" == "Water plants"

### List projects with embedded tasks via FastAPI (PostgREST join)
GET http://localhost:8000/projects

HTTP 200
[Asserts]
jsonpath "$" count >= 1
jsonpath "$[0].tasks" count >= 2

### Get project summary via FastAPI (custom aggregation: counts by status)
GET http://localhost:8000/projects/{{projectId}}/summary

HTTP 200
[Asserts]
jsonpath "$.total" == 2
jsonpath "$.pending" == 2
jsonpath "$.completed" == 0

### Complete one task via FastAPI (expect 200)
POST http://localhost:8000/tasks/{{taskId}}/complete

HTTP 200
[Asserts]
jsonpath "$.status" == "completed"

### Re-fetch the summary (completed count increases)
GET http://localhost:8000/projects/{{projectId}}/summary

HTTP 200
[Asserts]
jsonpath "$.total" == 2
jsonpath "$.pending" == 1
jsonpath "$.completed" == 1

### RPC demo: create a second project with two pending tasks
POST http://localhost:8000/projects
Content-Type: application/json
{"name":"Work"}

HTTP 201
[Captures]
projectId2: jsonpath "$.id"

###
POST http://localhost:8000/tasks
Content-Type: application/json
{"title":"Write docs","tags":["work"],"project_id":"{{projectId2}}"}

HTTP 201

###
POST http://localhost:8000/tasks
Content-Type: application/json
{"title":"Review PR","tags":["work"],"project_id":"{{projectId2}}"}

HTTP 201

### Complete all pending tasks in the second project via the RPC (atomic, expect count 2)
POST http://localhost:8000/projects/{{projectId2}}/complete-all

HTTP 200
[Asserts]
jsonpath "$.completed_count" == 2

### Confirm the second project summary now shows all completed
GET http://localhost:8000/projects/{{projectId2}}/summary

HTTP 200
[Asserts]
jsonpath "$.total" == 2
jsonpath "$.pending" == 0
jsonpath "$.completed" == 2

### Calling complete-all again on the now-empty pending set returns 0
POST http://localhost:8000/projects/{{projectId2}}/complete-all

HTTP 200
[Asserts]
jsonpath "$.completed_count" == 0

### List tasks via FastAPI
GET http://localhost:8000/tasks

HTTP 200
[Asserts]
jsonpath "$" count >= 2

### Filter tasks by jsonb tag via FastAPI (expect matching tasks)
GET http://localhost:8000/tasks?tag=urgent

HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].tags" contains "urgent"

### Filter tasks by a nonexistent tag (expect an empty array)
GET http://localhost:8000/tasks?tag=nonexistent

HTTP 200
[Asserts]
jsonpath "$" count == 0

### Full-text search via FastAPI (expect the task matching "milk")
GET http://localhost:8000/tasks/search?q=milk

HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].title" == "Buy milk"

### Full-text search for a term that does not match (expect an empty array)
GET http://localhost:8000/tasks/search?q=photovoltaic

HTTP 200
[Asserts]
jsonpath "$" count == 0

### Read the created task via FastAPI
GET http://localhost:8000/tasks/{{taskId}}

HTTP 200
[Asserts]
jsonpath "$.id" == "{{taskId}}"
jsonpath "$.status" == "completed"

### Complete the task again via FastAPI (expect 409 Conflict)
POST http://localhost:8000/tasks/{{taskId}}/complete

HTTP 409
[Asserts]
jsonpath "$.detail" == "Task is already completed."

### Reject empty title via FastAPI (expect 422 Unprocessable Entity)
POST http://localhost:8000/tasks
Content-Type: application/json
{"title":""}

HTTP 422

### List projects with embedded tasks directly via PostgREST (select=*,tasks(*))
GET http://localhost:3000/projects?select=*,tasks(*)

HTTP 200
[Asserts]
jsonpath "$" count >= 1
jsonpath "$[0].tasks" count >= 2

### List tasks directly via PostgREST (confirms the write propagated)
GET http://localhost:3000/tasks

HTTP 200
[Asserts]
jsonpath "$" count >= 2

### Full-text search directly via PostgREST (fts operator on search_vector)
GET http://localhost:3000/tasks?search_vector=fts.milk

HTTP 200
[Asserts]
jsonpath "$" count == 1

### Filter by jsonb tag directly via PostgREST (cs containment operator)
GET http://localhost:3000/tasks?tags=cs.["urgent"]

HTTP 200
[Asserts]
jsonpath "$" count == 1

### Read the completed task directly via PostgREST
GET http://localhost:3000/tasks?id=eq.{{taskId}}

HTTP 200
[Asserts]
jsonpath "$" count == 1
jsonpath "$[0].status" == "completed"

### FK constraint: inserting a task with a nonexistent project_id is rejected by PostgREST
POST http://localhost:3000/tasks
Content-Type: application/json
{"title":"orphan","project_id":"00000000-0000-0000-0000-000000000000"}

HTTP 409
[Asserts]
jsonpath "$.code" == "23503"

### ON DELETE SET NULL: create a project and a task, delete the project, task keeps existing with null project_id
POST http://localhost:8000/projects
Content-Type: application/json
{"name":"SetNull"}

HTTP 201
[Captures]
projectId3: jsonpath "$.id"

###
POST http://localhost:8000/tasks
Content-Type: application/json
{"title":"child","project_id":"{{projectId3}}"}

HTTP 201
[Captures]
taskId3: jsonpath "$.id"

### Delete the project directly via PostgREST
DELETE http://localhost:3000/projects?id=eq.{{projectId3}}

HTTP 204

### The child task still exists, with project_id nulled by ON DELETE SET NULL
GET http://localhost:3000/tasks?id=eq.{{taskId3}}&select=project_id

HTTP 200
[Asserts]
jsonpath "$[0].project_id" == null

### Cleanup: delete the tasks created by this run (keeps the test idempotent)
DELETE http://localhost:3000/tasks?project_id=eq.{{projectId}}

HTTP 204

### Cleanup: delete the second project's tasks and the project
DELETE http://localhost:3000/tasks?project_id=eq.{{projectId2}}

HTTP 204

### Cleanup: delete the orphaned task from the ON DELETE SET NULL test
DELETE http://localhost:3000/tasks?id=eq.{{taskId3}}

HTTP 204

### Cleanup: delete the project created by this run
DELETE http://localhost:3000/projects?id=eq.{{projectId}}

HTTP 204

###
DELETE http://localhost:3000/projects?id=eq.{{projectId2}}

HTTP 204
