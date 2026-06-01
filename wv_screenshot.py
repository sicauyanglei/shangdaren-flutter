import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={"width": 1280, "height": 720})
        await page.goto('file:///E:/AI-PRJ/shangdaren-game/flutter_app/assets/html/index.html')
        await page.wait_for_timeout(2000)
        await page.screenshot(path='E:/AI-PRJ/shangdaren-game/wv_start.png')
        print("WV start screenshot saved")

        start_btn = page.locator('button:has-text("开始游戏")')
        if await start_btn.count() > 0:
            await start_btn.click()
            await page.wait_for_timeout(5000)
            await page.screenshot(path='E:/AI-PRJ/shangdaren-game/wv_game.png')
            print("WV game screenshot saved")
        else:
            print("Start button not found")

        await browser.close()

asyncio.run(main())
