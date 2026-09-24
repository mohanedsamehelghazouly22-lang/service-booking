# Supabase production setup notes

The connected project `booking-app` was inspected and prepared for this application.

## Auth

Enable:
- Google OAuth
- Phone OTP

Android redirect URI:
`io.supabase.servicebooking://login-callback/`

Phone OTP also requires an SMS provider configured in Supabase Auth.

## Backend rules

Implemented server-side rules include:
- Atomic slot reservation
- One active booking per slot
- Instant vs pending booking behavior per location
- 4-hour pending confirmation window measured from `created_at`
- Server-side pending expiration via pg_cron every 5 minutes
- Provider confirmation validation
- Customer cancellation restriction when appointment is 3 hours or less away
- Provider cancellation audit trail
- Realtime tables for bookings, availability, notifications
- RLS on exposed public tables

## Storage

Bucket:
`service-images`

It is public for service/location display images; uploads/updates/deletes are restricted to Super Users.

## Important production note

Push delivery requires a real FCM project and server-side credentials. Never place FCM server credentials or Supabase secret/service-role keys in the Android app.
