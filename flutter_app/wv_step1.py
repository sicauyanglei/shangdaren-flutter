import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        await page.goto('http://localhost:8888')
        await page.wait_for_timeout(2000)

        # Screenshot start screen
        await page.screenshot(path='wv_step0_start.png')
        print('Step 0: Start screen')

        # Click start game button
        start_btn = await page.query_selector('text=开始游戏')
        if start_btn:
            await start_btn.click()
            await page.wait_for_timeout(1500)
            await page.screenshot(path='wv_step1_piao.png')
            print('Step 1: Piao selection screen')

            # Check what's shown now
            visible = await page.evaluate('''() => {
                const result = {};
                const selectors = ['.start-screen', '.piao-popup', '.game-container', '.piao-btn'];
                for (const sel of selectors) {
                    const el = document.querySelector(sel);
                    if (el) {
                        const rect = el.getBoundingClientRect();
                        result[sel] = {visible: rect.width > 0, rect: {x: Math.round(rect.x), y: Math.round(rect.y), w: Math.round(rect.width), h: Math.round(rect.height)}};
                    }
                }
                // Get all buttons
                const buttons = document.querySelectorAll('button, .btn, .piao-btn');
                result['all_buttons'] = Array.from(buttons).map(b => ({
                    text: b.innerText.trim().substring(0, 30),
                    visible: b.offsetParent !== null,
                    rect: {x: Math.round(b.getBoundingClientRect().x), y: Math.round(b.getBoundingClientRect().y), w: Math.round(b.getBoundingClientRect().width), h: Math.round(b.getBoundingClientRect().height)},
                })).filter(b => b.visible);
                return result;
            }''')
            print(f'Visible elements: {visible}')
        else:
            print('No start button found')

        await browser.close()

asyncio.run(main())
