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
        
        # Wait for dealing to complete
        await page.wait_for_timeout(25000)
        
        # Take screenshot after dealing
        await page.screenshot(path='E:/AI-PRJ/shangdaren-game/wv_after_deal.png', full_page=False)
        print('After dealing screenshot saved')
        
        # Check game state
        state = await page.evaluate('''() => {
            if (typeof gameState === "undefined") return "no gameState";
            const me = gameState.players ? gameState.players[1] : null;
            return JSON.stringify({
                gameStarted: gameState.gameStarted,
                phase: gameState.phase,
                roundNumber: gameState.roundNumber,
                currentPlayerIndex: gameState.currentPlayerIndex,
                myHandSize: me ? me.hand.length : 0,
                isMyTurn: gameState.currentPlayerIndex === 1,
                canChi: gameState.canChi,
                canPeng: gameState.canPeng,
                canZhao: gameState.canZhao,
                canHu: gameState.canHu,
            });
        }''')
        print(f'Game state: {state}')
        
        # Try to click a hand card
        hand_cards = await page.query_selector_all('.my-hand .card-stack')
        print(f'Hand card elements: {len(hand_cards)}')
        
        if len(hand_cards) > 0:
            # Click the first card
            await hand_cards[0].click()
            await page.wait_for_timeout(1000)
            
            # Check if card is selected
            state2 = await page.evaluate('''() => {
                if (typeof gameState === "undefined") return "no gameState";
                return JSON.stringify({
                    selectedCard: gameState.selectedCard,
                    currentPlayerIndex: gameState.currentPlayerIndex,
                });
            }''')
            print(f'After click: {state2}')
            
            await page.screenshot(path='E:/AI-PRJ/shangdaren-game/wv_card_selected.png', full_page=False)
            print('Card selected screenshot saved')
        
        await browser.close()

asyncio.run(capture())
