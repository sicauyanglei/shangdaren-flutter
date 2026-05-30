import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        await page.goto('http://localhost:8888')
        await page.wait_for_timeout(2000)

        # Click start game
        start_btn = await page.query_selector('text=开始游戏')
        if not start_btn:
            print('No start button found')
            await browser.close()
            return

        await start_btn.click()
        print('Clicked start game')

        # Take screenshots at different times
        for i in range(10):
            await page.wait_for_timeout(500)
            await page.screenshot(path=f'wv_timeline_{i}.png')

            # Check state
            state = await page.evaluate('''() => {
                const piaoPopup = document.querySelector('.piao-popup');
                const startScreen = document.querySelector('.start-screen');
                const gameContainer = document.querySelector('.game-container');
                const piaoBtns = document.querySelectorAll('.piao-btn');
                return {
                    startScreenVisible: startScreen ? startScreen.offsetParent !== null : false,
                    gameContainerVisible: gameContainer ? gameContainer.offsetParent !== null : false,
                    piaoPopupVisible: piaoPopup ? piaoPopup.offsetParent !== null : false,
                    piaoPopupDisplay: piaoPopup ? getComputedStyle(piaoPopup).display : 'N/A',
                    piaoBtnCount: piaoBtns.length,
                    gameState: typeof gameState !== 'undefined' ? {
                        status: gameState.status,
                        phase: gameState.phase,
                    } : 'undefined',
                };
            }''')
            print(f'  t={i*500}ms: {state}')

            if state.get('piaoPopupVisible'):
                print('  PIAO POPUP VISIBLE!')
                break

        await browser.close()

asyncio.run(main())
