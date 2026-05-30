import asyncio
from playwright.async_api import async_playwright

async def capture():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        await page.goto('file:///E:/AI-PRJ/shangdaren-game/flutter_app/assets/html/index.html')
        await page.wait_for_timeout(1000)
        
        before = await page.evaluate('() => document.getElementById("startScreen").classList.contains("hidden")')
        print(f'Start screen hidden before: {before}')
        
        await page.click('button.start-game-btn')
        await page.wait_for_timeout(3000)
        
        after = await page.evaluate('() => document.getElementById("startScreen").classList.contains("hidden")')
        print(f'Start screen hidden after: {after}')
        
        state = await page.evaluate('() => { if (typeof game === "undefined") return "no game"; return JSON.stringify({phase: game.phase, piaoEnabled: game.piaoEnabled}); }')
        print(f'Game state: {state}')
        
        await page.wait_for_timeout(20000)
        
        state2 = await page.evaluate('() => { if (typeof game === "undefined") return "no game"; return JSON.stringify({phase: game.phase}); }')
        print(f'Game state after wait: {state2}')
        
        await page.screenshot(path='E:/AI-PRJ/shangdaren-game/wv_game_board2.png', full_page=False)
        print('Screenshot saved')
        await browser.close()

asyncio.run(capture())
