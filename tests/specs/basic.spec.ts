import { test, expect } from '@playwright/test';

/**
 * Simple UI test for NaaVRE application
 * Tests basic navigation to the VRE app
 */
test.describe('NaaVRE UI Basic Tests', () => {
  
  test('should load the VRE app page successfully', async ({ page }) => {
    // Navigate to the VRE app
    const response = await page.goto('/vreapp');
    
    // Verify the page loaded successfully with a valid HTTP status
    expect(response?.status()).toBeLessThan(400);
    
    // Wait for the page to load
    await page.waitForLoadState('networkidle');
    
    // Take a screenshot for verification (Playwright creates directories automatically)
    await page.screenshot({ path: 'test-results/screenshots/vreapp-loaded.png', fullPage: true });
    
    // Verify the URL contains vreapp
    expect(page.url()).toContain('vreapp');
  });

  test('should have a valid page title', async ({ page }) => {
    // Navigate to the VRE app
    const response = await page.goto('/vreapp');
    
    // Verify the page loaded successfully
    expect(response?.status()).toBeLessThan(400);
    
    // Wait for the page to load
    await page.waitForLoadState('domcontentloaded');
    
    // Check that the page has a title (not empty)
    const title = await page.title();
    expect(title).toBeTruthy();
    expect(title.length).toBeGreaterThan(0);
  });

  test('should navigate to the root URL and display main page', async ({ page }) => {
    // Navigate to the base URL
    const response = await page.goto('/');
    
    // Verify the page loaded successfully with a valid HTTP status
    expect(response?.status()).toBeLessThan(400);
    
    // Wait for the page to load
    await page.waitForLoadState('networkidle');
    
    // Take a screenshot (Playwright creates directories automatically)
    await page.screenshot({ path: 'test-results/screenshots/main-page.png', fullPage: true });
    
    // Verify we can access the page with the correct domain
    expect(page.url()).toContain('minikube.test');
  });

    test('Should be able to login to the application', async ({ page }) => {
      // Navigate to the VRE app
      const response = await page.goto('/vreapp');
      expect(response?.status()).toBeLessThan(400);
      await page.waitForLoadState('networkidle');

      // Try to find the visible "Login" link (desktop)
      const loginLink = page.getByRole('link', { name: 'Login' });
      if (!await loginLink.isVisible()) {
        // If not visible, open the mobile menu (button with aria-haspopup or headlessui id)
        const menuButton = page.locator('button[aria-haspopup="menu"], button[id^="headlessui-menu-button"]');
        if (await menuButton.isVisible()) {
          await menuButton.click();
          // small wait for menu animation / DOM update
          await page.waitForTimeout(200);
        }
      }

      // Click the login entry (should now be visible)
      await loginLink.click();

      // Wait for either navigation or the appearance of a login form field
      await Promise.race([
        page.waitForNavigation({ waitUntil: 'networkidle', timeout: 3000 }).catch(() => {}),
        page.waitForSelector('input[type="user"], input[name="user"]', { timeout: 3000 }).catch(() => {})
      ]);
      // Assert that we've reached a login surface: URL contains "login" OR a login input is visible
      const urlContainsLogin = page.url().toLowerCase().includes('login');
      const hasLoginForm = await page.locator('input[type="user"], input[name="user"]').count() > 0;
      expect(urlContainsLogin || hasLoginForm).toBeTruthy();

      // Optional screenshot for debugging
      await page.screenshot({ path: 'test-results/screenshots/login-attempt.png', fullPage: true });
    });


});
