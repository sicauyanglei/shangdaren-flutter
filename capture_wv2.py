import asyncio
from playwright.async_api import async_playwright

async def capture():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        
        # Collect console messages
        page.on('console', lambda msg: print(f'Console: {msg.type}: {msg.text}'))
        page.on('pageerror', lambda err: print(f'Page error: {err}'))
        
        await page.goto('file:///E:/AI-PRJ/shangdaren-game/flutter_app/assets/html/index.html')
        await page.wait_for_timeout(2000)
        
        # Check if game object exists
        game_exists = await page.evaluate('() => typeof game !== "undefined"')
        print(f'Game object exists: {game_exists}')
        
        # Check if startGame function exists
        startgame_exists = await page.evaluate('() => typeof startGame !== "undefined"')
        print(f'startGame function exists: {startgame_exists}')
        
        # Check what scripts are loaded
        scripts = await page.evaluate('() => Array.from(document.scripts).map(s => s.src || s.textContent.substring(0, 100))')
        print(f'Scripts: {scripts}')
        
        # Try clicking start
        await page.click('button.start-game-btn')
        await page.wait_for_timeout(3000)
        
        game_exists2 = await page.evaluate('() => typeof game !== "undefined"')
        print(f'Game object exists after click: {game_exists2}')
        
        await page.screenshot(path='E:/AI-PRJ/shangdaren-game/wv_debug.png', full_page=False)
        await browser.close()

asyncio.run(capture())
