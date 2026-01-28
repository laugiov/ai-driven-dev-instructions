# API Design Guidelines

**Document Version**: 1.0
**Last Updated**: 2025-01-07
**Status**: Complete

## Table of Contents

1. [Overview](#overview)
2. [RESTful API Principles](#restful-api-principles)
3. [URL Structure](#url-structure)
4. [HTTP Methods](#http-methods)
5. [Request Format](#request-format)
6. [Response Format](#response-format)
7. [Status Codes](#status-codes)
8. [Error Handling](#error-handling)
9. [Pagination](#pagination)
10. [Filtering and Sorting](#filtering-and-sorting)
11. [Versioning](#versioning)
12. [Authentication](#authentication)
13. [Rate Limiting](#rate-limiting)
14. [Documentation](#documentation)

## Overview

Consistent, well-designed APIs improve developer experience and system maintainability. This document defines API design standards for all services in the platform.

### Design Principles

1. **Consistency**: Uniform patterns across all endpoints
2. **RESTful**: Follow REST architectural constraints
3. **Self-documenting**: Clear, intuitive endpoint names
4. **Versioned**: Support multiple API versions
5. **Secure**: Authentication and authorization on all endpoints
6. **Performant**: Efficient data transfer, pagination
7. **Error-friendly**: Clear error messages

## RESTful API Principles

### REST Constraints

| Constraint | Implementation |
|------------|----------------|
| **Client-Server** | Clear separation, stateless server |
| **Stateless** | No session state on server |
| **Cacheable** | Cache-Control headers |
| **Uniform Interface** | Standard HTTP methods, URIs |
| **Layered System** | API Gateway, service mesh |

### Resource-Oriented Design

```
Resources (nouns, not verbs):
✅ /api/v1/workflows
✅ /api/v1/agents
✅ /api/v1/workflows/{id}/executions

❌ /api/v1/getWorkflows
❌ /api/v1/createAgent
❌ /api/v1/executeWorkflow
```

## URL Structure

### Base URL

```
Production:  https://api.platform.com
Staging:     https://api-staging.platform.com
Development: http://localhost:8000
```

### URL Pattern

```
{base_url}/api/{version}/{resource}/{identifier}/{sub-resource}

Examples:
GET    /api/v1/workflows
GET    /api/v1/workflows/wf-123
GET    /api/v1/workflows/wf-123/steps
POST   /api/v1/workflows/wf-123/execute
```

### URL Conventions

```
✅ Use kebab-case for multi-word resources
   /api/v1/llm-agents

✅ Use plural nouns for collections
   /api/v1/workflows (not /api/v1/workflow)

✅ Use hierarchical structure for relationships
   /api/v1/workflows/{id}/steps/{stepId}

✅ Keep URLs short and readable
   /api/v1/users/{id}/workflows

❌ Don't use verbs in URLs
   /api/v1/createWorkflow ❌
   POST /api/v1/workflows ✅

❌ Don't use file extensions
   /api/v1/workflows.json ❌
   /api/v1/workflows (Content-Type header) ✅
```

## HTTP Methods

### Standard CRUD Operations

| Method | Action | Idempotent | Safe | Example |
|--------|--------|------------|------|---------|
| **GET** | Read | Yes | Yes | `GET /api/v1/workflows/123` |
| **POST** | Create | No | No | `POST /api/v1/workflows` |
| **PUT** | Replace | Yes | No | `PUT /api/v1/workflows/123` |
| **PATCH** | Update | No | No | `PATCH /api/v1/workflows/123` |
| **DELETE** | Delete | Yes | No | `DELETE /api/v1/workflows/123` |

### Method Usage

```php
// GET - Retrieve resource(s)
GET /api/v1/workflows           // List workflows
GET /api/v1/workflows/123       // Get specific workflow

// POST - Create new resource
POST /api/v1/workflows
Content-Type: application/json

{
  "name": "My Workflow",
  "definition": {...}
}

// PUT - Replace entire resource
PUT /api/v1/workflows/123
Content-Type: application/json

{
  "name": "Updated Workflow",
  "definition": {...},
  "status": "active"
}

// PATCH - Partial update
PATCH /api/v1/workflows/123
Content-Type: application/json

{
  "name": "New Name"  // Only update name
}

// DELETE - Remove resource
DELETE /api/v1/workflows/123
```

### Custom Actions

For operations that don't fit CRUD, use POST with action in URL:

```
POST /api/v1/workflows/123/execute
POST /api/v1/workflows/123/pause
POST /api/v1/workflows/123/resume
POST /api/v1/agents/123/test-completion
```

## Request Format

### Content Type

```
Content-Type: application/json

✅ Always use JSON for request/response bodies
❌ Don't use XML, form-encoded (except OAuth)
```

### Request Body Example

```json
POST /api/v1/agents
Content-Type: application/json

{
  "name": "Customer Support Agent",
  "model": "gpt-4",
  "system_prompt": "You are a helpful customer support agent",
  "configuration": {
    "temperature": 0.7,
    "max_tokens": 500
  }
}
```

### Request Validation

```php
<?php

// Symfony validation
use Symfony\Component\Validator\Constraints as Assert;

final class CreateAgentRequest
{
    #[Assert\NotBlank]
    #[Assert\Length(min: 3, max: 255)]
    public string $name;

    #[Assert\NotBlank]
    #[Assert\Choice(['gpt-4', 'gpt-3.5-turbo', 'claude-3'])]
    public string $model;

    #[Assert\NotBlank]
    #[Assert\Length(min: 10, max: 4000)]
    public string $system_prompt;

    #[Assert\Type('array')]
    public array $configuration = [];
}
```

## Response Format

### Success Response Structure

```json
{
  "data": {
    "id": "ag-123",
    "type": "agent",
    "attributes": {
      "name": "Customer Support Agent",
      "model": "gpt-4",
      "status": "active",
      "created_at": "2025-01-07T10:30:00Z"
    }
  },
  "meta": {
    "version": "1.0"
  }
}
```

### Collection Response

```json
GET /api/v1/workflows?page=1&limit=20

{
  "data": [
    {
      "id": "wf-123",
      "type": "workflow",
      "attributes": {
        "name": "Workflow 1",
        "status": "active"
      }
    },
    {
      "id": "wf-124",
      "type": "workflow",
      "attributes": {
        "name": "Workflow 2",
        "status": "draft"
      }
    }
  ],
  "meta": {
    "pagination": {
      "total": 150,
      "count": 20,
      "per_page": 20,
      "current_page": 1,
      "total_pages": 8
    }
  },
  "links": {
    "self": "/api/v1/workflows?page=1",
    "first": "/api/v1/workflows?page=1",
    "last": "/api/v1/workflows?page=8",
    "next": "/api/v1/workflows?page=2"
  }
}
```

### Response Headers

```
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
X-Request-ID: req-abc123
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1704628800
Cache-Control: no-cache, no-store, must-revalidate
```

## Status Codes

### Standard HTTP Status Codes

| Code | Status | Usage |
|------|--------|-------|
| **200** | OK | Successful GET, PUT, PATCH, DELETE |
| **201** | Created | Successful POST (resource created) |
| **202** | Accepted | Request accepted for async processing |
| **204** | No Content | Successful DELETE (no response body) |
| **400** | Bad Request | Invalid request format/validation error |
| **401** | Unauthorized | Missing or invalid authentication |
| **403** | Forbidden | Authenticated but not authorized |
| **404** | Not Found | Resource doesn't exist |
| **409** | Conflict | Resource conflict (duplicate, concurrent modification) |
| **422** | Unprocessable Entity | Validation error |
| **429** | Too Many Requests | Rate limit exceeded |
| **500** | Internal Server Error | Server error |
| **503** | Service Unavailable | Service down or overloaded |

### Status Code Examples

```php
<?php

// 200 OK - Successful read
return new JsonResponse($data, Response::HTTP_OK);

// 201 Created - Resource created
return new JsonResponse(
    ['id' => $workflow->getId()],
    Response::HTTP_CREATED,
    ['Location' => "/api/v1/workflows/{$workflow->getId()}"]
);

// 204 No Content - Successful deletion
return new JsonResponse(null, Response::HTTP_NO_CONTENT);

// 400 Bad Request - Invalid input
return new JsonResponse(
    ['error' => 'Invalid JSON'],
    Response::HTTP_BAD_REQUEST
);

// 401 Unauthorized - No auth
return new JsonResponse(
    ['error' => 'Authentication required'],
    Response::HTTP_UNAUTHORIZED
);

// 403 Forbidden - No permission
return new JsonResponse(
    ['error' => 'Insufficient permissions'],
    Response::HTTP_FORBIDDEN
);

// 404 Not Found - Resource missing
return new JsonResponse(
    ['error' => 'Workflow not found'],
    Response::HTTP_NOT_FOUND
);

// 422 Unprocessable Entity - Validation error
return new JsonResponse(
    [
        'error' => 'Validation failed',
        'details' => [
            'name' => ['Name is required'],
            'model' => ['Invalid model choice']
        ]
    ],
    Response::HTTP_UNPROCESSABLE_ENTITY
);

// 429 Too Many Requests - Rate limited
return new JsonResponse(
    ['error' => 'Rate limit exceeded'],
    Response::HTTP_TOO_MANY_REQUESTS,
    ['Retry-After' => 60]
);
```

## Error Handling

### Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "The request contains invalid data",
    "details": [
      {
        "field": "name",
        "message": "Name must be at least 3 characters"
      },
      {
        "field": "model",
        "message": "Invalid model choice"
      }
    ],
    "request_id": "req-abc123",
    "timestamp": "2025-01-07T10:30:00Z"
  }
}
```

### Error Codes

```php
<?php

enum ApiErrorCode: string
{
    // Client errors (4xx)
    case VALIDATION_ERROR = 'VALIDATION_ERROR';
    case AUTHENTICATION_REQUIRED = 'AUTHENTICATION_REQUIRED';
    case INSUFFICIENT_PERMISSIONS = 'INSUFFICIENT_PERMISSIONS';
    case RESOURCE_NOT_FOUND = 'RESOURCE_NOT_FOUND';
    case RESOURCE_CONFLICT = 'RESOURCE_CONFLICT';
    case RATE_LIMIT_EXCEEDED = 'RATE_LIMIT_EXCEEDED';

    // Server errors (5xx)
    case INTERNAL_SERVER_ERROR = 'INTERNAL_SERVER_ERROR';
    case SERVICE_UNAVAILABLE = 'SERVICE_UNAVAILABLE';
    case EXTERNAL_SERVICE_ERROR = 'EXTERNAL_SERVICE_ERROR';
}
```

### Exception Handling

```php
<?php

final class ApiExceptionListener
{
    public function onKernelException(ExceptionEvent $event): void
    {
        $exception = $event->getThrowable();

        $response = match (true) {
            $exception instanceof ValidationException => new JsonResponse([
                'error' => [
                    'code' => 'VALIDATION_ERROR',
                    'message' => 'Validation failed',
                    'details' => $exception->getErrors(),
                ]
            ], Response::HTTP_UNPROCESSABLE_ENTITY),

            $exception instanceof NotFoundException => new JsonResponse([
                'error' => [
                    'code' => 'RESOURCE_NOT_FOUND',
                    'message' => $exception->getMessage(),
                ]
            ], Response::HTTP_NOT_FOUND),

            $exception instanceof AuthenticationException => new JsonResponse([
                'error' => [
                    'code' => 'AUTHENTICATION_REQUIRED',
                    'message' => 'Authentication required',
                ]
            ], Response::HTTP_UNAUTHORIZED),

            default => new JsonResponse([
                'error' => [
                    'code' => 'INTERNAL_SERVER_ERROR',
                    'message' => 'An unexpected error occurred',
                ]
            ], Response::HTTP_INTERNAL_SERVER_ERROR),
        };

        $event->setResponse($response);
    }
}
```

## Pagination

### Query Parameters

```
GET /api/v1/workflows?page=2&limit=20

Parameters:
- page: Page number (default: 1)
- limit: Items per page (default: 20, max: 100)
```

### Pagination Response

```json
{
  "data": [...],
  "meta": {
    "pagination": {
      "total": 250,
      "count": 20,
      "per_page": 20,
      "current_page": 2,
      "total_pages": 13,
      "from": 21,
      "to": 40
    }
  },
  "links": {
    "first": "/api/v1/workflows?page=1&limit=20",
    "last": "/api/v1/workflows?page=13&limit=20",
    "prev": "/api/v1/workflows?page=1&limit=20",
    "next": "/api/v1/workflows?page=3&limit=20"
  }
}
```

### Pagination Implementation

```php
<?php

final class WorkflowController
{
    #[Route('/api/v1/workflows', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $page = max(1, (int) $request->query->get('page', 1));
        $limit = min(100, max(1, (int) $request->query->get('limit', 20)));

        $paginator = $this->workflowRepository->paginate($page, $limit);

        return $this->json([
            'data' => $paginator->getItems(),
            'meta' => [
                'pagination' => [
                    'total' => $paginator->getTotalItems(),
                    'count' => count($paginator->getItems()),
                    'per_page' => $limit,
                    'current_page' => $page,
                    'total_pages' => $paginator->getTotalPages(),
                ]
            ],
            'links' => [
                'first' => $this->generateUrl('workflows_list', ['page' => 1, 'limit' => $limit]),
                'last' => $this->generateUrl('workflows_list', ['page' => $paginator->getTotalPages(), 'limit' => $limit]),
                'prev' => $page > 1 ? $this->generateUrl('workflows_list', ['page' => $page - 1, 'limit' => $limit]) : null,
                'next' => $page < $paginator->getTotalPages() ? $this->generateUrl('workflows_list', ['page' => $page + 1, 'limit' => $limit]) : null,
            ]
        ]);
    }
}
```

## Filtering and Sorting

### Filtering

```
GET /api/v1/workflows?status=active&created_after=2025-01-01

Operators:
- Equals: ?status=active
- In: ?status=active,draft
- Greater than: ?created_after=2025-01-01
- Less than: ?created_before=2025-12-31
- Like: ?name=*customer*
```

### Sorting

```
GET /api/v1/workflows?sort=created_at&order=desc

Parameters:
- sort: Field to sort by
- order: asc (ascending) or desc (descending)

Multiple sorts:
?sort=status,created_at&order=asc,desc
```

### Implementation

```php
<?php

final class WorkflowController
{
    #[Route('/api/v1/workflows', methods: ['GET'])]
    public function list(Request $request): JsonResponse
    {
        $queryBuilder = $this->workflowRepository->createQueryBuilder('w');

        // Filtering
        if ($status = $request->query->get('status')) {
            $queryBuilder->andWhere('w.status = :status')
                ->setParameter('status', $status);
        }

        if ($createdAfter = $request->query->get('created_after')) {
            $queryBuilder->andWhere('w.createdAt >= :createdAfter')
                ->setParameter('createdAfter', new \DateTime($createdAfter));
        }

        // Sorting
        $sort = $request->query->get('sort', 'createdAt');
        $order = $request->query->get('order', 'desc');

        $allowedSorts = ['name', 'status', 'createdAt', 'updatedAt'];
        if (in_array($sort, $allowedSorts)) {
            $queryBuilder->orderBy("w.{$sort}", strtoupper($order));
        }

        return $this->json($queryBuilder->getQuery()->getResult());
    }
}
```

## Versioning

### URL Versioning (Recommended)

```
/api/v1/workflows
/api/v2/workflows

Pros: Clear, easy to route
Cons: Duplicate code for multiple versions
```

### Header Versioning

```
GET /api/workflows
Accept: application/vnd.platform.v1+json

Pros: Clean URLs
Cons: Harder to test, less visible
```

### Version Support Policy

- **Current version (v1)**: Fully supported
- **Previous version**: Supported for 6 months after new version
- **Deprecated versions**: 3 months notice before removal

## Authentication

### JWT Bearer Token

```
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

# Every request must include JWT token
# Token obtained from /auth/login endpoint
```

See [../02-security/03-authentication-authorization.md](../02-security/03-authentication-authorization.md) for complete authentication details.

## Rate Limiting

### Rate Limit Headers

```
X-RateLimit-Limit: 1000        # Max requests per window
X-RateLimit-Remaining: 999     # Remaining requests
X-RateLimit-Reset: 1704628800  # Unix timestamp when limit resets
```

### Rate Limit Tiers

| Tier | Requests/Minute | Requests/Hour |
|------|-----------------|---------------|
| **Free** | 60 | 1,000 |
| **Standard** | 300 | 10,000 |
| **Premium** | 1,000 | 50,000 |

### Rate Limit Exceeded Response

```json
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1704628860
Retry-After: 60

{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Try again in 60 seconds."
  }
}
```

## Documentation

### OpenAPI Specification

```yaml
openapi: 3.0.0
info:
  title: Platform API
  version: 1.0.0
  description: AI Workflow Processing Platform API

servers:
  - url: https://api.platform.com/api/v1
    description: Production
  - url: https://api-staging.platform.com/api/v1
    description: Staging

paths:
  /workflows:
    get:
      summary: List workflows
      tags: [Workflows]
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: limit
          in: query
          schema:
            type: integer
            default: 20
            maximum: 100
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/WorkflowList'

    post:
      summary: Create workflow
      tags: [Workflows]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateWorkflow'
      responses:
        '201':
          description: Workflow created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Workflow'

components:
  schemas:
    Workflow:
      type: object
      properties:
        id:
          type: string
          example: wf-123
        name:
          type: string
          example: My Workflow
        status:
          type: string
          enum: [draft, active, archived]
        created_at:
          type: string
          format: date-time
```

### API Documentation Tools

- **Swagger UI**: Interactive API documentation
- **Redoc**: Beautiful API documentation
- **Postman Collection**: Pre-configured API requests

## Best Practices Summary

1. ✅ Use RESTful resource-oriented URLs
2. ✅ Use appropriate HTTP methods
3. ✅ Return appropriate status codes
4. ✅ Use JSON for request/response
5. ✅ Implement pagination for collections
6. ✅ Support filtering and sorting
7. ✅ Version your API
8. ✅ Require authentication on all endpoints
9. ✅ Implement rate limiting
10. ✅ Provide clear error messages
11. ✅ Document with OpenAPI spec
12. ✅ Use HTTPS only

## References

- [REST API Design Best Practices](https://restfulapi.net/)
- [OpenAPI Specification](https://swagger.io/specification/)
- [HTTP Status Codes](https://httpstatuses.com/)

## Related Documentation

- [../02-security/03-authentication-authorization.md](../02-security/03-authentication-authorization.md) - API authentication
- [../02-security/05-network-security.md](../02-security/05-network-security.md) - API Gateway security
- [03-symfony-best-practices.md](03-symfony-best-practices.md) - Symfony API implementation

---

**Document Maintainers**: Engineering Team, API Team
**Review Cycle**: Quarterly
**Next Review**: 2025-04-07
