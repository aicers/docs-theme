# Sample API Reference

This page exercises visual elements typical of an API reference
document. Use it to verify that styles render correctly in both the
browser and PDF output.

## Authentication

All endpoints require a Bearer token in the `Authorization` header:

```http
Authorization: Bearer <access_token>
```

!!! warning
    Tokens expire after 3600 seconds. Use the refresh endpoint to
    obtain a new token before expiry.

---

## Endpoints

### <span class="method-badge method-get">GET</span> <span class="endpoint-path">/api/v1/customers</span>

Returns a paginated list of customers.

#### Query Parameters

| Name     | Type     | Required | Description                          |
|----------|----------|:--------:|--------------------------------------|
| `page`   | integer  |          | Page number (default: `1`)           |
| `limit`  | integer  |          | Items per page (default: `20`)       |
| `search` | string   |          | Filter by name or email              |
| `sort`   | string   |          | Sort field (`name`, `created_at`)    |
| `order`  | string   |          | Sort direction (`asc` or `desc`)     |

#### Response

=== "200 OK"

    ```json
    {
      "data": [
        {
          "id": "cust_01H8X3YZVK",
          "name": "Acme Corp",
          "email": "contact@acme.example",
          "created_at": "2025-08-14T09:30:00Z"
        }
      ],
      "meta": {
        "page": 1,
        "limit": 20,
        "total": 142
      }
    }
    ```

=== "401 Unauthorized"

    ```json
    {
      "error": {
        "code": "UNAUTHORIZED",
        "message": "Invalid or expired token"
      }
    }
    ```

---

### <span class="method-badge method-post">POST</span> <span class="endpoint-path">/api/v1/customers</span>

Creates a new customer.

#### Request Body

```json
{
  "name": "Acme Corp",
  "email": "contact@acme.example",
  "plan": "enterprise"
}
```

#### Fields

| Name    | Type   | Required | Description                              |
|---------|--------|:--------:|------------------------------------------|
| `name`  | string | Yes      | Customer display name                    |
| `email` | string | Yes      | Primary contact email                    |
| `plan`  | string |          | Subscription plan (`free`, `pro`, `enterprise`) |

#### Response

=== "201 Created"

    ```json
    {
      "data": {
        "id": "cust_01H8X4ABC1",
        "name": "Acme Corp",
        "email": "contact@acme.example",
        "plan": "enterprise",
        "created_at": "2025-08-14T10:00:00Z"
      }
    }
    ```

=== "422 Unprocessable Entity"

    ```json
    {
      "error": {
        "code": "VALIDATION_ERROR",
        "message": "Validation failed",
        "details": [
          { "field": "email", "message": "must be a valid email address" }
        ]
      }
    }
    ```

---

### <span class="method-badge method-put">PUT</span> <span class="endpoint-path">/api/v1/customers/{id}</span>

Replaces the entire customer resource.

#### Path Parameters

| Name | Type   | Description          |
|------|--------|----------------------|
| `id` | string | Customer identifier  |

#### Request Body

```json
{
  "name": "Acme Corporation",
  "email": "admin@acme.example",
  "plan": "pro"
}
```

#### Status Codes

| Code | Description |
|------|-------------|
| <span class="status-2xx">200</span> | Customer updated successfully |
| <span class="status-4xx">404</span> | Customer not found |
| <span class="status-4xx">422</span> | Validation error |
| <span class="status-5xx">500</span> | Internal server error |

---

### <span class="method-badge method-patch">PATCH</span> <span class="endpoint-path">/api/v1/customers/{id}</span>

Partially updates a customer resource. Only provided fields are
modified.

```json
{
  "plan": "enterprise"
}
```

---

### <span class="method-badge method-delete">DELETE</span> <span class="endpoint-path">/api/v1/customers/{id}</span>

Deletes a customer.

!!! danger
    This action is irreversible. All associated data (invoices,
    sessions, audit logs) will be permanently removed.

#### Response

=== "204 No Content"

    No body returned.

=== "404 Not Found"

    ```json
    {
      "error": {
        "code": "NOT_FOUND",
        "message": "Customer not found"
      }
    }
    ```

---

## Error Format

All error responses follow a consistent structure:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable description",
    "details": []
  }
}
```

Error codes
:   Machine-readable uppercase string (e.g. `UNAUTHORIZED`,
    `VALIDATION_ERROR`, `NOT_FOUND`).

Details
:   Optional array of field-level errors, present only for
    validation failures.

---

## Rate Limiting

The API enforces rate limits per access token:

| Plan       | Requests/min | Burst |
|------------|-------------:|------:|
| Free       |           60 |   100 |
| Pro        |          600 |  1000 |
| Enterprise |         6000 | 10000 |

!!! info
    Rate limit headers are included in every response:

    - `X-RateLimit-Limit` — maximum requests per window
    - `X-RateLimit-Remaining` — requests remaining
    - `X-RateLimit-Reset` — UTC epoch seconds when the window resets

When the limit is exceeded the API returns:

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 30
```

---

## Pagination

List endpoints support cursor-based pagination:

```http
GET /api/v1/customers?limit=20&after=cust_01H8X3YZVK
```

!!! tip
    Prefer cursor-based pagination (`after` / `before`) over
    offset-based (`page`) for large datasets. Cursors remain stable
    even when records are inserted or deleted between requests.

---

## Changelog

- [x] `v1.4.0` — Add `PATCH` support for partial updates
- [x] `v1.3.0` — Add cursor-based pagination
- [x] `v1.2.0` — Add rate limiting headers
- [ ] `v1.5.0` — Webhook event subscriptions (planned)

---

## Footnotes

The API follows REST conventions[^1] and uses JSON:API-inspired
error formatting[^2].

[^1]: Fielding, R. T. (2000). *Architectural Styles and the Design
      of Network-based Software Architectures*. Doctoral
      dissertation, University of California, Irvine.
[^2]: The error envelope is inspired by JSON:API but does not
      implement the full specification.
