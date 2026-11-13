# PRD: Dayframe (dayframe-scheduler)

Tagline: "Frame your day. Schedule your story."

## 1. Overview
Dayframe is an iPhone app for planning, scheduling, and publishing social media posts across multiple channels from one place, with a Buffer-like experience: a simple queue, a calendar, a fast composer, and basic analytics.

## 2. Problem
Creators, freelancers, and small teams post to several platforms and lose time switching apps, remembering when to post, and tracking results. Existing tools are desktop-first or heavy on mobile.

## 3. Target Users
- Solo creators and freelancers (primary)
- Small business owners and social media managers (secondary)

## 4. Goals
- Compose once, publish to many channels
- Schedule by queue slot or specific date/time
- See everything planned in Queue and Calendar
- Understand performance with simple analytics
- Feel fast, calm, and clean on iPhone

## 5. Non-Goals (v1)
- Android or web app
- Team approvals, multi-user workspaces
- Inbox / comment replies
- Video editing, link-in-bio pages
- Paid ad management

## 6. MVP Features
| ID | Feature | Priority |
|----|---------|----------|
| F1 | Email, Apple, and Google sign-in | P0 |
| F2 | Onboarding (3 pages) | P1 |
| F3 | Connect channels via OAuth (start: Instagram, X, LinkedIn) | P0 |
| F4 | Queue view with channel filter chips, grouped by day | P0 |
| F5 | Composer: multi-channel select, text, media, character counters, per-platform preview | P0 |
| F6 | Scheduling: add to queue, custom date/time, post now | P0 |
| F7 | Drafts and Failed-post retry | P0 |
| F8 | Calendar month and week views | P1 |
| F9 | Post detail: edit, reschedule, delete, duplicate | P0 |
| F10 | Analytics: followers, reach, engagement, clicks, top posts | P1 |
| F11 | Posting schedule editor (weekly time slots) | P0 |
| F12 | Push notifications (published, failed) | P1 |
| F13 | Settings: theme, notifications, logout, delete account | P0 |
| F14 | Subscription (Free / Pro) | P2 |

Later phases add TikTok, YouTube, Facebook.

## 7. Plan Tiers (product decision, adjustable)
- Free: 3 channels, 10 scheduled posts per channel
- Pro: unlimited channels and scheduled posts, full analytics ranges

## 8. User Stories
- As a creator, I connect my accounts once so I can post to all of them.
- As a creator, I write one post and tailor it per platform.
- As a creator, I set weekly time slots so "Add to queue" picks the next free slot.
- As a creator, I get notified when a post fails and can retry in one tap.
- As a creator, I see my week in a calendar to avoid gaps.

## 9. Success Metrics
- Activation: signs up and connects 1 channel within first session
- Core action: 3+ posts scheduled in first 7 days
- Reliability: at least 99% of due posts published within 2 minutes of scheduled time
- Retention: weekly active scheduling users

## 10. Risks
- Platform API access, review, and rate limits (Meta, TikTok especially)
- Token expiry and revoked access
- App Store review for sign-in and subscription rules
- Publishing correctness across time zones

## 11. Related Docs
See `../agent.md` for the doc map.
