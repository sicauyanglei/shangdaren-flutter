// ============================================
// 屏幕适配 Hook
// 基于 1280x720 设计画布，获取屏幕实际尺寸并计算缩放比例
// ============================================

import { useState, useEffect } from 'react';
import Taro from '@tarojs/taro';

const DESIGN_W = 1280;
const DESIGN_H = 720;

export interface ScreenScale {
  /** 屏幕实际宽度 (px) */
  screenWidth: number;
  /** 屏幕实际高度 (px) */
  screenHeight: number;
  /** 1 设计宽度像素 = scaleW 实际像素 */
  scaleW: number;
  /** 1 设计高度像素 = scaleH 实际像素 */
  scaleH: number;
  /** 将设计稿宽度像素转为实际 px 值 */
  vw: (px: number) => string;
  /** 将设计稿高度像素转为实际 px 值 */
  vh: (px: number) => string;
}

export function useScreenScale(): ScreenScale {
  const [info, setInfo] = useState(() => {
    try {
      const sys = Taro.getSystemInfoSync();
      return { sw: sys.windowWidth, sh: sys.windowHeight };
    } catch {
      return { sw: DESIGN_W, sh: DESIGN_H };
    }
  });

  useEffect(() => {
    try {
      const sys = Taro.getSystemInfoSync();
      setInfo({ sw: sys.windowWidth, sh: sys.windowHeight });
    } catch {}
  }, []);

  const scaleW = info.sw / DESIGN_W;
  const scaleH = info.sh / DESIGN_H;

  return {
    screenWidth: info.sw,
    screenHeight: info.sh,
    scaleW,
    scaleH,
    vw: (px: number) => (px * scaleW) + 'px',
    vh: (px: number) => (px * scaleH) + 'px',
  };
}
