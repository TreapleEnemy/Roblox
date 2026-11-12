# Изменения расширения

## Новые модули
- `src/client/Icons.luau`
- `src/server/ExpansionWorld.luau`
- `src/server/TravelService.luau`

## Изменённые исходники
- `src/client/Effects.luau`
- `src/client/Main.client.luau`
- `src/client/UI.luau`
- `src/server/EconomyService.luau`
- `src/server/Main.server.luau`
- `src/server/MobService.luau`
- `src/server/WorldBuilder.luau`
- `src/shared/Animator.luau`
- `src/shared/Config.luau`
- `src/shared/Models.luau`
- `src/shared/Rules.luau`

## Исходники без изменений
- `src/character/Health.server.luau`
- `src/server/CharacterService.luau`
- `src/server/CombatService.luau`
- `src/server/DataService.luau`
- `src/server/NPCService.luau`

## Проверка совместимости

Все прежние именованные функции модулей сохранены. Формат профиля и имя DataStore не изменены. Старые ключи Config.Items, Config.Mobs, Config.Zones и Remote-имена сохранены. Пределы этой проверки: только структура и офлайн-логика, не поведение реального движка.

Новые тесты: tests/expansion_spec.luau и tests/runtime_smoke.luau; переносимый тестовый запуск tools/portable_verify.py. Сборка tools/build.py поддерживает явный --portable.
