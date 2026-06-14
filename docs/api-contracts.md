# KPB Education relaunch API contracts

These are the working contracts represented in the current scaffolding.

## Profiles

- `GET /profiles/me`
- `PATCH /profiles/me`

Purpose:
- load the current user profile
- progressively enrich profile data after onboarding

## Orientation

- `POST /orientation/sessions`
- `GET /orientation/results/:id`

Purpose:
- submit guided orientation answers
- retrieve scored recommendations and next actions

## Catalog

- `GET /catalog/fields`
- `GET /catalog/countries`
- `GET /catalog/institutions`
- `GET /catalog/programs`
- `GET /catalog/scholarships`

Purpose:
- feed Explore, Scholarships, and recommendation surfaces

## Content

- `GET /content/service-offers`
- `GET /content/support-destinations`
- `GET /content/articles`

Purpose:
- feed the mobile relaunch with dashboard-managed offers, destination coverage, and editorial content

## Community

- `GET /community/forum-categories`
- `GET /community/forum-tags`

Purpose:
- expose dashboard-managed forum taxonomy to the mobile community layer

## Cases

- `GET /cases`
- `GET /cases/:id`
- `POST /cases`
- `PATCH /cases/:id`
- `GET /cases/:id/messages`
- `POST /cases/:id/messages`
- `POST /cases/:id/documents`

Purpose:
- create and manage the unified student-facing `My Cases` experience
- support counselor/admin updates, service messaging, and document handling

## Admin case operations

- `GET /admin/cases`
- `POST /admin/cases/:id/assign`
- `POST /admin/cases/:id/tasks`
- `POST /admin/cases/:id/internal-notes`
- `POST /admin/cases/:id/timeline-events`

Purpose:
- power counselor and admin case ownership, internal workflow, and operational follow-up

## Appointments

- `GET /appointments`
- `POST /appointments`

Purpose:
- schedule counseling and mentoring sessions linked to cases

## Saved Items

- `GET /saved-items`
- `POST /saved-items`
- `DELETE /saved-items/:id`

Purpose:
- persist saved countries, fields, programs, institutions, and scholarships

## Partner leads

- `GET /partner-leads`
- `POST /partner-leads`

Purpose:
- support lightweight partner acquisition outside the student case flow

## Admin content operations

- `GET /admin/service-offers`
- `POST /admin/service-offers`
- `PATCH /admin/service-offers/:id`
- `GET /admin/support-destinations`
- `POST /admin/support-destinations`
- `PATCH /admin/support-destinations/:id`
- `GET /admin/articles`
- `POST /admin/articles`
- `PATCH /admin/articles/:id`
- `GET /admin/forum-categories`
- `POST /admin/forum-categories`
- `PATCH /admin/forum-categories/:id`
- `GET /admin/forum-tags`
- `POST /admin/forum-tags`
- `PATCH /admin/forum-tags/:id`
- `GET /admin/forum-moderation`

Purpose:
- let operations teams add service offers, destination coverage, articles, forum categories, and topic tags from the dashboard

## Admin notifications

- `GET /admin/notifications/templates`
- `POST /admin/notifications/templates`
- `PATCH /admin/notifications/templates/:id`
- `GET /admin/notifications/campaigns`
- `POST /admin/notifications/campaigns`
- `GET /admin/notifications/campaigns/:id/deliveries`

Purpose:
- manage grouped or specific campaigns across push, in-app, and email channels
- attach critical campaign events to case timelines when needed

## Admin users and reporting

- `GET /admin/users`
- `POST /admin/users`
- `PATCH /admin/users/:id`
- `GET /admin/reports/overview`
- `GET /admin/reports/funnel`
- `GET /admin/reports/counselor-performance`
- `GET /admin/reports/campaign-performance`

Purpose:
- manage internal roles and provide the first reporting layer for cases, counseling, and campaigns
