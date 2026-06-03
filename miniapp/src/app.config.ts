export default defineAppConfig({
  pages: [
    'pages/home/index',
    'pages/settings/index',
    'pages/records/index',
    'pages/mine/index',
    'pages/game/index',
  ],
  window: {
    backgroundTextStyle: 'light',
    navigationBarBackgroundColor: '#0d2818',
    navigationBarTitleText: '上大人字牌',
    navigationBarTextStyle: 'white',
    navigationStyle: 'custom',
    pageOrientation: 'landscape',
  },
  tabBar: {
    color: '#86909c',
    selectedColor: '#ffd700',
    backgroundColor: '#0d2818',
    borderStyle: 'black',
    list: [
      { text: '大厅', pagePath: 'pages/home/index' },
      { text: '设置', pagePath: 'pages/settings/index' },
      { text: '战绩', pagePath: 'pages/records/index' },
      { text: '我的', pagePath: 'pages/mine/index' },
    ],
  },
})
