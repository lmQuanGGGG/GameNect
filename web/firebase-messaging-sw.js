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
  if (clientList.some((client) => client.focused)) return;

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
  event.stopImmediatePropagation();
  event.notification.close();
  const { targetUrl = '/', payload = {} } = event.notification.data || {};

  event.waitUntil(async function () {
    await savePendingNotification(payload);

    const clientList = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    const sameOriginClients = clientList.filter((client) => {
      try {
        return new URL(client.url).origin === self.location.origin;
      } catch (e) {
        return false;
      }
    });

    const appClient =
      sameOriginClients.find((client) => client.focused) ||
      sameOriginClients.find((client) => client.visibilityState === 'visible') ||
      sameOriginClients[0];

    if (appClient) {
      await appClient.focus();

      if (targetUrl && targetUrl !== '/') {
        try {
          await appClient.navigate(targetUrl);
        } catch (e) {
          console.error('Failed to navigate existing client:', e);
        }
      }

      // Gửi cho Flutter xử lý route
      appClient.postMessage({ type: 'notification', data: payload });

      // Gửi lại sau chút để Flutter/PWA kịp resume
      setTimeout(() => {
        appClient.postMessage({ type: 'notification', data: payload });
      }, 500);

      return;
    }

    if (clients.openWindow) {
      return clients.openWindow(targetUrl);
    }
  }());
});

// Cache Firebase Storage media files for faster PWA reloads.
const MEDIA_CACHE_NAME = 'gamenect-media-cache';
const MEDIA_CACHE_MAX_ENTRIES = 1200;
const MEDIA_CACHE_MAX_AGE_MS = 1000 * 60 * 60 * 24 * 60; // 60 days
const MEDIA_CACHE_META_HEADER = 'x-gamenect-cached-at';

const isMediaRequest = (url, request) => {
  if (request.method !== 'GET') return false;
  if (request.headers.has('range')) return false;
  return (
    url.origin === 'https://firebasestorage.googleapis.com' ||
    url.origin === 'https://storage.googleapis.com' ||
    url.hostname.endsWith('.googleusercontent.com')
  );
};

const withCacheTimestamp = async (response) => {
  const headers = new Headers(response.headers);
  headers.set(MEDIA_CACHE_META_HEADER, Date.now().toString());
  return new Response(await response.blob(), {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
};

const trimMediaCache = async (cache) => {
  const requests = await cache.keys();
  const now = Date.now();
  const entries = [];

  for (const request of requests) {
    const response = await cache.match(request);
    const cachedAt = Number(response?.headers.get(MEDIA_CACHE_META_HEADER) || 0);
    if (cachedAt && now - cachedAt > MEDIA_CACHE_MAX_AGE_MS) {
      await cache.delete(request);
      continue;
    }
    entries.push({ request, cachedAt });
  }

  if (entries.length <= MEDIA_CACHE_MAX_ENTRIES) return;
  entries.sort((a, b) => (a.cachedAt || 0) - (b.cachedAt || 0));
  const overflow = entries.length - MEDIA_CACHE_MAX_ENTRIES;
  await Promise.all(entries.slice(0, overflow).map((entry) => cache.delete(entry.request)));
};

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Chỉ cache media immutable từ Firebase/Google Storage qua GET.
  if (isMediaRequest(url, event.request)) {
    event.respondWith(
      caches.open(MEDIA_CACHE_NAME).then(async (cache) => {
        const cachedResponse = await cache.match(event.request);
        if (cachedResponse) {
          return cachedResponse;
        }

        try {
          const networkResponse = await fetch(event.request);
          if (networkResponse && (networkResponse.status === 200 || networkResponse.type === 'opaque')) {
            // Lưu bản sao vào cache và dọn nền để giữ cache lớn nhưng không phình vô hạn.
            const responseForCache = networkResponse.type === 'opaque'
              ? networkResponse.clone()
              : await withCacheTimestamp(networkResponse.clone());
            await cache.put(event.request, responseForCache);
            trimMediaCache(cache);
          }
          return networkResponse;
        } catch (error) {
          console.error('Fetch and cache failed for Storage URL:', error);
          if (cachedResponse) return cachedResponse;
          return fetch(event.request);
        }
      })
    );
  }
});
