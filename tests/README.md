# NaaVRE UI Tests

This directory contains Playwright tests for the NaaVRE UI to replicate user behavior in a Minikube environment.

## Prerequisites

- Node.js (v18 or later recommended)
- npm or yarn
- Access to a running NaaVRE instance (e.g., Minikube with NaaVRE deployed)

## Setup

1. Navigate to the tests directory:
   ```bash
   cd tests
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Install Playwright browsers:
   ```bash
   npx playwright install
   ```

## Running Tests

### Using the default URL (https://naavre-dev.minikube.test)

```bash
npm test
```

### Using a custom URL

```bash
BASE_URL=https://your-custom-url.test npm test
```

### Run tests in headed mode (see the browser)

```bash
npm run test:headed
```

### Run tests in UI mode (interactive)

```bash
npm run test:ui
```

### Debug tests

```bash
npm run test:debug
```

## Test Structure

- `playwright.config.ts` - Playwright configuration
- `specs/` - Test specifications
  - `basic.spec.ts` - Basic UI tests for navigating to VRE app

## Planned Test Coverage

The following features are planned to be tested:

- [x] Basic navigation to VRE app
- [ ] Login functionality
- [ ] Browse labs
- [ ] Create notebook
- [ ] Create containers
- [ ] Build workflow
- [ ] Execute workflow

## Screenshots

Test screenshots are saved to the `screenshots/` directory during test runs.

## Configuration

The tests use the following default configuration:
- Base URL: `https://naavre-dev.minikube.test` (can be overridden with `BASE_URL` env var)
- HTTPS errors are ignored (for self-signed certificates in test environments)
- Tests run in Chromium by default

You can modify these settings in `playwright.config.ts`.

## Troubleshooting

### HTTPS Certificate Errors

If you encounter certificate errors, make sure `ignoreHTTPSErrors: true` is set in `playwright.config.ts`.

### Connection Refused

If tests fail with connection refused errors:
1. Verify the NaaVRE instance is running
2. Check that the URL is accessible from your machine
3. Verify DNS/hosts file configuration for Minikube domains

### Running in CI

When running in CI (GitHub Actions), set the `CI` environment variable. This will:
- Enable test retries (2 retries)
- Run tests sequentially (workers: 1)
- Forbid `.only` in test files
