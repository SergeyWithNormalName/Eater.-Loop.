# Правила безопасного рефакторинга

1. Не меняйте геймплей: скорости, тайминги мини-игр, delay-ы teleport, shader glitch timing, музыкальные fade-интервалы.
2. Не добавляйте `has_method/ call` между объектами проекта; вместо этого используйте `SceneRuleRunner` или публичный API.
3. Не трогайте `MusicManager` приватные `_`-методы — используйте только публичные хелперы.
4. Любой интерактивный объект должен использовать `InteractiveObject.play_feedback_sfx`, `set_interaction_enabled`, `locked_message` и `attachment` через публичные методы.
5. Power-sensitive объекты опираются на `PoweredSwitchableInteractable`: лампы/прожекторы/генератор не создают ad hoc взаимодействия между собой.
6. При любом изменении state/checkpoint добавьте тест, который подтверждает сохранение/восстановление (`test_save_state_split`, `test_respawn_checkpoint_restore`, `test_level_checkpoint_spawn`).
7. При миграции уровней вынесите wiring в `SceneRuleRunner` и добавьте `SceneRuleRunner` tests до или параллельно изменениям.
8. Документируйте новую систему (README + соответствующие docs) до того, как изменения попадут в мастер.
