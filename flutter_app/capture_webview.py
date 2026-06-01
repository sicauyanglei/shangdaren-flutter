import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        await page.goto('http://localhost:8888')
        await page.wait_for_timeout(3000)
        await page.screenshot(path='screen_webview.png', full_page=False)
        print('WebView screenshot saved to screen_webview.png')
        await browser.close()

asyncio.run(main())
