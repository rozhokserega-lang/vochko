#!/usr/bin/env node
/**
 * Настройка Telegram Mini App через Bot API.
 *
 * Использование:
 *   BOT_TOKEN=123456:ABC WEBAPP_URL=https://example.com/ node telegram/setup.mjs
 *   node telegram/setup.mjs --token 123456:ABC --url https://example.com/
 *
 * Скрипт не требует зависимостей и ничего не сохраняет на диск.
 */

const args = process.argv.slice(2);

function readArg(name, envName) {
  const i = args.indexOf(`--${name}`);
  if (i !== -1 && args[i + 1]) return args[i + 1];
  return process.env[envName];
}

const token = readArg('token', 'BOT_TOKEN');
const url = readArg('url', 'WEBAPP_URL');

if (!token) {
  console.error('Не задан токен. Укажите BOT_TOKEN или --token.');
  process.exit(1);
}
if (!url) {
  console.error('Не задан URL. Укажите WEBAPP_URL или --url.');
  process.exit(1);
}
if (!/^https:\/\//i.test(url)) {
  console.error('Telegram Mini App требует HTTPS. URL должен начинаться с https://');
  process.exit(1);
}

async function api(method, body = {}) {
  const res = await fetch(`https://api.telegram.org/bot${token}/${method}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!data.ok) {
    throw new Error(`${method}: ${data.description || `HTTP ${res.status}`}`);
  }
  return data.result;
}

try {
  const me = await api('getMe');
  console.log(`Бот: @${me.username} (${me.first_name})`);

  await api('setChatMenuButton', {
    menu_button: {
      type: 'web_app',
      text: 'Играть',
      web_app: { url },
    },
  });
  console.log(`Меню-кнопка «Играть» → ${url}`);

  const menu = await api('getChatMenuButton');
  console.log('Проверка меню-кнопки:', JSON.stringify(menu));

  await api('setMyDescription', {
    description:
      'ВОЧКО — двадцать одно: карточный рогалик-колодострой. Три стола, общая колода, джокеры и боссы.',
  });
  await api('setMyShortDescription', {
    short_description: 'Карточный рогалик-колодострой',
  });
  console.log('Описание бота обновлено.');

  console.log(`\nГотово. Откройте @${me.username} в Telegram и нажмите «Играть».`);
} catch (err) {
  console.error(`\nОшибка: ${err.message}`);
  if (/unauthorized|not found/i.test(err.message)) {
    console.error('Проверьте токен: он выглядит как 123456:ABC-DEF...');
  }
  process.exit(1);
}
