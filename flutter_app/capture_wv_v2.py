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
            print('Clicked start game')
            await page.wait_for_timeout(1500)

        # Screenshot after start
        await page.screenshot(path='wv_after_start.png')
        print('After start screenshot saved')

        # Get page HTML to understand what's shown
        html_snippet = await page.evaluate('''() => {
            const body = document.body.innerHTML;
            return body.substring(0, 3000);
        }''')
        print(f'HTML snippet: {html_snippet[:2000]}')

        # Find all visible buttons
        buttons_info = await page.evaluate('''() => {
            const buttons = document.querySelectorAll('button, .btn, [role="button"]');
            return Array.from(buttons).map(b => ({
                text: b.innerText.trim().substring(0, 30),
                visible: b.offsetParent !== null,
                className: b.className.substring(0, 50),
                rect: b.getBoundingClientRect(),
            })).filter(b => b.visible);
        }''')
        print(f'\nVisible buttons: {buttons_info}')

        # Check for piao popup specifically
        piao_info = await page.evaluate('''() => {
            const piaoEl = document.querySelector('.piao-popup');
            if (!piaoEl) return 'No .piao-popup found';
            return {
                display: getComputedStyle(piaoEl).display,
                visibility: getComputedStyle(piaoEl).visibility,
                rect: piaoEl.getBoundingClientRect().toJSON(),
                innerHTML: piaoEl.innerHTML.substring(0, 500),
            };
        }''')
        print(f'\nPiao popup info: {piao_info}')

        # Try clicking piao buttons with force
        piao_buttons = await page.query_selector_all('.piao-popup button, .piao-popup .btn')
        print(f'\nPiao buttons found: {len(piao_buttons)}')
        for i, btn in enumerate(piao_buttons):
            text = await btn.inner_text()
            print(f'  Piao button {i}: "{text}"')

        # Click the first piao button (0) with force
        if piao_buttons:
            await piao_buttons[0].click(force=True)
            print('Clicked first piao button with force')
            await page.wait_for_timeout(500)

        # Wait for AI piao selections
        await page.wait_for_timeout(3000)
        await page.screenshot(path='wv_after_piao.png')
        print('After piao screenshot saved')

        # Wait for dealing
        await page.wait_for_timeout(8000)
        await page.screenshot(path='wv_game_playing.png')
        print('Game playing screenshot saved')

        # Get game state
        state = await page.evaluate('''() => {
            try {
                if (typeof gameState === 'undefined') return {error: 'gameState undefined'};
                return {
                    status: gameState.status,
                    currentPlayerIndex: gameState.currentPlayerIndex,
                    isMyTurn: gameState.isMyTurn,
                    isDrawing: gameState.isDrawing,
                    deckCount: gameState.deck ? gameState.deck.length : 'N/A',
                    roundNumber: gameState.roundNumber,
                    dealerIndex: gameState.dealerIndex,
                    canChi: gameState.canChi,
                    canPeng: gameState.canPeng,
                    canZhao: gameState.canZhao,
                    canHu: gameState.canHu,
                    players: gameState.players ? gameState.players.map((p,i) => ({
                        index: i,
                        name: p.name,
                        handCount: p.hand ? p.hand.length : 0,
                        discardCount: p.discards ? p.discards.length : 0,
                        meldCount: p.melds ? p.melds.length : 0,
                        isTing: p.isTing,
                        score: p.score,
                        piao: p.piao,
                        type: p.type,
                    })) : [],
                };
            } catch(e) {
                return {error: e.message};
            }
        }''')
        print(f'\nGame state: {state}')

        await browser.close()

asyncio.run(main())
