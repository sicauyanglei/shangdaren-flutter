import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        await page.goto('http://localhost:8888')
        await page.wait_for_timeout(2000)

        # Screenshot initial state
        await page.screenshot(path='wv_step0_initial.png')
        print('Step 0: Initial state saved')

        # Click start game
        start_btn = await page.query_selector('text=开始游戏')
        if start_btn:
            await start_btn.click()
            print('Clicked start game')
            await page.wait_for_timeout(3000)
            await page.screenshot(path='wv_step1_after_start.png')
            print('Step 1: After start game saved')

            # Wait for dealing animation
            await page.wait_for_timeout(5000)
            await page.screenshot(path='wv_step2_dealing.png')
            print('Step 2: After dealing saved')

            # Wait more for game to progress
            await page.wait_for_timeout(8000)
            await page.screenshot(path='wv_step3_playing.png')
            print('Step 3: Playing state saved')

            # Get game state from JS
            state = await page.evaluate('''() => {
                const gs = window.gameState || {};
                return {
                    phase: gs.phase,
                    currentPlayer: gs.currentPlayer,
                    deckCount: gs.deck ? gs.deck.length : 0,
                    players: gs.players ? gs.players.map(p => ({
                        name: p.name,
                        handCount: p.hand ? p.hand.length : 0,
                        discardCount: p.discards ? p.discards.length : 0,
                        meldCount: p.melds ? p.melds.length : 0,
                        isTing: p.isTing,
                        score: p.score,
                        piao: p.piao
                    })) : [],
                    roundNumber: gs.roundNumber || 0,
                    dealerIndex: gs.dealerIndex,
                    canChi: gs.canChi,
                    canPeng: gs.canPeng,
                    canZhao: gs.canZhao,
                    canHu: gs.canHu,
                    isMyTurn: gs.isMyTurn,
                };
            }''')
            print(f'Game state: {state}')
        else:
            print('No start button found')

        await browser.close()

asyncio.run(main())
