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
        print('Step 0: Start screen saved')

        # Click start game
        start_btn = await page.query_selector('text=开始游戏')
        if start_btn:
            await start_btn.click()
            await page.wait_for_timeout(1500)
            await page.screenshot(path='wv_01_after_start.png')
            print('Step 1: After start saved')

        # Handle piao selection
        piao_btns = await page.query_selector_all('.piao-popup button')
        if piao_btns:
            for btn in piao_btns:
                text = await btn.inner_text()
                if text.strip() == '0':
                    await btn.click(force=True)
                    break
            await page.wait_for_timeout(500)

        # Wait for dealing and game to start
        await page.wait_for_timeout(15000)
        await page.screenshot(path='wv_02_game_playing.png')
        print('Step 2: Game playing saved')

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
        print(f'Game state: {state}')

        # Get all visible UI elements and their positions
        ui_info = await page.evaluate('''() => {
            const result = {};
            const selectors = [
                '.start-screen', '.game-container', '.piao-popup',
                '.player-left', '.player-right', '.bottom-area',
                '.my-hand', '.action-buttons', '.zimo-badge',
                '.round-info', '.current-time', '.center-area',
                '.deck-stack', '.settings-btn', '.ting-badge',
                '.my-discard-side', '.my-melds-side',
                '.player-melds-side', '.player-discard',
            ];
            for (const sel of selectors) {
                const el = document.querySelector(sel);
                if (el) {
                    const rect = el.getBoundingClientRect();
                    const style = getComputedStyle(el);
                    result[sel] = {
                        visible: rect.width > 0 && rect.height > 0,
                        display: style.display,
                        rect: {x: Math.round(rect.x), y: Math.round(rect.y), w: Math.round(rect.width), h: Math.round(rect.height)},
                    };
                } else {
                    result[sel] = null;
                }
            }
            return result;
        }''')
        print(f'\nUI elements:')
        for sel, info in ui_info.items():
            if info and info.get('visible'):
                print(f'  {sel}: rect={info["rect"]}')

        await browser.close()

asyncio.run(main())
