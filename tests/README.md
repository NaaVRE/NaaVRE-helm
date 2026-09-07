# NaaVRE UI Tests


## Running Tests

First go to the tests' directory:

```bash
cd tests
```
end-to-end tests:
```bash
npx playwright test
```    
Interactive UI mode:
```bash
npx playwright test --ui
``` 

Test only on Desktop Chrome:
```bash
  npx playwright test --project=chromium
```
Run the tests in a specific file:
```bash
npx playwright test example
```
Run the tests in debug mode:
```bash
  npx playwright test --debug
```

Auto generate tests with Codegen:
```bash
  npx playwright codegen
```


And check out the following files:
  - ./e2e/example.spec.ts - Example end-to-end test
  - ./playwright.config.ts - Playwright Test configuration

Visit https://playwright.dev/docs/intro for more information. 



## Planned Test Coverage

The following features are planned to be tested:

- [x] Basic navigation to VRE app
- [x] Login functionality
- [ ] Browse labs
- [ ] Create notebook
- [ ] Create containers
- [ ] Build workflow
- [ ] Execute workflow

## Screenshots

Test screenshots are saved to the `screenshots/` directory during test runs.


