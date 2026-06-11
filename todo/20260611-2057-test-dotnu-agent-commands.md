---
task-name: проверка dotnu-команд для агентских инструкций
status: completed
created: 2026-06-11
updated: 2026-06-11
completed: 2026-06-11
---

# Проверить все dotnu-команды из черновика агентских инструкций

## Task from user (original)

мне нравится план. Давай сначала напишем todo /10_create_update_todo чтобы протестирвоать все упомянутые команды. Я боюсь что они могли выйти из строя с обновлениями, либо у них могуть быть лучше альтернативы с использованием парсинга ast.

## Task description (extended version)

Готовится секция для глобального CLAUDE.md, которая рекомендует агентам
dotnu-команды как основной инструментарий для работы с Nushell-модулями.
Перед тем как «культивировать» эти команды, нужно убедиться, что каждая из них:

1. **работает на текущем Nushell** в контейнере cozy (команды могли сломаться
   с обновлениями Nushell или самого dotnu);
2. **не имеет лучшей альтернативы на AST-парсинге**. В репо уже есть
   AST-инфраструктура (`ast-complete`, `split-statements` — см.
   `todo/20260105-005-ast-tooling-summary-and-future.md`), и часть команд на неё
   переведена (`find-examples`, `list-module-commands`). Остальные могут всё ещё
   использовать строчный/regex-парсинг, который менее надёжен.

Список команд для проверки (из черновика инструкций):

| Команда | Группа |
|---|---|
| `list-module-exports` | чтение модулей |
| `list-module-interface` | чтение модулей |
| `module-commands-code-to-record` | чтение модулей |
| `dependencies` | анализ зависимостей |
| `filter-commands-with-no-tests` | анализ зависимостей |
| `embeds-update` | embeds / доказательства |
| `examples-update` | embeds / доказательства |
| `embed-add` | embeds, интерактив |
| `embeds-setup` | embeds, интерактив |
| `embeds-capture-start` / `embeds-capture-stop` | embeds, интерактив |
| `set-x` | профилирование |
| `extract-command-code` | отладка |

## Requirements

- [x] Каждая команда проверена живым запуском на текущем Nushell (версию
      зафиксировать в результатах), а не только прохождением существующих тестов
- [x] Для команд с парсингом исходников зафиксировано: строчный/regex или AST;
      если строчный — оценено, дала бы замена на `ast-complete` /
      `split-statements` реальную надёжность, и записан вывод (менять / не менять)
- [x] Интерактивные команды (`embeds-capture-start/stop`, `embed-add`,
      `embeds-setup`) проверены в живой nu-сессии, т.к. юнит-тесты их
      env-поведение не покрывают
- [x] Найденные поломки записаны как отдельные пункты с минимальным репро
- [x] Критерий успеха: по каждой команде вердикт — «работает», «работает, но
      есть AST-альтернатива лучше», «сломана (репро приложено)»

## Implementation plan

- [x] Шаг 0: зафиксировать окружение — `version`, коммит dotnu; прогнать
      `nu toolkit.nu test` как базовую линию
- [x] Шаг 1: чтение модулей — `list-module-exports`, `list-module-interface`,
      `module-commands-code-to-record` на реальных модулях (`dotnu/mod.nu`,
      `~/repos/nu-goodies`, `tests/assets/*`); сверить полноту со
      справочным `scope commands` после `use`
- [x] Шаг 2: анализ зависимостей — `dependencies` (+ `--definitions-only`,
      `--keep-builtins`) и `filter-commands-with-no-tests` на
      `tests/assets/module-say` и на самом dotnu
- [x] Шаг 3: embeds — `embeds-update` (файл и pipe-вариант), `examples-update`
      на копиях фикстур; проверить идемпотентность (повторный запуск → пустой
      git diff)
- [x] Шаг 4: интерактив — в живой nu-сессии: `embeds-setup` (+ `--auto-commit`),
      `embeds-capture-start` → несколько команд → `embeds-capture-stop`,
      `embed-add`; проверить содержимое capture-файла
- [x] Шаг 5: `set-x` (на `tests/assets/set-x-demo.nu`, запустить результат) и
      `extract-command-code` (+ `--set-vars`, `--clear-vars`; учесть, что
      дефолтный `--code-editor code` в контейнере недоступен — проверить
      `--echo` / `--output`)
- [x] Шаг 6: аудит парсинга — для каждой команды из шагов 1–5 определить
      механизм парсинга в `commands.nu`; составить таблицу
      «команда → механизм → стоит ли переводить на AST»
- [x] Шаг 7: свести результаты в этот файл (раздел «Результаты»), завести
      отдельные todo на найденные поломки и оправданные AST-переводы

## Affected files

- Existing files: `dotnu/commands.nu` (только чтение на этапе аудита),
  `tests/assets/*` (фикстуры для прогонов)
- New files: возможны новые todo по итогам шага 7; сам код в рамках этой
  задачи не меняется

## Результаты

**Окружение:** Nushell 0.113.1, dotnu commit 7763f51, контейнер cozy.
Базовая линия: `nu toolkit.nu test` — 74 passed, 0 failed.

### Сводная таблица вердиктов

| Команда | Вердикт | Парсинг | Переводить на AST? |
|---|---|---|---|
| `list-module-exports` | работает, но 2 бага на `export use` (репро: todo/20260611-2112) | AST (`ast --flatten` в `extract-exported-commands`) | уже AST; чинить семантику `main`/bare `export use` |
| `list-module-interface` | работает (только `main`-команды по контракту; `[main]` для module-say, null без main) | строчный regex `^(export )?def ` + `extract-command-name` | низкий приоритет: anchored-regex ломается только на `def main` внутри многострочной строки с начала строки |
| `module-commands-code-to-record` | **сломана** (репро: todo/20260611-2110) | строчный + ручной forward-fill; `append null` стал no-op → смещение всех строк | да — `split-statements` даёт границы def-statement по байтам; оправданный перевод |
| `dependencies` (+`--definitions-only`, `--keep-builtins`) | работает (module-say и сам dotnu, оба флага) | AST (`list-module-commands`: `ast-complete` + `split-statements`) | уже AST |
| `filter-commands-with-no-tests` | работает (coverage-пайплайн из CLAUDE.md: 6 непокрытых команд) | не парсит исходники (фильтр таблицы) | n/a |
| `embeds-update` (файл и pipe) | работает; идемпотентна (повторный запуск — файл не меняется) | строчный: `# => `-фильтр + regex `\| print $in$` | нет: embeds — построчные комментарии by design; единственный риск — литеральная строка с `\n# => ` внутри (редко) |
| `examples-update` | работает; идемпотентна (5 → 4, "stale" → "a-b" на свежей фикстуре) | AST (`find-examples` на `ast-complete`) | уже AST |
| `embeds-setup` (+`--auto-commit`) | работает (env выставлен, файл создан, autocommit в git сделан) | не парсит | n/a |
| `embeds-capture-start/stop` | **сломаны вне интерактива автора**: `cprint` не определён в dotnu (репро: todo/20260611-2111); в живом REPL (sqlite history + nu-goodies overlay) capture-цикл работает корректно | не парсит (display_output hook + sqlite history) | n/a |
| `embed-add` | работает в живом REPL (с вводом и без); связка quirk'ов — см. todo/20260611-2111 | regex по истории (sqlite) | n/a |
| `set-x` | работает (`set-x-demo_setx.nu` запущен: 502ms/703ms/807ms на sleep 0.5/0.7/0.8) | split по пустым строкам (regex) | нет: пустая строка — пользовательская граница блока (контракт, не парсинг); AST сменил бы семантику |
| `extract-command-code` (+`--echo`, `--output`, `--set-vars`, `--clear-vars`) | работает (все флаги; `--code-editor` не нужен при `--echo`/`--output`) | runtime-интроспекция: `view source` через `nu -n -c` — надёжнее любого парсинга | n/a |

### Найденные поломки (отдельные todo заведены)

1. `module-commands-code-to-record` — мусор на любом модуле, где до первого
   `def` есть строки (`use`, комментарии): `append null` теперь no-op,
   forward-fill короче таблицы, `merge` смещает всё.
   → todo/20260611-2110-fix-module-commands-code-to-record.md
2. `embeds-capture-start/stop` — `cprint` нигде не определён/не импортирован;
   падает в `nu -c` и `nu -n` (работает только после
   `overlay use nu-goodies` в интерактиве).
   → todo/20260611-2111-fix-capture-cprint-dependency.md
3. `list-module-exports` — `main` из `export use sub.nu [main]` получает имя
   родительского модуля (дубль `nu-goodies` × 2 вместо `gradient-screen`,
   `cprint`); bare `export use file.nu` пропускается.
   → todo/20260611-2112-fix-list-module-exports-export-use.md

### Заметки для агентских инструкций

- Интерактив проверен через настоящий PTY-REPL (pexpect, с ответами на
  terminal-query `ESC[6n`/DA1): capture-файл корректен, идемпотентного
  мусора нет; `embeds-capture-stop` себя в файл не пишет, а вот
  `embeds-capture-start` пишет (см. todo 2111).
- `embed-add`/capture требуют sqlite-историю; `nu -c` без конфига даёт
  plaintext → null → невнятная ошибка. В инструкциях стоит явно писать:
  capture-команды — только для интерактивных сессий.
- `extract-command-code`: если в модуле есть `export def main`, запуск
  извлечённого файла через `nu file.nu` выполнит и `main` (файл делает
  `source mod.nu`, а `nu script.nu` вызывает `main` после исполнения тела).
- Сверка с `scope commands` для nu-goodies: расхождения только из багов
  todo 2112 плюс std-кастомные `banner`/`pwd` (попадают в `scope commands`
  без модуля — учитывать при таких сверках).

## Execution result

**Date:** 2026-06-11 21:15 UTC
**Created files:**
- `todo/20260611-2110-fix-module-commands-code-to-record.md` — поломка forward-fill
- `todo/20260611-2111-fix-capture-cprint-dependency.md` — скрытая зависимость cprint + quirks capture/embed-add
- `todo/20260611-2112-fix-list-module-exports-export-use.md` — баги export use

**Modified files:**
- `todo/20260611-2057-test-dotnu-agent-commands.md` — раздел «Результаты», статус

**Summary:**
Все 13 команд из списка проверены живым запуском на Nushell 0.113.1
(интерактивные — через настоящий PTY-REPL). 10 работают, 2 поломки
(`module-commands-code-to-record`, `embeds-capture-start/stop` вне
интерактива), 1 команда с багами на `export use` (`list-module-exports`).
Единственный оправданный AST-перевод — `module-commands-code-to-record`
на `split-statements`; остальные строчные парсеры либо line-oriented by
design (embeds, set-x), либо уже на AST. Код dotnu не менялся.
