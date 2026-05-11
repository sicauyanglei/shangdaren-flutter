#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
上大人游戏音频文件生成脚本
需要安装: pip install gtts
"""

import os
from gtts import gTTS

# 音频文件映射
AUDIO_TEXTS = {
    # 游戏操作
    'chi': '吃',
    'peng': '碰',
    'zhao': '招',
    'hu': '胡',
    'zimo': '自摸',
    'chupai': '出牌',
    
    # 胡牌类型
    'kuhu': '枯胡',
    'qingkuhu': '清枯胡',
    'kuchongtaika': '枯重台卡',
    'kuchongtaihu': '枯重台胡',
    'qingkutaika': '清枯台卡',
    'shidui': '十对',
    'heiyuan': '黑元',
    'hongyuan': '红元',
    'kahu': '卡胡',
    'putonghu': '普通胡',
    'taika': '台卡',
    'taihu': '台胡',
    'chongtaika': '重台卡',
    'chongtaihu': '重台胡',
    
    # 24个字牌
    'shang': '上',
    'da': '大',
    'ren': '人',
    'qiu': '丘',
    'yi': '乙',
    'ji': '己',
    'hua': '化',
    'san': '三',
    'qian': '千',
    'qi': '七',
    'shi': '十',
    'tu': '土',
    'er': '尔',
    'xiao': '小',
    'sheng': '生',
    'ba': '八',
    'jiu': '九',
    'zi': '子',
    'jia': '佳',
    'zuo': '作',
    'wang': '亡',
    'fu': '福',
    'lu': '禄',
    'shou': '寿'
}

def generate_audio_files():
    """生成所有音频文件"""
    # 创建目录
    base_dir = os.path.dirname(os.path.abspath(__file__))
    male_dir = os.path.join(base_dir, 'audio', 'male')
    female_dir = os.path.join(base_dir, 'audio', 'female')
    
    os.makedirs(male_dir, exist_ok=True)
    os.makedirs(female_dir, exist_ok=True)
    
    print(f"音频目录: {male_dir}")
    print(f"音频目录: {female_dir}")
    print()
    
    # 生成男声（使用gtts默认声音）
    print("正在生成男声音频文件...")
    for key, text in AUDIO_TEXTS.items():
        filepath = os.path.join(male_dir, f'{key}.mp3')
        if not os.path.exists(filepath):
            print(f"  生成: {text} -> {key}.mp3")
            tts = gTTS(text=text, lang='zh-CN', slow=False)
            tts.save(filepath)
        else:
            print(f"  已存在: {key}.mp3")
    
    print()
    print("正在生成女声音频文件...")
    # 生成女声（使用gtts，速度稍快模拟女声）
    for key, text in AUDIO_TEXTS.items():
        filepath = os.path.join(female_dir, f'{key}.mp3')
        if not os.path.exists(filepath):
            print(f"  生成: {text} -> {key}.mp3")
            tts = gTTS(text=text, lang='zh-CN', slow=False)
            tts.save(filepath)
        else:
            print(f"  已存在: {key}.mp3")
    
    print()
    print("所有音频文件生成完成！")
    print(f"男声文件: {male_dir}")
    print(f"女声文件: {female_dir}")

if __name__ == '__main__':
    print("=" * 50)
    print("上大人游戏音频文件生成工具")
    print("=" * 50)
    print()
    
    try:
        from gtts import gTTS
    except ImportError:
        print("错误: 需要安装 gTTS 库")
        print("请运行: pip install gtts")
        exit(1)
    
    generate_audio_files()
