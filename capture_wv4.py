import asyncio
from playwright.async_api import async_playwright

async def capture():
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        
        page.on('pageerror', lambda err: print(f'[Page Error] {err}'))
        
        await page.goto('file:///E:/AI-PRJ/shangdaren-game/flutter_app/assets/html/index.html')
        await page.wait_for_timeout(2000)
        
        # Click start game
        await page.click('button.start-game-btn')
        print('Clicked start game')
        
        # Wait for dealing animation to complete
        await page.wait_for_timeout(25000)
        
        # Check game state
        state = await page.evaluate('''() => {
            if (typeof gameState === "undefined") return "no gameState";
            return JSON.stringify({
                gameStarted: gameState.gameStarted,
                phase: gameState.phase,
                roundNumber: gameState.roundNumber
            });
        }''')
        print(f'Game state: {state}')
        
        # Check if cards are visible
        cards = await page.evaluate('''() => {
            const handCards = document.querySelectorAll('.hand-card');
            const playedCards = document.querySelectorAll('.played-card');
            return JSON.stringify({
                handCards: handCards.length,
                playedCards: playedCards.length
            });
        }''')
        print(f'Cards: {cards}')
        
        await page.screenshot(path='E:/AI-PRJ/shangdaren-game/wv_game_board3.png', full_page=False)
        print('Screenshot saved')
        await browser.close()

asyncio.run(capture())
