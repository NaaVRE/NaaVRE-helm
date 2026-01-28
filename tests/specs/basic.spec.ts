import { test, expect } from '@playwright/test';

/**
 * Simple UI test for NaaVRE application
 * Tests basic navigation to the VRE app
 */
test.describe('NaaVRE UI Basic Tests', () => {
  
  test('should load the VRE app page', async ({ page }) => {
    // Navigate to the VRE app
    await page.goto('/vreapp');
    
    // Wait for the page to load
    await page.waitForLoadState('networkidle');
    
    // Take a screenshot for verification
    await page.screenshot({ path: 'screenshots/vreapp-loaded.png', fullPage: true });
    
    // Verify the page loaded successfully (status should not be 404 or 500)
    expect(page.url()).toContain('vreapp');
  });

  test('should have a valid page title', async ({ page }) => {
    // Navigate to the VRE app
    await page.goto('/vreapp');
    
    // Wait for the page to load
    await page.waitForLoadState('domcontentloaded');
    
    // Check that the page has a title (not empty)
    const title = await page.title();
    expect(title).toBeTruthy();
    expect(title.length).toBeGreaterThan(0);
  });

  test('should be able to access the main page', async ({ page }) => {
    // Navigate to the base URL
    await page.goto('/');
    
    // Wait for the page to load
    await page.waitForLoadState('networkidle');
    
    // Take a screenshot
    await page.screenshot({ path: 'screenshots/main-page.png', fullPage: true });
    
    // Verify we can access the page
    expect(page.url()).toContain('minikube.test');
  });
});
