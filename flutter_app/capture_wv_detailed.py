import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        await page.goto('http://localhost:8888')
        await page.wait_for_timeout(2000)

        # Step 0: Start screen
        await page.screenshot(path='wv_00_start.png')
        print('Step 0: Start screen')

        # Click start game
        start_btn = await page.query_selector('text=开始游戏')
        if start_btn:
            await start_btn.click()
            await page.wait_for_timeout(1000)
            await page.screenshot(path='wv_01_after_click_start.png')
            print('Step 1: After click start')

        # Check if piao selection is visible
        piao_popup = await page.query_selector('.piao-popup, .piao-selection, [class*="piao"]')
        if piao_popup:
            print('Piao popup found, selecting piao=0')
            # Try clicking piao 0 button
            piao_0 = await page.query_selector('text=0')
            if piao_0:
                await piao_0.click()
                await page.wait_for_timeout(500)

        # Wait for dealing
        await page.wait_for_timeout(5000)
        await page.screenshot(path='wv_02_after_piao.png')
        print('Step 2: After piao selection')

        # Wait more for game to progress
        await page.wait_for_timeout(10000)
        await page.screenshot(path='wv_03_game_playing.png')
        print('Step 3: Game playing')

        # Try to get game state
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
        print(f'Game state: {state}')

        # Check what's visible on the page
        visible_elements = await page.evaluate('''() => {
            const result = {};
            const selectors = [
                '.start-screen', '.game-container', '.piao-popup',
                '.player-left', '.player-right', '.bottom-area',
                '.my-hand', '.action-buttons', '.zimo-badge',
                '.round-info', '.current-time', '.center-area',
                '.deck-stack', '.settings-btn',
            ];
            for (const sel of selectors) {
                const el = document.querySelector(sel);
                result[sel] = el ? {visible: el.offsetParent !== null, display: getComputedStyle(el).display, rect: el.getBoundingClientRect()} : null;
            }
            return result;
        }''')
        print(f'\nVisible elements:')
        for sel, info in visible_elements.items():
            if info:
                print(f'  {sel}: visible={info["visible"]}, display={info["display"]}, rect={info.get("rect", "N/A")}')

        await browser.close()

asyncio.run(main())
