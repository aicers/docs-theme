# 샘플 API 레퍼런스

이 페이지는 API 레퍼런스 문서에서 흔히 사용하는 시각 요소를 포함합니다.
브라우저와 PDF 출력에서 스타일이 올바르게 렌더링되는지 확인하는 데
사용합니다.

## 인증

모든 엔드포인트는 `Authorization` 헤더에 Bearer 토큰이 필요합니다:

```http
Authorization: Bearer <access_token>
```

!!! warning
    토큰은 3600초 후에 만료됩니다. 만료 전에 갱신 엔드포인트를
    사용하여 새 토큰을 발급받으세요.

---

## 엔드포인트

### <span class="method-badge method-get">GET</span> <span class="endpoint-path">/api/v1/customers</span>

고객 목록을 페이지 단위로 반환합니다.

#### 쿼리 파라미터

| 이름     | 타입     | 필수 | 설명                                |
|----------|----------|:----:|-------------------------------------|
| `page`   | integer  |      | 페이지 번호 (기본값: `1`)            |
| `limit`  | integer  |      | 페이지당 항목 수 (기본값: `20`)       |
| `search` | string   |      | 이름 또는 이메일로 필터               |
| `sort`   | string   |      | 정렬 필드 (`name`, `created_at`)     |
| `order`  | string   |      | 정렬 방향 (`asc` 또는 `desc`)        |

#### 응답

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
        "message": "유효하지 않거나 만료된 토큰입니다"
      }
    }
    ```

---

### <span class="method-badge method-post">POST</span> <span class="endpoint-path">/api/v1/customers</span>

새 고객을 생성합니다.

#### 요청 본문

```json
{
  "name": "Acme Corp",
  "email": "contact@acme.example",
  "plan": "enterprise"
}
```

#### 필드

| 이름    | 타입   | 필수 | 설명                                          |
|---------|--------|:----:|-----------------------------------------------|
| `name`  | string | 예   | 고객 표시 이름                                 |
| `email` | string | 예   | 기본 연락처 이메일                              |
| `plan`  | string |      | 구독 플랜 (`free`, `pro`, `enterprise`)        |

#### 응답

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
        "message": "유효성 검사 실패",
        "details": [
          { "field": "email", "message": "올바른 이메일 주소여야 합니다" }
        ]
      }
    }
    ```

---

### <span class="method-badge method-put">PUT</span> <span class="endpoint-path">/api/v1/customers/{id}</span>

고객 리소스 전체를 교체합니다.

#### 경로 파라미터

| 이름 | 타입   | 설명           |
|------|--------|----------------|
| `id` | string | 고객 식별자     |

#### 요청 본문

```json
{
  "name": "Acme Corporation",
  "email": "admin@acme.example",
  "plan": "pro"
}
```

#### 상태 코드

| 코드 | 설명 |
|------|------|
| <span class="status-2xx">200</span> | 고객 업데이트 성공 |
| <span class="status-4xx">404</span> | 고객을 찾을 수 없음 |
| <span class="status-4xx">422</span> | 유효성 검사 오류 |
| <span class="status-5xx">500</span> | 내부 서버 오류 |

---

### <span class="method-badge method-patch">PATCH</span> <span class="endpoint-path">/api/v1/customers/{id}</span>

고객 리소스를 부분 업데이트합니다. 제공된 필드만 수정됩니다.

```json
{
  "plan": "enterprise"
}
```

---

### <span class="method-badge method-delete">DELETE</span> <span class="endpoint-path">/api/v1/customers/{id}</span>

고객을 삭제합니다.

!!! danger
    이 작업은 되돌릴 수 없습니다. 관련된 모든 데이터(청구서, 세션,
    감사 로그)가 영구적으로 제거됩니다.

#### 응답

=== "204 No Content"

    본문 없음.

=== "404 Not Found"

    ```json
    {
      "error": {
        "code": "NOT_FOUND",
        "message": "고객을 찾을 수 없습니다"
      }
    }
    ```

---

## 오류 형식

모든 오류 응답은 일관된 구조를 따릅니다:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "사람이 읽을 수 있는 설명",
    "details": []
  }
}
```

오류 코드
:   기계가 읽을 수 있는 대문자 문자열입니다 (예: `UNAUTHORIZED`,
    `VALIDATION_ERROR`, `NOT_FOUND`).

상세 정보
:   필드 수준 오류의 선택적 배열로, 유효성 검사 실패 시에만
    포함됩니다.

---

## 속도 제한

API는 액세스 토큰당 속도 제한을 적용합니다:

| 플랜       | 요청/분    | 버스트  |
|-----------|----------:|-------:|
| Free      |        60 |    100 |
| Pro       |       600 |  1,000 |
| Enterprise|     6,000 | 10,000 |

!!! info
    속도 제한 헤더가 모든 응답에 포함됩니다:

    - `X-RateLimit-Limit` — 윈도우당 최대 요청 수
    - `X-RateLimit-Remaining` — 남은 요청 수
    - `X-RateLimit-Reset` — 윈도우가 초기화되는 UTC epoch 초

제한을 초과하면 API는 다음을 반환합니다:

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 30
```

---

## 페이지네이션

목록 엔드포인트는 커서 기반 페이지네이션을 지원합니다:

```
GET /api/v1/customers?limit=20&after=cust_01H8X3YZVK
```

!!! tip
    대용량 데이터셋에는 오프셋 기반(`page`)보다 커서 기반(`after` /
    `before`) 페이지네이션을 권장합니다. 요청 사이에 레코드가
    추가되거나 삭제되어도 커서는 안정적으로 유지됩니다.

---

## 변경 이력

- [x] `v1.4.0` — 부분 업데이트를 위한 `PATCH` 지원 추가
- [x] `v1.3.0` — 커서 기반 페이지네이션 추가
- [x] `v1.2.0` — 속도 제한 헤더 추가
- [ ] `v1.5.0` — 웹훅 이벤트 구독 (계획)

---

## 각주

이 API는 REST 규약[^1]을 따르며 JSON:API에서 영감을 받은 오류
형식[^2]을 사용합니다.

[^1]: Fielding, R. T. (2000). *Architectural Styles and the Design
      of Network-based Software Architectures*. 박사 학위 논문,
      University of California, Irvine.
[^2]: 오류 엔벨로프는 JSON:API에서 영감을 받았지만 전체 사양을
      구현하지는 않습니다.
