# Telegram Mini App

Игра уже умеет работать внутри Telegram: подключён `telegram-web-app.js`, есть тактильный отклик, `BackButton` для правил и подтверждение закрытия во время забега. Бэкенд не нужен — это статический сайт на GitHub Pages.

## 1. Создать бота

1. Откройте [@BotFather](https://t.me/BotFather).
2. Отправьте `/newbot`.
3. Задайте имя (например, `ВОЧКО`) и username (например, `vochko_bot`).
4. Сохраните токен вида `123456789:AA...`.

## 2. Прописать URL

Нужен HTTPS-адрес. Для этого репозитория это:

```
https://rozhokserega-lang.github.io/vochko/
```

Выполните в корне репозитория (PowerShell):

```powershell
$env:BOT_TOKEN="123456789:AA..."
$env:WEBAPP_URL="https://rozhokserega-lang.github.io/vochko/"
node telegram/setup.mjs
```

Или в bash:

```bash
BOT_TOKEN="123456789:AA..." \
WEBAPP_URL="https://rozhokserega-lang.github.io/vochko/" \
node telegram/setup.mjs
```

Скрипт выставит меню-кнопку «Играть» и описание бота. Токен нигде не сохраняется.

## 3. Открыть

Зайдите в бота и нажмите кнопку **«Играть»** слева от поля ввода. На некоторых клиентах она спрятана в меню чата.

Если кнопки нет — перезапустите Telegram или проверьте бота через `/mybots` → *Bot Settings* → *Menu Button*.

## Вручную через BotFather

Если не хотите запускать скрипт:

1. `/mybots` → выберите бота.
2. *Bot Settings* → *Menu Button* → *Configure menu button*.
3. Отправьте URL `https://rozhokserega-lang.github.io/vochko/` и текст кнопки `Играть`.

## Обновления

```bash
git add .
git commit -m "update"
git push
```

GitHub Pages обновится за минуту. Telegram кэширует WebView: закройте мини-апп и откройте заново (или потяните вниз для перезагрузки).

## Если что-то не работает

| Симптом | Что проверить |
|---|---|
| `Ошибка: Not Found` | Неверный токен. Скопируйте его из BotFather целиком. |
| `Telegram Mini App требует HTTPS` | URL должен начинаться с `https://`, не `http://`. |
| Кнопка «Играть» не появилась | Перезапустите Telegram; проверьте Menu Button в `/mybots`. |
| Открывается пустая страница | Откройте URL в браузере. Если 404 — Pages ещё собирается или репозиторий приватный. |
| Старая версия игры | Закройте и откройте мини-апп; проверьте, что `git push` дошёл до `main`. |
| Токен попал в git | `/revoke` у BotFather и выпустите новый. |

## Безопасность

- Не коммитьте `BOT_TOKEN` и не вставляйте его в `index.html`.
- Скрипт читает токен из переменной окружения или аргумента `--token`.
- Mini App не получает доступ к сообщениям и не требует данных пользователя: `initData` не используется.
