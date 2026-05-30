import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page(viewport={'width': 1280, 'height': 720})
        await page.goto('http://localhost:8888')
        await page.wait_for_timeout(2000)
        await page.screenshot(path='wv_start_clean.png')

        # Get start screen element positions
        info = await page.evaluate('''() => {
            const startScreen = document.getElementById('startScreen');
            if (!startScreen) return {error: 'no startScreen'};
            const rect = startScreen.getBoundingClientRect();
            
            // Get all child elements
            const children = startScreen.querySelectorAll('*');
            const elements = [];
            for (const child of children) {
                if (child.offsetParent !== null || child.id) {
                    const r = child.getBoundingClientRect();
                    if (r.width > 0 && r.height > 0) {
                        elements.push({
                            tag: child.tagName,
                            id: child.id || '',
                            class: child.className || '',
                            text: child.innerText ? child.innerText.trim().substring(0, 50) : '',
                            rect: {x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height)},
                        });
                    }
                }
            }
            
            // Get start screen styles
            const style = getComputedStyle(startScreen);
            
            return {
                startScreenRect: {x: Math.round(rect.x), y: Math.round(rect.y), w: Math.round(rect.width), h: Math.round(rect.height)},
                startScreenStyle: {
                    background: style.background.substring(0, 100),
                    display: style.display,
                },
                elements: elements,
            };
        }''')
        print(f'Start screen info:')
        print(f'  Rect: {info.get("startScreenRect")}')
        print(f'  Style: {info.get("startScreenStyle")}')
        print(f'  Children ({len(info.get("elements", []))}):')
        for el in info.get('elements', []):
            if el['text'] or el['id']:
                print(f'    {el["tag"]} id={el["id"]} class={el["class"][:30]} text="{el["text"]}" rect={el["rect"]}')

        await browser.close()

asyncio.run(main())
