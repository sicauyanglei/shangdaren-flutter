from PIL import Image
import numpy as np

wv = Image.open(r'E:\AI-PRJ\shangdaren-game\wv_game.png')
fl = Image.open(r'E:\AI-PRJ\shangdaren-game\fl_game6.png')

wv_arr = np.array(wv)[:,:,:3]
fl_arr = np.array(fl)[:,:,:3]

print("=== Small Card Detail Comparison ===")
print()

wv_left_cards = wv_arr[80:160, 10:260]
fl_left_cards = fl_arr[80:160, 10:260]

wv_non_green = np.sum(wv_left_cards > 30, axis=2) > 0
fl_non_green = np.sum(fl_left_cards > 30, axis=2) > 0

wv_card_pixels = np.sum(wv_non_green)
fl_card_pixels = np.sum(fl_non_green)
print(f"Left area non-green pixels - WV: {wv_card_pixels}, FL: {fl_card_pixels}")

wv_right_cards = wv_arr[80:160, 1020:1270]
fl_right_cards = fl_arr[80:160, 1020:1270]

wv_non_green_r = np.sum(wv_right_cards > 30, axis=2) > 0
fl_non_green_r = np.sum(fl_right_cards > 30, axis=2) > 0

wv_card_pixels_r = np.sum(wv_non_green_r)
fl_card_pixels_r = np.sum(fl_non_green_r)
print(f"Right area non-green pixels - WV: {wv_card_pixels_r}, FL: {fl_card_pixels_r}")

print()
print("=== Hand Card Region ===")
wv_hand = wv_arr[500:700, 400:880]
fl_hand = fl_arr[500:700, 400:880]

wv_hand_var = np.var(wv_hand.astype(float))
fl_hand_var = np.var(fl_hand.astype(float))
print(f"Hand card region variance - WV: {wv_hand_var:.1f}, FL: {fl_hand_var:.1f}")

wv_hand_detail = np.sum(np.abs(np.diff(wv_hand.astype(float), axis=0))) + np.sum(np.abs(np.diff(wv_hand.astype(float), axis=1)))
fl_hand_detail = np.sum(np.abs(np.diff(fl_hand.astype(float), axis=0))) + np.sum(np.abs(np.diff(fl_hand.astype(float), axis=1)))
print(f"Hand card edge detail - WV: {wv_hand_detail:.0f}, FL: {fl_hand_detail:.0f}")

print()
print("=== Deck Area ===")
wv_deck = wv_arr[20:80, 170:400]
fl_deck = fl_arr[20:80, 170:400]
wv_deck_var = np.var(wv_deck.astype(float))
fl_deck_var = np.var(fl_deck.astype(float))
print(f"Deck area variance - WV: {wv_deck_var:.1f}, FL: {fl_deck_var:.1f}")

print()
print("=== Overlay Player Info ===")
for name, wv_region, fl_region in [
    ("Left player", wv_arr[5:75, 10:160], fl_arr[5:75, 10:160]),
    ("Right player", wv_arr[5:75, 1120:1270], fl_arr[5:75, 1120:1270]),
    ("My player", wv_arr[660:715, 5:200], fl_arr[660:715, 5:200]),
]:
    wv_var = np.var(wv_region.astype(float))
    fl_var = np.var(fl_region.astype(float))
    wv_non_green = np.sum(np.any(wv_region > 30, axis=2))
    fl_non_green = np.sum(np.any(fl_region > 30, axis=2))
    print(f"{name}: WV var={wv_var:.1f} non-green={wv_non_green}, FL var={fl_var:.1f} non-green={fl_non_green}")

wv_left_crop = wv.crop((10, 80, 260, 160))
fl_left_crop = fl.crop((10, 80, 260, 160))
wv_left_crop.save(r'E:\AI-PRJ\shangdaren-game\wv_left_cards.png')
fl_left_crop.save(r'E:\AI-PRJ\shangdaren-game\fl_left_cards.png')
print("\nCropped left card regions saved for visual comparison")
