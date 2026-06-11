---
task-name: проверка dotnu-команд для агентских инструкций
status: draft
created: 2026-06-11
updated: 2026-06-11
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

- [ ] Каждая команда проверена живым запуском на текущем Nushell (версию
      зафиксировать в результатах), а не только прохождением существующих тестов
- [ ] Для команд с парсингом исходников зафиксировано: строчный/regex или AST;
      если строчный — оценено, дала бы замена на `ast-complete` /
      `split-statements` реальную надёжность, и записан вывод (менять / не менять)
- [ ] Интерактивные команды (`embeds-capture-start/stop`, `embed-add`,
      `embeds-setup`) проверены в живой nu-сессии, т.к. юнит-тесты их
      env-поведение не покрывают
- [ ] Найденные поломки записаны как отдельные пункты с минимальным репро
- [ ] Критерий успеха: по каждой команде вердикт — «работает», «работает, но
      есть AST-альтернатива лучше», «сломана (репро приложено)»

## Implementation plan

- [ ] Шаг 0: зафиксировать окружение — `version`, коммит dotnu; прогнать
      `nu toolkit.nu test` как базовую линию
- [ ] Шаг 1: чтение модулей — `list-module-exports`, `list-module-interface`,
      `module-commands-code-to-record` на реальных модулях (`dotnu/mod.nu`,
      `~/repos/nu-goodies`, `tests/assets/*`); сверить полноту со
      справочным `scope commands` после `use`
- [ ] Шаг 2: анализ зависимостей — `dependencies` (+ `--definitions-only`,
      `--keep-builtins`) и `filter-commands-with-no-tests` на
      `tests/assets/module-say` и на самом dotnu
- [ ] Шаг 3: embeds — `embeds-update` (файл и pipe-вариант), `examples-update`
      на копиях фикстур; проверить идемпотентность (повторный запуск → пустой
      git diff)
- [ ] Шаг 4: интерактив — в живой nu-сессии: `embeds-setup` (+ `--auto-commit`),
      `embeds-capture-start` → несколько команд → `embeds-capture-stop`,
      `embed-add`; проверить содержимое capture-файла
- [ ] Шаг 5: `set-x` (на `tests/assets/set-x-demo.nu`, запустить результат) и
      `extract-command-code` (+ `--set-vars`, `--clear-vars`; учесть, что
      дефолтный `--code-editor code` в контейнере недоступен — проверить
      `--echo` / `--output`)
- [ ] Шаг 6: аудит парсинга — для каждой команды из шагов 1–5 определить
      механизм парсинга в `commands.nu`; составить таблицу
      «команда → механизм → стоит ли переводить на AST»
- [ ] Шаг 7: свести результаты в этот файл (раздел «Результаты»), завести
      отдельные todo на найденные поломки и оправданные AST-переводы

## Affected files

- Existing files: `dotnu/commands.nu` (только чтение на этапе аудита),
  `tests/assets/*` (фикстуры для прогонов)
- New files: возможны новые todo по итогам шага 7; сам код в рамках этой
  задачи не меняется
