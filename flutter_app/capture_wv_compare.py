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
        if start_btn:
            await start_btn.click()
            await page.wait_for_timeout(1500)

        # Handle piao selection - click piao 0 buttons
        piao_btns = await page.query_selector_all('.piao-popup button')
        if piao_btns:
            for btn in piao_btns:
                text = await btn.inner_text()
                if text.strip() == '0':
                    await btn.click(force=True)
                    break
            await page.wait_for_timeout(500)

        # Wait for dealing and some gameplay
        await page.wait_for_timeout(15000)
        await page.screenshot(path='wv_game_state.png')
        print('WebView game state screenshot saved')

        # Get game state
        state = await page.evaluate('''() => {
            try {
                if (typeof gameState === 'undefined') return {error: 'gameState undefined'};
                return JSON.stringify({
                    status: gameState.status,
                    currentPlayerIndex: gameState.currentPlayerIndex,
                    isMyTurn: gameState.isMyTurn,
                    isDrawing: gameState.isDrawing,
                    deckCount: gameState.deck ? gameState.deck.length : 0,
                    roundNumber: gameState.roundNumber,
                    dealerIndex: gameState.dealerIndex,
                    canChi: gameState.canChi,
                    canPeng: gameState.canPeng,
                    canZhao: gameState.canZhao,
                    canHu: gameState.canHu,
                    players: gameState.players ? gameState.players.map((p,i) => ({
                        name: p.name,
                        handCount: p.hand ? p.hand.length : 0,
                        discardCount: p.discards ? p.discards.length : 0,
                        meldCount: p.melds ? p.melds.length : 0,
                        isTing: p.isTing,
                        score: p.score,
                        piao: p.piao,
                    })) : [],
                });
            } catch(e) {
                return JSON.stringify({error: e.message});
            }
        }''')
        print(f'WebView state: {state}')

        await browser.close()

asyncio.run(main())
