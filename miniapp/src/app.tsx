import React from 'react';
import { useDidShow, useDidHide } from '@tarojs/taro';
import './app.scss';

function App(props) {
  useDidShow(() => {});
  useDidHide(() => {});
  return props.children;
}

export default App;
