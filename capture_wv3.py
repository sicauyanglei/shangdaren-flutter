import asyncio
from playwright.async_api import async_playwright

async def capture():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        
        page.on('console', lambda msg: print(f'[Console {msg.type}] {msg.text}'))
        page.on('pageerror', lambda err: print(f'[Page Error] {err}'))
        
        await page.goto('file:///E:/AI-PRJ/shangdaren-game/flutter_app/assets/html/index.html')
        await page.wait_for_timeout(2000)
        
        # Check gameState object
        gs = await page.evaluate('() => { if (typeof gameState === "undefined") return "no gameState"; return JSON.stringify({gameStarted: gameState.gameStarted, phase: gameState.phase}); }')
        print(f'GameState: {gs}')
        
        # Click start game
        await page.click('button.start-game-btn')
        await page.wait_for_timeout(3000)
        
        gs2 = await page.evaluate('() => { if (typeof gameState === "undefined") return "no gameState"; return JSON.stringify({gameStarted: gameState.gameStarted, phase: gameState.phase, roundNumber: gameState.roundNumber}); }')
        print(f'GameState after click: {gs2}')
        
        # Check game container visibility
        gc = await page.evaluate('() => { const gc = document.querySelector(".game-container"); if (!gc) return "no container"; return JSON.stringify({display: gc.style.display, visible: gc.offsetParent !== null}); }')
        print(f'Game container: {gc}')
        
        # Wait for dealing to complete
        await page.wait_for_timeout(25000)
        
        gs3 = await page.evaluate('() => { if (typeof gameState === "undefined") return "no gameState"; return JSON.stringify({gameStarted: gameState.gameStarted, phase: gameState.phase, roundNumber: gameState.roundNumber, dealingComplete: gameState.dealingComplete}); }')
        print(f'GameState after dealing: {gs3}')
        
        await page.screenshot(path='E:/AI-PRJ/shangdaren-game/wv_game_final.png', full_page=False)
        print('Final screenshot saved')
        await browser.close()

asyncio.run(capture())
