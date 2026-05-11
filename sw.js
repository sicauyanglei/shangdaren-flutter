const CACHE_NAME = 'shangdaren-v1';
const STATIC_ASSETS = [
  './',
  './index.html',
  './game.js',
  './manifest.json',
  './logo.png',
  './logo72.png',
  './logo96.png',
  './logo144.png',
  './logo192.png',
  './images/back.png'
];

const AUDIO_FILES = [
  'audio/male/shang.mp3', 'audio/male/da.mp3', 'audio/male/ren.mp3',
  'audio/male/qiu.mp3', 'audio/male/yi.mp3', 'audio/male/ji.mp3',
  'audio/male/hua.mp3', 'audio/male/san.mp3', 'audio/male/qian.mp3',
  'audio/male/qi.mp3', 'audio/male/shi.mp3', 'audio/male/tu.mp3',
  'audio/male/er.mp3', 'audio/male/xiao.mp3', 'audio/male/sheng.mp3',
  'audio/male/ba.mp3', 'audio/male/jiu.mp3', 'audio/male/zi.mp3',
  'audio/male/jia.mp3', 'audio/male/zuo.mp3', 'audio/male/wang.mp3',
  'audio/male/fu.mp3', 'audio/male/lu.mp3', 'audio/male/shou.mp3',
  'audio/male/hu.mp3', 'audio/male/zimo.mp3', 'audio/male/chupai.mp3',
  'audio/male/guo.mp3', 'audio/male/liuju.mp3',
  'audio/female/shang.mp3', 'audio/female/da.mp3', 'audio/female/ren.mp3',
  'audio/female/qiu.mp3', 'audio/female/yi.mp3', 'audio/female/ji.mp3',
  'audio/female/hua.mp3', 'audio/female/san.mp3', 'audio/female/qian.mp3',
  'audio/female/qi.mp3', 'audio/female/shi.mp3', 'audio/female/tu.mp3',
  'audio/female/er.mp3', 'audio/female/xiao.mp3', 'audio/female/sheng.mp3',
  'audio/female/ba.mp3', 'audio/female/jiu.mp3', 'audio/female/zi.mp3',
  'audio/female/jia.mp3', 'audio/female/zuo.mp3', 'audio/female/wang.mp3',
  'audio/female/fu.mp3', 'audio/female/lu.mp3', 'audio/female/shou.mp3',
  'audio/female/hu.mp3', 'audio/female/zimo.mp3', 'audio/female/chupai.mp3',
  'audio/female/guo.mp3', 'audio/female/liuju.mp3'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      cache.addAll(STATIC_ASSETS);
      AUDIO_FILES.forEach(file => {
        cache.add(file).catch(() => {});
      });
      return;
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      if (response) {
        return response;
      }
      return fetch(event.request).then((fetchResponse) => {
        if (!fetchResponse || fetchResponse.status !== 200) {
          return fetchResponse;
        }
        const responseToCache = fetchResponse.clone();
        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, responseToCache);
        });
        return fetchResponse;
      }).catch(() => {
        return caches.match(event.request);
      });
    })
  );
});
