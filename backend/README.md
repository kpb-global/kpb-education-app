# KPB Education API

NestJS API scaffold for the KPB Education relaunch.

## Target responsibilities

- auth and user profiles
- orientation sessions and results
- catalogs: fields, countries, institutions, programs, scholarships
- cases, case messages, case timeline events
- counselor/admin operational actions

## Current state

The API now exposes scaffolded relaunch modules for:

- `GET/PATCH /profiles/me`
- `POST /orientation/sessions`
- `GET /orientation/results/:id`
- `GET /catalog/*`
- `GET/POST/PATCH /cases`
- `GET/POST /cases/:id/messages`
- `POST /cases/:id/documents`
- `GET/POST /appointments`
- `GET/POST/DELETE /saved-items`
- `GET/POST /partner-leads`

It still needs:

- dependency installation
- persistence wiring
- auth guards and RBAC
- document upload integration
- push notification jobs
- queue-based background processing
