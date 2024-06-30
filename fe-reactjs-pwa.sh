#!/bin/bash

# 1. Setup Project
npx create-react-app my-pwa-app --template redux
cd my-pwa-app

# Install dependencies
npm install @reduxjs/toolkit react-redux workbox-webpack-plugin tailwindcss postcss autoprefixer webpack-bundle-analyzer localforage redux-persist

# 2. Setup Redux Toolkit Query with Error Handling
cat <<EOT > src/features/apiSlice.js
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react';

export const apiSlice = createApi({
  reducerPath: 'api',
  baseQuery: fetchBaseQuery({ baseUrl: '/api' }),
  endpoints: (builder) => ({
    getItems: builder.query({
      query: () => 'items',
    }),
  }),
});

export const { useGetItemsQuery } = apiSlice;
EOT

# 3. Integrate Redux Store with Persist
cat <<EOT > src/app/store.js
import { configureStore } from '@reduxjs/toolkit';
import { apiSlice } from '../features/apiSlice';
import storage from 'redux-persist/lib/storage';
import { persistReducer, persistStore } from 'redux-persist';

const persistConfig = {
  key: 'root',
  storage,
};

const persistedReducer = persistReducer(persistConfig, {
  [apiSlice.reducerPath]: apiSlice.reducer,
});

export const store = configureStore({
  reducer: persistedReducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware().concat(apiSlice.middleware),
});

export const persistor = persistStore(store);
EOT

cat <<EOT > src/app/hooks.js
import { useDispatch, useSelector } from 'react-redux';
export const useAppDispatch = () => useDispatch();
export const useAppSelector = useSelector;
EOT

# 4. Setup Tailwind CSS with Dark Mode Support
npx tailwindcss init -p
cat <<EOT > tailwind.config.js
module.exports = {
  content: ['./src/**/*.{js,jsx,ts,tsx}', './public/index.html'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        primary: '#1a73e8',
        secondary: '#ff5722',
      },
    },
  },
  plugins: [],
};
EOT

cat <<EOT > src/index.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOT

# 5. Service Worker and Caching
cat <<EOT > src/service-worker.js
import { registerRoute } from 'workbox-routing';
import { StaleWhileRevalidate, CacheFirst } from 'workbox-strategies';
import { CacheableResponsePlugin } from 'workbox-cacheable-response';
import { BackgroundSyncPlugin } from 'workbox-background-sync';

// Background Sync for failed API requests
const bgSyncPlugin = new BackgroundSyncPlugin('apiQueue', {
  maxRetentionTime: 24 * 60,
});

// Cache images with CacheFirst strategy
registerRoute(
  ({ request }) => request.destination === 'image',
  new CacheFirst({
    cacheName: 'images',
    plugins: [
      new CacheableResponsePlugin({
        statuses: [0, 200],
      }),
    ],
  })
);

// Cache API responses with StaleWhileRevalidate strategy
registerRoute(
  ({ url }) => url.pathname.startsWith('/api/'),
  new StaleWhileRevalidate({
    cacheName: 'api-cache',
    plugins: [
      new CacheableResponsePlugin({
        statuses: [0, 200],
      }),
      bgSyncPlugin,
    ],
  })
);
EOT

# 6. Modify manifest.json
cat <<EOT > public/manifest.json
{
  "short_name": "PWA",
  "name": "My PWA App",
  "icons": [
    {
      "src": "favicon.ico",
      "sizes": "64x64 32x32 24x24 16x16",
      "type": "image/x-icon"
    }
  ],
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#1a73e8",
  "background_color": "#ffffff"
}
EOT

# 7. Create Example Components with Lazy Loading and Dark Mode
cat <<EOT > src/components/LazyImage.js
import React, { memo } from 'react';

const LazyImage = memo(() => (
  <img src="your-image-url.webp" alt="Lazy Loaded" loading="lazy" />
));

export default LazyImage;
EOT

cat <<EOT > src/theme.js
import { useState, useEffect } from 'react';

export const useDarkMode = () => {
  const [theme, setTheme] = useState(localStorage.getItem('theme') || 'light');

  useEffect(() => {
    const root = window.document.documentElement;
    root.classList.remove(theme === 'dark' ? 'light' : 'dark');
    root.classList.add(theme);
  }, [theme]);

  const toggleTheme = () => {
    const newTheme = theme === 'light' ? 'dark' : 'light';
    setTheme(newTheme);
    localStorage.setItem('theme', newTheme);
  };

  return { theme, toggleTheme };
};
EOT

cat <<EOT > src/App.js
import React, { Suspense } from 'react';
import { useGetItemsQuery } from './features/apiSlice';
import { Provider } from 'react-redux';
import { store, persistor } from './app/store';
import { PersistGate } from 'redux-persist/integration/react';
import { useDarkMode } from './theme';
const LazyImage = React.lazy(() => import('./components/LazyImage'));

function App() {
  const { data, error, isLoading } = useGetItemsQuery();
  const { theme, toggleTheme } = useDarkMode();

  return (
    <Provider store={store}>
      <PersistGate loading={null} persistor={persistor}>
        <div className={`App ${theme}`}>
          <button onClick={toggleTheme}>
            Toggle to {theme === 'light' ? 'Dark' : 'Light'} Mode
          </button>
          {navigator.onLine ? (
            <Suspense fallback={<div>Loading...</div>}>
              <LazyImage />
            </Suspense>
          ) : (
            <div>You are offline. Some features may be unavailable.</div>
          )}
          {isLoading ? (
            <div>Loading items...</div>
          ) : error ? (
            <div>Error loading items: {error.message}</div>
          ) : (
            <ul>
              {data.map((item) => (
                <li key={item.id}>{item.name}</li>
              ))}
            </ul>
          )}
        </div>
      </PersistGate>
    </Provider>
  );
}

export default App;
EOT

# 8. Webpack Bundle Analyzer
cat <<EOT > webpack.config.js
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
module.exports = {
  plugins: [
    new BundleAnalyzerPlugin(),
  ],
};
EOT

# 9. Run Lighthouse (Ensure you have Chrome and Lighthouse installed)
npm run build
npx serve -s build &
sleep 5
lighthouse http://localhost:3000 --view

echo "PWA setup complete. Your app is running on localhost:3000"
