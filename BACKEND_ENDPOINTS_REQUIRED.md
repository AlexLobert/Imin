# Comprehensive Backend Endpoints Required for "I'm In" App

This document lists all backend endpoints needed to support the full functionality of the iOS app.

## ✅ Already Implemented

### Authentication
- `POST /create_account` - Create new user account
- `POST /login` - Authenticate user
- `POST /logout` - End user session

### Status/Availability
- `GET /status` - Get current user's status (In/Out)
- `POST /set_status` - Update user's status

---

## 🔴 Required Endpoints

### 1. User Profile Management

#### Get Current User Profile
```
GET /profile
Response: {
  "user_id": "string",
  "email": "string",
  "name": "string" | null,
  "handle": "string" | null,
  "avatar_url": "string" | null,
  "created_at": "ISO8601 datetime"
}
```

#### Update User Profile
```
PATCH /profile
Request: {
  "name": "string" | null,
  "handle": "string" | null,
  "avatar_url": "string" | null
}
Response: Updated profile object
```

#### Get User by ID
```
GET /users/{user_id}
Response: {
  "user_id": "string",
  "name": "string" | null,
  "handle": "string" | null,
  "avatar_url": "string" | null,
  "status": "In" | "Out"
}
```

---

### 2. Circles Management

#### List User's Circles
```
GET /circles
Response: [
  {
    "circle_id": "UUID",
    "name": "string",
    "member_count": "integer",
    "created_at": "ISO8601 datetime"
  }
]
```

#### Get Circle Details
```
GET /circles/{circle_id}
Response: {
  "circle_id": "UUID",
  "name": "string",
  "members": [
    {
      "user_id": "string",
      "name": "string",
      "handle": "string" | null,
      "avatar_url": "string" | null
    }
  ],
  "created_at": "ISO8601 datetime"
}
```

#### Create Circle
```
POST /circles
Request: {
  "name": "string"
}
Response: Created circle object
```

#### Update Circle
```
PATCH /circles/{circle_id}
Request: {
  "name": "string"
}
Response: Updated circle object
```

#### Delete Circle
```
DELETE /circles/{circle_id}
Response: { "message": "Circle deleted" }
```

#### Add Member to Circle
```
POST /circles/{circle_id}/members
Request: {
  "user_id": "string"
}
Response: { "message": "Member added" }
```

#### Remove Member from Circle
```
DELETE /circles/{circle_id}/members/{user_id}
Response: { "message": "Member removed" }
```

---

### 3. Friends Management

#### List Friends
```
GET /friends
Response: [
  {
    "user_id": "string",
    "name": "string",
    "handle": "string" | null,
    "avatar_url": "string" | null,
    "status": "In" | "Out"
  }
]
```

#### Send Friend Request
```
POST /friends/requests
Request: {
  "user_id": "string" | "handle": "string"
}
Response: { "message": "Friend request sent" }
```

#### Accept Friend Request
```
POST /friends/requests/{request_id}/accept
Response: { "message": "Friend request accepted" }
```

#### Reject Friend Request
```
POST /friends/requests/{request_id}/reject
Response: { "message": "Friend request rejected" }
```

#### Remove Friend
```
DELETE /friends/{user_id}
Response: { "message": "Friend removed" }
```

#### Search Users
```
GET /users/search?q={query}
Response: [
  {
    "user_id": "string",
    "name": "string",
    "handle": "string" | null,
    "avatar_url": "string" | null
  }
]
```

---

### 4. Visibility/Audience Management

#### Get Visibility Settings
```
GET /visibility
Response: {
  "mode": "everyone" | "circles",
  "circle_ids": ["UUID"] | null
}
```

#### Update Visibility Settings
```
PUT /visibility
Request: {
  "mode": "everyone" | "circles",
  "circle_ids": ["UUID"] | null
}
Response: Updated visibility settings
```

---

### 5. Chat/Messaging

#### Get Users Currently "In"
```
GET /users/in
Response: [
  {
    "user_id": "string",
    "name": "string",
    "handle": "string",
    "status": "In"
  }
]
```

#### List Chat Threads
```
GET /threads
Query params:
  - filter: "all" | "unread" | "in_now" (optional)
Response: [
  {
    "thread_id": "UUID",
    "title": "string",
    "participant_id": "string",
    "last_message": "string" | null,
    "last_message_at": "ISO8601 datetime" | null,
    "updated_at": "ISO8601 datetime",
    "unread_count": "integer",
    "in_count": "integer" (number of participants currently "In")
  }
]
```

#### Get Thread Details
```
GET /threads/{thread_id}
Response: {
  "thread_id": "UUID",
  "title": "string",
  "participants": [
    {
      "user_id": "string",
      "name": "string",
      "handle": "string" | null,
      "avatar_url": "string" | null,
      "status": "In" | "Out"
    }
  ],
  "created_at": "ISO8601 datetime",
  "updated_at": "ISO8601 datetime"
}
```

#### Create or Get Thread with User
```
POST /threads
Request: {
  "participant_id": "string"
}
Response: Thread object (creates if doesn't exist, returns existing if found)
```

#### Get Messages in Thread
```
GET /threads/{thread_id}/messages
Query params:
  - limit: integer (optional, default: 50)
  - before: ISO8601 datetime (optional, for pagination)
Response: [
  {
    "message_id": "UUID",
    "thread_id": "UUID",
    "sender_id": "string",
    "body": "string",
    "created_at": "ISO8601 datetime"
  }
]
```

#### Send Message
```
POST /threads/{thread_id}/messages
Request: {
  "body": "string"
}
Response: Created message object
```

#### Mark Thread as Read
```
POST /threads/{thread_id}/read
Response: { "message": "Thread marked as read" }
```

---

### 6. Status Expiration

#### Get Status Expiration
```
GET /status/expiration
Response: {
  "expires_at": "ISO8601 datetime" | null
}
```

#### Update Status with Expiration
```
POST /set_status
Request: {
  "status": "In" | "Out",
  "expires_at": "ISO8601 datetime" | null (optional, defaults to 8 hours from now for "In")
}
Response: {
  "status": "In" | "Out",
  "expires_at": "ISO8601 datetime" | null
}
```

---

## 📋 Additional Considerations

### Authentication
All endpoints (except `/create_account` and `/login`) require authentication via:
- Cookie-based session (current implementation)
- OR Bearer token in `Authorization` header

### Error Responses
All endpoints should return standardized error responses:
```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {} // Optional additional error details
  }
}
```

### Pagination
Endpoints that return lists should support pagination:
- Query params: `limit` (default: 20, max: 100), `offset` or `cursor`
- Response includes: `items`, `total`, `has_more`, `next_cursor`

### Real-time Updates (Future)
Consider WebSocket support for:
- Real-time status updates
- New messages
- Friend requests
- Thread updates

### Rate Limiting
Implement rate limiting on:
- Authentication endpoints
- Message sending
- Status updates

---

## 🔄 Data Models Needed

### User
- `user_id` (UUID or integer)
- `email` (string, unique)
- `name` (string, nullable)
- `handle` (string, nullable, unique)
- `avatar_url` (string, nullable)
- `status` (enum: "In" | "Out")
- `status_expires_at` (datetime, nullable)
- `created_at` (datetime)
- `updated_at` (datetime)

### Circle
- `circle_id` (UUID)
- `user_id` (foreign key)
- `name` (string)
- `created_at` (datetime)
- `updated_at` (datetime)

### CircleMember
- `circle_id` (foreign key)
- `user_id` (foreign key)
- `created_at` (datetime)

### Friend
- `user_id` (foreign key)
- `friend_id` (foreign key)
- `status` (enum: "pending" | "accepted" | "blocked")
- `created_at` (datetime)

### Thread
- `thread_id` (UUID)
- `title` (string, nullable)
- `created_at` (datetime)
- `updated_at` (datetime)

### ThreadMember
- `thread_id` (foreign key)
- `user_id` (foreign key)
- `last_read_at` (datetime, nullable)
- `joined_at` (datetime)

### Message
- `message_id` (UUID)
- `thread_id` (foreign key)
- `sender_id` (foreign key)
- `body` (text)
- `created_at` (datetime)

### VisibilitySettings
- `user_id` (foreign key, unique)
- `mode` (enum: "everyone" | "circles")
- `updated_at` (datetime)

---

## 🎯 Priority Order

### Phase 1 (Critical - App Won't Work Without These)
1. ✅ Authentication (already done)
2. ✅ Status endpoints (already done)
3. Get Users Currently "In" (`GET /users/in`)
4. List Chat Threads (`GET /threads`)
5. Get Messages (`GET /threads/{thread_id}/messages`)
6. Send Message (`POST /threads/{thread_id}/messages`)
7. Create/Get Thread (`POST /threads`)

### Phase 2 (Important - Core Features)
8. Circles CRUD (`GET /circles`, `POST /circles`, `PATCH /circles/{id}`, `DELETE /circles/{id}`)
9. Circle Members (`POST /circles/{id}/members`, `DELETE /circles/{id}/members/{user_id}`)
10. Visibility Settings (`GET /visibility`, `PUT /visibility`)
11. User Profile (`GET /profile`, `PATCH /profile`)
12. Search Users (`GET /users/search`)

### Phase 3 (Nice to Have)
13. Friends Management (`GET /friends`, `POST /friends/requests`, etc.)
14. Mark Thread as Read (`POST /threads/{thread_id}/read`)
15. Status Expiration (`GET /status/expiration`)

---

## 📝 Notes

- The app currently uses Supabase for chat functionality, but these endpoints would replace that dependency
- Circles are currently hardcoded in the frontend - these endpoints would enable real persistence
- Visibility settings are stored in `@AppStorage` - should be synced with backend
- Consider implementing WebSocket/SSE for real-time updates in future iterations
