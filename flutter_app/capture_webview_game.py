import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        await page.goto('http://localhost:8888')
        await page.wait_for_timeout(2000)

        # Take screenshot of start screen
        await page.screenshot(path='screen_wv_start.png')
        print('Start screen saved')

        # Click start button - try to find it
        buttons = await page.query_selector_all('button')
        print(f'Found {len(buttons)} buttons')
        for i, btn in enumerate(buttons):
            text = await btn.inner_text()
            print(f'  Button {i}: "{text}"')

        # Look for start game button
        start_btn = await page.query_selector('text=开始游戏')
        if not start_btn:
            start_btn = await page.query_selector('text=开始')
        if not start_btn:
            start_btn = await page.query_selector('.start-btn')
        if not start_btn:
            start_btn = await page.query_selector('#startBtn')
        if not start_btn:
            # Try clicking any visible button
            all_btns = await page.query_selector_all('button, .btn, [role="button"]')
            for btn in all_btns:
                text = await btn.inner_text()
                visible = await btn.is_visible()
                print(f'  Visible button: "{text}" visible={visible}')
                if visible and ('开始' in text or 'start' in text.lower()):
                    start_btn = btn
                    break

        if start_btn:
            await start_btn.click()
            print('Clicked start button')
            await page.wait_for_timeout(5000)
            await page.screenshot(path='screen_wv_game.png')
            print('Game screen saved')
        else:
            print('No start button found, taking screenshot anyway')
            await page.screenshot(path='screen_wv_game.png')

        # Also check the page content
        title = await page.title()
        print(f'Page title: {title}')
        url = page.url
        print(f'Page URL: {url}')

        await browser.close()

asyncio.run(main())
