# AI Quickstarts Scripts

Два PowerShell-скрипта для генерации quickstart-сценариев по Jira и применения фидбэка из комментариев.

## Что есть

- `scripts/New-QuickstartsFromJira.ps1` - генерация страниц quickstart по `summary + description + comments`.
- `scripts/Apply-QuickstartFeedback.ps1` - правки существующих страниц по комментариям.
- `scripts/lib/Quickstart.Common.ps1` - общие функции Jira/Confluence/AI CLI/JSON.

## Обязательные переменные окружения

- `ATLASSIAN_EMAIL`
- `ATLASSIAN_API_TOKEN`
- `ATLASSIAN_BASE_URL` (пример: `https://deviot.atlassian.net`)
- `CONF_ROOT_PARENT_ID` (id корневого контейнера `AI Quickstarts`, обычно folder id)

## Опциональные переменные окружения

- `CONF_ROOT_PARENT_TYPE` (`folder` по умолчанию, можно `page`)
- `CONF_SPACE_ID` (если не задан, скрипт попытается определить по `CONF_ROOT_PARENT_ID`)
- `CONF_LAST_CHANGES_PAGE_TITLE` (по умолчанию: `last changes`)
- `AI_AGENT_COMMAND` (по умолчанию: `claude`)

## Рекомендуемый порядок запуска

1) Локальная отладка через Cursor headless:

```powershell
.\scripts\New-QuickstartsFromJira.ps1 `
  -Ticket UMEC-1205 `
  -LocalOutputPath .\out `
  -AiCommand "cursor-agent -p --output-format stream-json --stream-partial-output --trust --approve-mcps --force"
```

2) Применение фидбэка локально:

```powershell
.\scripts\Apply-QuickstartFeedback.ps1 `
  -Ticket UMEC-1205 `
  -LocalOutputPath .\out `
  -AiCommand "cursor-agent -p --output-format stream-json --stream-partial-output --trust --approve-mcps --force"
```

3) Публикация в Confluence (если `-LocalOutputPath` не задан):

```powershell
.\scripts\New-QuickstartsFromJira.ps1 UMEC-1205
.\scripts\Apply-QuickstartFeedback.ps1 UMEC-1205
```

## Структура публикации

- Quickstart-страницы: `AI Quickstarts/<Ticket>/<quickstart-name>`, где `<Ticket>` создается как folder
- Last changes: страница с названием `CONF_LAST_CHANGES_PAGE_TITLE` под корнем `AI Quickstarts` (создается автоматически, если отсутствует)

## Примечания

- AI-ответ должен быть строго JSON по шаблону в `prompts/response-json-template.md`.
- Для Confluence используется REST API v2 (folders/pages).
- Если `AiCommand`/`AI_AGENT_COMMAND` указан без параметров (например, `claude` или `cursor-agent`), скрипт автоматически добавляет stream-флаги для прогресса.
- Если команда передана уже с параметрами, скрипт отправляет ее как есть.
- Если задан `-LocalOutputPath`, используется local-режим; иначе публикация в Confluence.
- В local-режиме сохраняются:
  - `out/<Ticket>/*.md`
  - `out/<Ticket>/agent-response.json`
  - `out/last-changes.md`

