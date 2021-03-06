import type_defs, entity

proc heal*(item:Item, user:Entity, game:Game) =
    echo "Heal..."
    if user.creature.hp < user.creature.max_hp:
        heal_damage(user.creature, 5);
        #var amount = min(user.creature.max_hp-user.creature.hp, 5);
        #user.creature.hp += amount;
        user.inventory.items.delete(user.inventory.items.find(item));

proc cast_lightning*(item:Item, user:Entity, game:Game) =
    var tg = closest_monster(game.player, game.level.entities, game.FOV_map, 4);
    if isNil(tg):
        game.game_messages.add(("No enemy is close enough to strike", (255,0,0)));
    else:
        tg.creature.take_damage(8);
        game.game_messages.add(("A lightning bolt strikes " & $tg.name & " and deals 8 damage!", (0,255,0)));
    # destroy
    game.player.inventory.items.delete(game.player.inventory.items.find(item));
    # standard stuff
    game.game_messages.add(($game.player.name & " uses " & $item.owner.name, (255,255,255)));