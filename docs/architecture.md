# KPB Education architecture snapshot

## Product backbone

- Mobile app: Flutter
- API: NestJS + PostgreSQL + Redis + S3-compatible storage
- Admin web: Next.js

## Core runtime domain

- `UserProfile`
- `OrientationSession`
- `Field`
- `Country`
- `Institution`
- `Program`
- `Scholarship`
- `Case`
- `CaseMessage`
- `CaseTimelineEvent`
- `CaseTask`
- `CaseDocument`
- `CaseInternalNote`
- `Appointment`
- `SavedItem`
- `PartnerLead`
- `ServiceOffer`
- `SupportDestination`
- `Article`
- `ForumCategory`
- `ForumTopicTag`
- `NotificationTemplate`
- `NotificationCampaign`
- `NotificationDelivery`

## Case-first operating model

Every serious conversion flow should create a `Case`.

Case types:

- consultation
- application_support
- scholarship_support
- housing_support
- mentorship

## Mobile implementation note

The Flutter relaunch now has:

- a centralized `AppController`
- local persistence for onboarding, profile, saved items, cases, and orientation history
- a dedicated API client boundary
- mock catalog content still used for the current demo experience
- new relaunch content types for service offers, support destinations, articles, forum categories, and forum tags
- a dedicated `Community` screen and additional home/explore surfaces for dashboard-managed content

The next implementation wave should move from local-first mock data to live repositories backed by the relaunch API.

## Current backend implementation note

The backend now exposes scaffolded relaunch endpoints for:

- profiles
- orientation sessions/results
- catalog resources
- cases, messages, and document uploads
- admin case assignment, tasks, notes, and timeline events
- content resources and admin content CRUD
- community taxonomy and moderation queue
- notification templates, campaigns, and deliveries
- admin users and operational reporting
- appointments
- saved items
- partner leads

It still needs production persistence, auth, storage, queueing, and notification wiring.

## Current admin implementation note

The admin workspace remains a structural scaffold for:

- overview metrics
- case operations
- content operations
- community operations
- notification campaigns
- user and role operations
- reporting

## Operational note

Counselor/admin actions are intended for the web workspace, not the mobile app.
