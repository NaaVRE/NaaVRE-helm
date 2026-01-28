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
});
