import times # for timing the special effects
import dom # for keypad
import tables
import math_helpers, math, alea, astar, map, map_common
import map_helpers
import calendar

# type definition moved to type_defs
import type_defs
import factions # to be able to use get_faction_reaction()
import table_tools

proc generate_stats*(typ="standard", kind="melee") : array[6,int] = 
    var arr : array[6, int]
    if typ == "heroic":
        arr = [ 15, 14, 13, 12, 10, 8]
    else:
        arr = [ 13, 12, 11, 10, 9, 8]

    var temp: array[6, int]
    if kind == "ranged":
        # STR DEX CON INT WIS CHA
        temp[0] = arr[2]
        temp[1] = arr[0]
        temp[2] = arr[1]
        temp[3] = arr[3]
        temp[4] = arr[4]
        temp[5] = arr[5]
    else:
        echo "Using default array"
        # STR DEX CON INT WIS CHA
        temp[0] = arr[0]
        temp[1] = arr[2]
        temp[2] = arr[1]
        temp[3] = arr[4]
        temp[4] = arr[3]
        temp[5] = arr[5]


    return temp
    


# Nim functions have to be defined before anything that uses them


# based on https://forum.nim-lang.org/t/2194
proc fieldval(cr: Creature, field: string): int {.discardable.} =
    if field == "melee":
        return cr.melee
    if field == "dodge":
        return cr.dodge

# equivalent for setting
proc setfield(cr: Creature, field: string, val: int) =
    if field == "melee":
        cr.melee = val
    if field == "dodge":
        cr.dodge = val

# d100 roll under
proc skill_test(cr: Creature, skill: string, game: Game) : bool =
    echo ("Making a test for " & skill & " target: " & $field_val(cr, skill))
    #var rng = aleaRNG();
    var res = game.rng.roller("1d100");

    #if result < getattr(self, skill):
    if res < fieldval(cr, skill):
            # player-only:
        if cr.owner == game.player:
            # check how much we gain in the skill
            var tick = game.rng.roller("1d100")
            # roll OVER the current skill
            if tick > fieldval(cr, skill):
                # +1d4 if we succeeded
                var gain = game.rng.roller("1d4")
                setfield(cr, skill, (fieldval(cr, skill) + gain));
                game.game_messages.add(("You gain " & $gain & " skill points!", (0,255,0)))
            else:
                # +1 if we didn't
                setfield(cr, skill, (fieldval(cr, skill) + 1));
                game.game_messages.add(("You gain 1 skill point", (0,255,0)))
        return true
    else:
        # player-only:
        if cr.owner == game.player:
            # if we failed, the check for gain is different
            var tick = game.rng.roller("1d100")
            # roll OVER the current skill
            if tick > fieldval(cr, skill):
                # +1 if we succeeded, else nothing
                setfield(cr, skill, (fieldval(cr, skill) + 1));
                game.game_messages.add(("You learn from your failure and gain 1 skill point", (0,255,0)))

        return false

# find closest enemy, up to a maximum range, and in the player's FOV
proc closest_monster*(player: Entity, entities: seq[Entity], fov_map:seq[Vector2], max_range:int) : Entity =
    var target: Entity;
    var closest_dist: int;
    closest_dist = max_range+1; # start with slightly more than maximum range
    for entity in entities:
        if not isNil(entity.creature) and entity != player and entity.position in fov_map:
            # calculate distance between this entity and the player
            var dist = player.position.distance_to(entity.position);
            if dist < closest_dist: # it's closer, so remember it
                target = entity
                closest_dist = dist

    return target

proc pick_up*(item: Item, e: Entity, game:Game) =
    if not isNil(e.inventory):
        e.inventory.items.add(item)
        game.game_messages.add(("Picked up item " & item.owner.name, (255,255,255)));
        # because it's no longer on map
        game.level.entities.delete(game.level.entities.find(item.owner));

proc drop*(item: Item, e: Entity, game:Game) =
    e.inventory.items.delete(e.inventory.items.find(item));
    # set position
    item.owner.position = e.position
    game.level.entities.add(item.owner);
    game.game_messages.add(("You dropped the " & $item.owner.name, (255,255,255)));

# Equipment system
proc display_name*(e: Entity) : string = 
    if not isNil(e.item):
        if not isNil(e.equipment) and e.equipment.equipped:
            return e.name & " (equipped)"
        else:
            return e.name
    else:
        return e.name

# returns the equipment in a slot, or nil if it's empty
proc get_equipped_in_slot(inv: Inventory, slot: string) : Equipment =
    for it in inv.items:
        if not isNil(it.owner.equipment) and it.owner.equipment.slot == slot and it.owner.equipment.equipped:
            return it.owner.equipment;
    return nil

proc unequip(eq: Equipment, e: Entity, game: Game= nil) =
    eq.equipped = false;
    if not isNil(game):
        game.game_messages.add((e.name & " took off " & $eq.owner.name, (255,255,255)));

proc equip*(eq: Equipment, e: Entity, game: Game = nil) =
    if isNil(e.inventory):
        return

    var old_equipment = get_equipped_in_slot(e.inventory, eq.slot);
    if not isNil(old_equipment):
        old_equipment.unequip(e, game);

    eq.equipped = true;
    if not isNil(game):
        game.game_messages.add((e.name & " equipped " & $eq.owner.name, (255,255,255)));


proc toggle_equip(eq: Equipment, e: Entity, game: Game) = 
    if eq.equipped:
        eq.unequip(e, game)
    else:
        eq.equip(e, game)

proc equipped_items(inv: Inventory) : seq[Item] =
    var list_equipped: seq[Item];
    
    for it in inv.items:
        if not isNil(it.owner.equipment) and it.owner.equipment.equipped:
            list_equipped.add(it);

    return list_equipped

proc get_weapon(e:Entity) : Item =
    if not isNil(e.inventory):
        for i in e.inventory.equipped_items:
            if not isNil(i.owner.equipment) and i.owner.equipment.num_dice > 0:
                #echo("We have a weapon " & $i.owner.name);
                return i

        # in case there is none
        return nil
    else:
        return nil

proc use_item*(item:Item, user:Entity, game:Game) : bool =
    # equippable items
    if not isNil(item.owner.equipment):
        item.owner.equipment.toggle_equip(user, game);
        return true

    # call proc?
    elif not isNil(item.use_func):
        echo "Calling use function"
        item.use_func(item, user, game);
        return true
    else:
        return false

# Nim property
# Unfortunately we can't name it the same as the variable itself,
# the manual indicates we should be able to, but there's a name collision...
proc get_defense*(cr:Creature): int {.inline.} =
    var ret = cr.defense

    if not isNil(cr.owner.inventory):
        # check for items
        for i in cr.owner.inventory.equipped_items:
            if i.owner.equipment.defense_bonus > 0:
                ret += i.owner.equipment.defense_bonus
                #echo("Added def bonus of " & $i.owner.equipment.defense_bonus);
    
    echo("Def: " & $ret)
    return ret

# we had to move setting body parts out of here... recursive imports...

proc random_body_part(cr:Creature) : BodyPart =
    var rng = aleaRNG();
    var loc = rng.roller("1d20");

    if loc < 3:
        return cr.body_parts[4] # left leg
    elif loc < 6:
        return cr.body_parts[5] # right leg
    elif loc < 13:
        return cr.body_parts[1] # torso
    elif loc < 16:
        return cr.body_parts[2] # left arm
    elif loc < 19:
        return cr.body_parts[3] # right arm
    else:
        return cr.body_parts[0] # head

proc heal_damage*(cr:Creature, amount: int) =
    var amount = amount;
    # prevent overhealing
    if cr.hp + amount > cr.max_hp:
        amount = cr.max_hp - cr.hp

    cr.hp += amount


# basic combat system
proc take_damage*(cr:Creature, amount:int) =
    # determine body part hit
    var part = cr.random_body_part();
    part.hp -= amount;

    #cr.hp -= amount;

    # kill!
    #if cr.hp <= 0:
    if (part.part == "torso" or part.part == "head") and part.hp <= 0:
        cr.dead = true;

proc attack*(cr:Creature, target:Entity, game:Game) =
    #var rng = aleaRNG();
    var damage = game.rng.roller("1d6");

    var weapon = cr.owner.get_weapon()
    if not isNil(weapon):
        #echo("We have a weapon, dmg " & $weapon.owner.equipment.num_dice & "d" & $weapon.owner.equipment.damage_dice);
        damage = game.rng.roller($weapon.owner.equipment.num_dice & "d" & $weapon.owner.equipment.damage_dice);

    var color = (127,127,127);
    if target == game.player:
        color = (255,0,0)

    #var attack_roll = rng.roller("1d100");
    #if attack_roll < target.creature.get_defense:
    if cr.skill_test("melee", game):
        game.game_messages.add((cr.owner.name & " hits " & target.name & "!", (255,255,255)));
        # assume target can try to dodge
        if target.creature.skill_test("dodge", game):
            game.game_messages.add((target.name & " dodges!", (0,255,0)));
        else:
            if damage > 0:
                target.creature.take_damage(damage);
                game.level.effects.add(Effect(id:"dmg", start: getTime(), interval:seconds(5), x:target.position.x, y:target.position.y, param:damage));
                game.game_messages.add((cr.owner.name & " attacks " & target.name & " for " & $damage & " points of damage!", color));
            else:
                game.game_messages.add((cr.owner.name & " attacks " & target.name & " but does no damage", color));
    else:
        game.game_messages.add((cr.owner.name & " misses " & target.name & "!", (114,114,255)));
        game.level.effects.add(Effect(id:"shield", start: getTime(), interval:seconds(5), x:target.position.x, y:target.position.y, param:0));

proc showDialogueKeypad(game:Game) =
    # dom magic
    dom.document.getElementById("keypad").style.display = "none";
    dom.document.getElementById("inventory_keypad").style.display = "block";

    var target = getInventoryKeypad();
    # these need to be created on the fly, depending on how many items we have...
    # Nim ranges are inclusive!
    for i in 0 .. game.talking_data.cr.chat.answers.len-1:
        createButton(target, i, cstring("dialogueSelectNim"));

proc showDialogue(game: Game, target: Entity) =
     # remember previous state
     game.previous_state = game.game_state
     game.game_state = GUI_S_DIALOGUE.int
     #echo $game.game_state
     game.talking_data = (target.creature, target.creature.chat.start, "")
     #echo $game.talking_data.cr.owner.name

     showDialogueKeypad(game);

# some functions that have our Entity type as the first parameter
proc move*(e: Entity, dx: int, dy: int, game:Game, map:Map, entities:seq[Entity]) : bool =
    ##echo("Move: " & $dx & " " & $dy);
    var tx = e.position.x + dx
    var ty = e.position.y + dy
    
    if tx < 0 or ty < 0:
        return false
    
    if tx > map.tiles.len or ty > map.tiles.len:
        return false

    # if it's a wall
    if map.tiles[ty * map.width + tx] == 0:
        return false

    # check for creatures
    var target:Entity;
    target = get_creatures_at(entities, tx, ty);
    #if not isNil(target):
    if not isNil(target) and target.creature.faction != e.creature.faction:
        var is_enemy_faction : bool;
        is_enemy_faction = get_faction_reaction(game, e.creature.faction, target.creature.faction) < 0;

        if is_enemy_faction:
            echo "Target faction " & $target.creature.faction & " is enemy!"
            #echo("You kick the " & $target.creature.name & " in the shins!");
            attack(e.creature, target, game);
        else:
            if target.creature.text != "":
                game.game_messages.add((target.name & " says: " & $target.creature.text, (255,255,255)));
            else:
                game.game_messages.add((target.name & " has nothing to say", (127,127,127)));

            # test
            if not isNil(target.creature.chat):
                #echo "creature has chat"
                echo ("Creature languages: " & $target.creature.languages & " player languages " & $e.creature.languages)
                echo ("Know same languages? " & $(target.creature.languages == e.creature.languages))

                # test
                var items: seq[Entity]
                items.add(spawnItembyID("chainmail", game.level.map));

                showDialogue(game, target);

                if items.len > 0:
                    game.shop_data.items = items;

                #dialogue_menu(game, target.name, target.creature.chat)
        
        # no need to recalc FOV
        return false
    
    if isNil(target):
        e.position = ((e.position.x + dx, e.position.y + dy))
        return true
    #echo e.position

proc move_towards(e:Entity, target:Vector2, game:Game, game_map:Map, entities:seq[Entity]) : bool =
    var dx = target.x - e.position.x
    var dy = target.y - e.position.y
    #var distance = math.sqrt(dx ** 2 + dy ** 2)
    var distance = distance_to(e.position, target);

    dx = int(round(dx / distance))
    dy = int(round(dy / distance))
    #echo ("dx " & $dx & " dy: " & $dy);

    if not game_map.is_blocked(e.position.x + dx, e.position.y + dy) or isNil(get_creatures_at(entities, e.position.x + dx, e.position.y + dy)):
        echo("We can move to " & $(e.position.x + dx) & " " & $(e.position.y + dy));
        return e.move(dx, dy, game, game_map, entities);

proc move_astar(e:Entity, target:Vector2, game:Game, game_map:Map, entities:seq[Entity]) =
    echo "Calling astar..."
    var astar = findPathNim(game_map, e.position, target, entities);
    # for e in astar:
    #     echo e
    if astar.len > 1:
        # get the next point along the path (because #0 is our current position)
        # it was already checked for walkability by astar so we don't need to do it again
        e.position = astar[1]
    else:
        # backup in case no path found
        discard e.move_towards(target, game, game_map, entities);

# how to deal with the fact that canvas ref is stored as part of Game?
#proc draw*(e: Entity) =

proc take_turn*(ai:AI, target:Entity, fov_map:seq[Vector2], game:Game, game_map:Map, entities:seq[Entity]) = 
    #var rng = aleaRNG();
    #echo ("The " & ai.owner.creature.name & "wonders when it will get to move");
    var monster = ai.owner
    # assume if we can see it, it can see us too
    if monster.position in fov_map:
        if monster.position.distance_to(target.position) >= 2:
            if monster.creature.faction != target.creature.faction:
                var is_neutral_faction = game.get_faction_reaction(monster.creature.faction, target.creature.faction, true) >= 0
                if is_neutral_faction:
                    discard monster.move(game.rng.range(-1..1), game.rng.range(-1..1), game, game_map, entities)
                else:
                    # discard means we're not using the return value
                    #discard monster.move_towards(target.position, game_map, entities);
                    monster.move_astar(target.position, game, game_map, entities);
        elif target.creature.hp > 0:
            var is_enemy_faction : bool;
            is_enemy_faction = get_faction_reaction(game, monster.creature.faction, target.creature.faction) < 0;

            if is_enemy_faction:
                echo "Target faction " & $target.creature.faction & " is enemy!"
                #echo ai.owner.creature.name & " insults you!";
                attack(ai.owner.creature, target, game);
            else:
                if monster.creature.text != "":
                    game.game_messages.add((monster.name & " says: " & $monster.creature.text, (255,255,255)));
                else:
                    game.game_messages.add((monster.name & " has nothing to say", (127,127,127)));

# Player-specific stuff
proc rest_stop(p: Player, game:Game) =
    p.resting = false
    # passage of time
    game.calendar.turn += calendar.HOUR*8
    game.game_messages.add(("Rested for " & $p.rest_cnt & " turns", (0,0,255)));
    game.game_messages.add((game.calendar.get_time_date(game.calendar.turn), (0,0,255)));


proc rest_start*(p:Player, turns:int, game:Game) =
    p.rest_cnt = 0
    p.resting = true
    p.rest_turns = turns
    game.game_messages.add(("Resting starts...", (0,0,255)));

    if p.resting and p.rest_cnt >= turns:
        p.rest_stop(game)
    else:
        # toggle game state to enemy turn
        game.game_state = ENEMY_TURN.int
        p.rest_cnt += 1

proc resting_step(p:Player, game:Game) =
    if not p.resting:
        return

    if p.resting and p.rest_cnt >= p.rest_turns:
        p.rest_stop(game)
    else:
        # actual resting stuff (actually only done once for simplicity)
        if p.rest_cnt == 6:
            # I think this formula dates back to Incursion
            var heal = int(((1+3)*p.owner.creature.base_con)/5)

            p.owner.creature.hp = int(min(p.owner.creature.max_hp, p.owner.creature.hp+heal))


        # toggle game state to enemy turn
        game.game_state = ENEMY_TURN.int
        p.rest_cnt += 1

proc act*(p:Player, game:Game) =
    if p.resting:
        p.resting_step(game);
    
    # count down nutrition/thirst
    # halve hunger rate when sleeping
    if p.resting:
        p.nutrition -= 0.5
        p.thirst -= 0.5
    else:
        p.nutrition -= 1
        p.thirst -= 1

proc add_money*(p:Player, amount:int) =
    for m in p.money:
        if m.kind == "silver":
            m.amount += amount

proc remove_money*(p:Player, amount:int) : bool =
    var ret = false
    for m in p.money:
        if m.kind == "silver" and m.amount - amount >= 0:
            m.amount -= amount
            ret = true

    return ret;