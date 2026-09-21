# Masar mobile

See the [project README](../README.md) for setup and the [RevenueCat guide](../docs/REVENUECAT.md) for subscriptions.

```bash
flutter pub get
cp config.example.json config.json
flutter run --dart-define-from-file=config.json
```

Local preferences store language/theme. Account sessions use secure storage. Demo mode is temporary and isolated from the backend.
