#!/usr/bin/env python3
"""科大讯飞 TTS 下载脚本 - 生成上大人字牌游戏音频文件"""
import websocket
import datetime
import hashlib
import hmac
import base64
import json
import os
import ssl

# 科大讯飞 TTS 配置
APPID = "19a05817"
APISecret = "NDE1YjYzMTE0OWM2MDc0NjRjZGE2ZWMz"
APIKey = "120b7f0f53c461a9118a59c0b4d34b91"

# 发音人配置
VOICES = {
    "male": "xiaofeng",
    "female": "xiaoyan"
}

# 需要生成的文字列表
CARD_CHARS = ["上", "大", "人", "丘", "乙", "己", "化", "三", "千", "七", "十", "土",
              "尔", "小", "生", "八", "九", "子", "佳", "作", "亡", "福", "禄", "寿"]

ACTION_WORDS = ["吃", "碰", "招", "过", "胡", "自摸", "出牌", "招"]

GAME_WORDS = ["流局", "十对", "黑元", "红元", "枯胡", "清枯胡", "清枯重台",
              "重台胡", "重台卡", "枯重台胡", "枯重台卡",
              "快点吧"]

# 文字到文件名映射
WORD_TO_FILENAME = {
    "上": "shang", "大": "da", "人": "ren", "丘": "qiu", "乙": "yi", "己": "ji",
    "化": "hua", "三": "san", "千": "qian", "七": "qi", "十": "shi", "土": "tu",
    "尔": "er", "小": "xiao", "生": "sheng", "八": "ba", "九": "jiu", "子": "zi",
    "佳": "jia", "作": "zuo", "亡": "wang", "福": "fu", "禄": "lu", "寿": "shou",
    "吃": "chi", "碰": "peng", "招": "zhao", "过": "guo", "胡": "hu", "自摸": "zimo",
    "出牌": "chupai", "流局": "liuju", "十对": "shidui", "黑元": "heiyuan",
    "红元": "hongyuan", "枯胡": "kuhu", "清枯胡": "qingkuhu", "清枯重台": "qingkuchongtaika",
    "重台胡": "chongtaihu", "重台卡": "chongtaika", "枯重台胡": "kuzhongtaihu",
    "枯重台卡": "kuzhongtaika", "枯胡": "kuhu", "枯重台胡": "kuzhongtaihu",
    "快点吧": "kuaidianba", "普通胡": "putonghu", "卡胡": "kahu",
    "大胡": "taihu", "台卡": "taika", "清胡": "qinghu", "清卡胡": "qingkahu",
    "清枯胡": "qingkuhu", "清枯台胡": "qingkutaihu", "清枯台卡": "qingkutaika",
    "清枯重台胡": "qingkuchongtaihu", "清枯重台卡": "qingkuchongtaika",
    "红元3精": "hongyuan3jing", "红元4精": "hongyuan4jing",
    "红元5精": "hongyuan5jing", "红元6精": "hongyuan6jing",
    "招": "zhao", "左": "zuo",
}


def create_url():
    """生成鉴权URL"""
    url = "wss://tts-api.xfyun.cn/v2/tts"
    now = datetime.datetime.utcnow()
    from wsgiref.handlers import format_date_time
    from time import mktime
    date = format_date_time(mktime(now.timetuple()))
    signature_origin = f"host: ws-api.xfyun.cn\ndate: {date}\nGET /v2/tts HTTP/1.1"
    signature_sha = hmac.new(
        APISecret.encode('utf-8'),
        signature_origin.encode('utf-8'),
        digestmod=hashlib.sha256
    ).digest()
    signature = base64.b64encode(signature_sha).decode(encoding='utf-8')
    authorization_origin = (
        f'api_key="{APIKey}", algorithm="hmac-sha256", '
        f'headers="host date request-line", signature="{signature}"'
    )
    authorization = base64.b64encode(authorization_origin.encode('utf-8')).decode(encoding='utf-8')
    params = {"authorization": authorization, "date": date, "host": "ws-api.xfyun.cn"}
    from urllib.parse import urlencode
    return url + "?" + urlencode(params)


def tts_download(text, voice, output_path):
    """下载单个TTS音频"""
    url = create_url()
    body = {
        "common": {"app_id": APPID},
        "business": {
            "aue": "lame",
            "sfl": 1,
            "auf": "audio/L16;rate=16000",
            "vcn": voice,
            "speed": 50,
            "volume": 50,
            "pitch": 50,
            "tte": "UTF8",
        },
        "data": {
            "status": 2,
            "text": base64.b64encode(text.encode('utf-8')).decode('utf-8'),
        },
    }

    audio_data = bytearray()

    def on_message(ws, message):
        nonlocal audio_data
        result = json.loads(message)
        code = result.get("code")
        if code != 0:
            print(f"  Error: code={code}, message={result.get('message', '')}")
            ws.close()
            return
        audio = result.get("data", {}).get("audio")
        if audio:
            audio_data.extend(base64.b64decode(audio))
        status = result.get("data", {}).get("status")
        if status == 2:
            ws.close()

    def on_error(ws, error):
        print(f"  WebSocket error: {error}")

    def on_open(ws):
        ws.send(json.dumps(body))

    ws = websocket.WebSocketApp(
        url, on_open=on_open, on_message=on_message, on_error=on_error
    )
    ws.run_forever(sslopt={"cert_reqs": ssl.CERT_NONE})

    if audio_data:
        with open(output_path, "wb") as f:
            f.write(audio_data)
        print(f"  Saved: {output_path} ({len(audio_data)} bytes)")
        return True
    else:
        print(f"  Failed: {output_path}")
        return False


def main():
    import argparse
    parser = argparse.ArgumentParser(description="科大讯飞TTS音频生成")
    parser.add_argument("--gender", choices=["male", "female", "both"], default="both",
                        help="生成哪种性别的音频")
    parser.add_argument("--output-dir", default=None,
                        help="输出目录，默认为脚本所在目录的assets/audio")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    if args.output_dir:
        base_dir = args.output_dir
    else:
        base_dir = os.path.join(script_dir, "assets", "audio")

    # 所有需要生成的文字
    all_words = CARD_CHARS + ACTION_WORDS + GAME_WORDS
    # 去重
    all_words = list(dict.fromkeys(all_words))

    genders = ["male", "female"] if args.gender == "both" else [args.gender]

    for gender in genders:
        voice = VOICES[gender]
        output_dir = os.path.join(base_dir, gender)
        os.makedirs(output_dir, exist_ok=True)
        print(f"\n=== Generating {gender} voice ({voice}) ===")

        for word in all_words:
            filename = WORD_TO_FILENAME.get(word)
            if not filename:
                print(f"  Skip: no filename mapping for '{word}'")
                continue
            output_path = os.path.join(output_dir, f"{filename}.mp3")
            if os.path.exists(output_path):
                print(f"  Exists: {output_path}, overwriting...")
            print(f"  Generating: {word} -> {filename}.mp3")
            tts_download(word, voice, output_path)


if __name__ == "__main__":
    main()
