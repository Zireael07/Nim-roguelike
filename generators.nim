import data_loader
import jsffi # to be able to do stuff with the data we loaded from JS side
import type_defs
import entity

# globals
var items_data*: JsObject;
var monster_data*: JsObject;

proc loadfiles*() =
    data_loader.load_files(@[cstring("/data/items"), cstring("/data/test")]);


    # test
    #data_loader.loadfile("/data/items");

proc generateItem*(id:string, x: int, y:int) : Entity =
    echo "Generate item with id: " & $id

    if isNil(items_data[id]):
        echo("No item with id " & $id);
        return nil

    else:
        var item_name = to(items_data[id]["name"], cstring);
        echo $item_name;

        var item_image = to(items_data[id]["image"], int);
        echo $item_image;
        
        var en_it = Entity(position:(x,y), image:item_image, name: $item_name);
        # item component
        var it = Item(owner:en_it);
        en_it.item = it;

        var item_type = to(items_data[id]["type"], cstring);

        # optional parameters depending on type
        if item_type == "weapon":
            var num_dice = to(items_data[id]["damage_number"], int);
            var damage_dice = to(items_data[id]["damage_dice"], int);

            # equipment component
            var eq = Equipment(owner:en_it, num_dice: num_dice, damage_dice:damage_dice);
            en_it.equipment = eq;
        
        if item_type == "armor":
            var def_bonus = to(items_data[id]["combat_armor"], int);
            # equipment component
            var eq = Equipment(owner:en_it, defense_bonus: def_bonus);
            en_it.equipment = eq;

        echo("Spawned item at " & $en_it.position);
        return en_it;

proc generateMonster*(id: string, x,y:int) : Entity =
    echo "Generate monster with id: " & $id

    if isNil(monster_data[id]):
        echo("No monster with id " & $id);
        return nil

    else:
        var mon_name = to(monster_data[id]["name"], cstring)
        var item_image = to(monster_data[id]["image"], int);
        echo $item_image;
        
        var mon = Entity(position:(x,y), image:item_image, name: $mon_name);

        var mon_hp = to(monster_data[id]["hit_points"], int)
        #var mon_dam_num = to(monster_data[id]["damage_number"], int)
        #var mon_dam_dice = to(monster_data[id]["damage_dice"], int)

        # creature component
        var creat = newCreature(owner=mon, hp=mon_hp, defense=30, attack=20);
        mon.creature = creat;
        # AI component
        var AI_comp = AI(owner:mon);
        mon.ai = AI_comp;

        echo("Spawned monster at " & $mon.position);
        return mon;

proc getData*() : seq[JsObject] =
    var data = data_loader.get_loaded();

    return data

# the callback on loading all data files was moved to main.nim


