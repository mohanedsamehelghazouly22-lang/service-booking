# Service Booking App — Flutter + Supabase

Production-oriented Android service booking application built with Flutter and Supabase.

## Backend already prepared

The connected Supabase project used by this build is:

`https://lybbdqwgfjekrqhhgdkf.supabase.co`

The database has been prepared for:

- Customer / Provider / Super User roles
- Services and service locations
- Provider-location assignments
- Availability slots
- Pending and instant booking modes
- 4-hour pending confirmation expiry
- 3-hour customer cancellation restriction
- Atomic booking creation and double-booking protection
- Provider confirmation and cancellation audit trail
- Notifications table and Realtime-enabled operational tables
- Supabase Storage bucket for service/location images
- RLS policies

The mobile client uses only the Supabase publishable key. Never put a service-role/secret key in the Android app.

## Open in GitHub

Upload the contents of this folder to a GitHub repository. The included GitHub Actions workflow will generate the Android platform files, analyze the Flutter project, build a release APK, and publish the APK as an Actions artifact.

## Local build

Requires Flutter stable 3.44+ and Android SDK.

```bash
flutter pub get
flutter create . --platforms=android --org com.servicebooking --project-name service_booking_app
flutter analyze
flutter build apk --release
```

APK output:

`build/app/outputs/flutter-apk/app-release.apk`

## Supabase Auth configuration

Enable Google and Phone authentication in the Supabase dashboard.

For Google OAuth on Android, configure the redirect URI:

`io.supabase.servicebooking://login-callback/`

The Android intent filter is automatically added by the GitHub Actions build workflow.

Phone OTP requires a configured Supabase SMS provider.

## Push notifications

The database includes `notifications` and `user_devices`. For production push delivery, connect Firebase Cloud Messaging and deploy a protected Supabase Edge Function that sends FCM messages from notification events. FCM credentials must remain server-side.

## Design direction

The UI follows the supplied reference direction: dark surfaces, warm orange accent, rounded cards, image-led service browsing, clear status pills, and compact mobile navigation. All application copy is English.
