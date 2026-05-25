/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.12.4/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.4/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDFWNkvs7BMaehV7QrkW_8xL9dDW2MzGRA',
  authDomain: 'gamenect-9bec0.firebaseapp.com',
  projectId: 'gamenect-9bec0',
  storageBucket: 'gamenect-9bec0.firebasestorage.app',
  messagingSenderId: '226979979166',
  appId: '1:226979979166:web:8bf0340558aceae131408f',
  measurementId: 'G-D12ZYRV7LL',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(async (payload) => {
  const { notification = {}, data = {} } = payload;
  const title = notification.title || data.title || 'GameNect';
  
  // Ưu tiên path nếu backend có gửi, fallback về query parameters
  const query = new URLSearchParams(data).toString();
  const targetUrl = data.path ? data.path : (query ? `/?${query}` : '/');

  const clientList = await clients.matchAll({ type: 'window', includeUncontrolled: true });
  if (clientList.some((client) => client.visibilityState === 'visible')) return;

  await self.registration.showNotification(title, {
    body: notification.body || data.body || '',
    data: { targetUrl, payload: data },
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
  });
});

const savePendingNotification = async (payload) => {
  try {
    const cache = await caches.open('gamenect-pending-notifications');
    await cache.put('/pending', new Response(JSON.stringify(payload)));
  } catch (e) {
    console.error('Failed to save pending notification', e);
  }
};

self.addEventListener('message', (event) => {
  if (event.data?.type === 'GET_PENDING_NOTIFICATION') {
    event.waitUntil(
      caches.open('gamenect-pending-notifications').then(async (cache) => {
        const response = await cache.match('/pending');
        if (response && event.source) {
          event.source.postMessage({ type: 'notification', data: await response.json() });
          await cache.delete('/pending');
        }
      })
    );
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const { targetUrl = '/', payload = {} } = event.notification.data || {};

  event.waitUntil(async function() {
    await savePendingNotification(payload);

    const clientList = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    const appClient = clientList.find((c) => c.url.startsWith(self.registration.scope));

    if (appClient) {
      await appClient.focus();
      // Bắn trực tiếp message cho appClient xử lý redirect mượt mà ngay khi focus xong
      return appClient.postMessage({ type: 'notification', data: payload });
    }

    // Fix: phải dùng self.navigator trong Service Worker
    const isIOS = /iPad|iPhone|iPod/.test(self.navigator.userAgent);
    const isStandalone = self.location.search.includes('mode=standalone');
    
    if (isIOS && isStandalone) return; 

    if (clients.openWindow) {
      return clients.openWindow(targetUrl);
    }
  }());
});
