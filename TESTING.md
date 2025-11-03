# Testing Guide

This document describes the testing setup for the English Learning App.

## Test Structure

### Unit Tests
- **Providers**: `test/providers/`
  - `coin_provider_test.dart` - Tests for coin management
  - `theme_provider_test.dart` - Tests for theme management
  - `shop_provider_test.dart` - Tests for shop functionality

- **Models**: `test/models/`
  - `word_data_test.dart` - Tests for WordData model
  - `product_test.dart` - Tests for Product model

- **Services**: `test/services/`
  - `achievement_service_test.dart` - Tests for achievement system

### Widget Tests
- **Widgets**: `test/widgets/`
  - `score_display_test.dart` - Tests for ScoreDisplay widget

- **Integration**: `test/widget_test.dart` - App initialization tests

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/providers/coin_provider_test.dart
```

### Run with coverage
```bash
flutter test --coverage
```

### View coverage report
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## CI/CD

Tests automatically run on:
- Pull requests to `main` or `develop` branches
- Pushes to `main` or `develop` branches

The GitHub Actions workflow (`.github/workflows/test.yml`) runs:
1. Code formatting check
2. Static analysis (`flutter analyze`)
3. All unit and widget tests
4. Coverage report generation

## Test Coverage

Current test coverage includes:
- ✅ Coin provider (add, spend, load, save)
- ✅ Theme provider (toggle, load, save)
- ✅ Shop provider (purchase, load, save)
- ✅ Achievement service (unlock, check)
- ✅ Models (WordData, Product)
- ✅ ScoreDisplay widget

## Adding New Tests

When adding new features:
1. Create unit tests for business logic
2. Create widget tests for UI components
3. Ensure tests use `SharedPreferences.setMockInitialValues({})` for isolation
4. Run tests locally before committing

## Best Practices

1. **Test Isolation**: Each test should be independent
2. **Mock Data**: Use `SharedPreferences.setMockInitialValues()` for storage
3. **Async Testing**: Properly await async operations
4. **Clear Names**: Use descriptive test names
5. **Coverage**: Aim for >80% coverage on business logic

