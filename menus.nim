import html5_canvas

import type_defs, entity
import calendar

# generic
proc menu(game:Game, header:string, options:seq[string], width:int=100, screen_width:int, screen_height:int, top:int=0, letters:bool=true, centered:bool=true, text="") =
    if options.len > 26: 
        echo("Cannot have a menu with more than 26 options.")
        return

    # calculate height
    let header_height = 2

    let menu_h = int(header_height + 1 + 26)
    let menu_y = int((50 - menu_h) / 2) + top

    var menu_x = 5.0
    if centered:
        menu_x = screen_width/2-width/2;
    
    # background
    game.context.fillStyle = rgb(0,0,0);
    game.context.fillRect(menu_x-2.0, float(menu_y * 10), float(width), float(menu_h * 10));

    game.context.font = "12px Arial";
    game.context.fillStyle = rgb(255, 255, 255);

    # print all the options
    #var y = header_height
    var y = (menu_y + header_height) * 10

    if text != "":
        fillText(game.context, text, menu_x, float(y))

        y += 15 

    var letter_index = ord('a')
    for option_text in options:
        var text = option_text
        if letters:
            text = "(" & chr(letter_index) & ") " & option_text

        fillText(game.context, text, menu_x, float(y));
        # experimental height between lines in px
        y += 10;
        if letters:
            letter_index += 1

# this one has no letters option, and therefore no 26 entries limit
proc menu_colored(game:Game, header:string, options:seq[GameMessage], width:int=100, screen_width:int, screen_height:int, centered=true) =
    # calculate height
    let header_height = 2

    let menu_h = int(header_height + 1 + 26)
    let menu_y = int((50 - menu_h) / 2)

    var menu_x = 5.0
    if centered:
        menu_x = screen_width/2-width/2;
    
    # background
    game.context.fillStyle = rgb(0,0,0);
    game.context.fillRect(menu_x-2.0, float(menu_y * 10), float(width), float(menu_h * 10));

    game.context.font = "12px Arial";
    #game.context.fillStyle = rgb(255, 255, 255);

    # print all the options
    var y = (menu_y + header_height) * 10

    for option in options:
        var text = option[0]
        game.context.fillStyle = rgb(option[1][0], option[1][1], option[1][2]);
        fillText(game.context, text, menu_x, float(y));
        # experimental height between lines in px
        y += 10;

proc multicolumn_menu*(game: Game, title:string, columns:seq[seq[string]], width:int=100, screen_width:int, wanted=1, current=0) =
    if columns[0].len > 26: 
        echo("Cannot have a menu with more than 26 options.")
        return
    
    # auto-center
    var menu_x = screen_width/2-width/2;

    let header_height = 2

    let menu_h = int(header_height + 1 + 26)
    let menu_y = int((50 - menu_h) / 2)

    # default column
    var cur_column = current
    # save number of columns
    game.multicolumn_total = len(columns);
    game.multicolumn_wanted = wanted;

    # background
    game.context.fillStyle = rgb(0,0,0);
    game.context.fillRect(menu_x-2.0, float(menu_y * 10), float(width), float(menu_h * 10));

    game.context.font = "12px Arial";
    game.context.fillStyle = rgb(255, 255, 255);

    fillText(game.context, "Press tab to change columns", menu_x, float(menu_y * 10));

    # print all the options
    var y = (menu_y + header_height) * 10
    # this continues the lettering between columns e.g ab | cd | ef
    var letter_index = ord('a')

    var x = menu_x

    for i in 0..(len(columns)-1):
        #col = columns[i]
        var w = 10*15
        y = (menu_y + header_height + 2) * 10
        # outline current column
        if i == cur_column:
            var h = float(len(columns[i]) * 10);
            game.context.strokeRect(x-1.0, float(y)-11.0, float(w), h+2.0);
            game.context.strokeStyle = rgb(255, 255, 255);


        # draw the column
        for option_text in columns[i]:
            var text = "(" & chr(letter_index) & ") " & option_text
            fillText(game.context, text, x, float(y));
            # experimental height between lines in px
            y += 10;

            letter_index += 1

        x += float(w)+2

        #i += 1


proc text_menu*(game:Game, header:string, text:seq[string], screen_width:int, width:int=100, centered=true) =
    # calculate height
    let header_height = 2

    let menu_h = int(header_height + 1 + 26)
    let menu_y = int((50 - menu_h) / 2)

    var menu_x = 5.0
    if centered:
        menu_x = screen_width/2-width/2;
    
    # background
    game.context.fillStyle = rgb(0,0,0);
    game.context.fillRect(menu_x-2.0, float(menu_y * 10), float(width), float(menu_h * 10));

    game.context.font = "12px Arial";
    game.context.fillStyle = rgb(255, 255, 255);

    var y = (menu_y + header_height) * 10

    #fillText(game.context, text, menu_x, float(y));
    # temporary until newlines/wordwrap work
    for txt in text:
        fillText(game.context, txt, menu_x, float(y));
        # experimental height between lines in px
        y += 10;

# specific
proc inventory_menu*(game:Game, header:string, inventory:Inventory, inventory_width:int, screen_width:int, screen_height:int) =
    var options: seq[string]
    # show a menu with each item of the inventory as an option
    if inventory.items.len == 0:
        options = @["Inventory is empty."]
    else:
        #options = [item.owner.name for item in inventory.items]
        for item in inventory.items:
            options.add(item.owner.display_name);

    menu(game, header, options, inventory_width, screen_width, screen_height)

proc character_stats_menu*(game:Game, player: Entity) =
    var options = @["STR: " & $player.creature.base_str, "DEX: " & $player.creature.base_dex,
                "CON: " & $player.creature.base_con, "INT: " & $player.creature.base_int,
                "WIS: " & $player.creature.base_wis, "CHA: " & $player.creature.base_cha,
                "(R)eroll! ", " (E)xit: "]

    menu(game, "STATS", options, 300, game.canvas.width, game.canvas.height, 10, false);

proc character_sheet_menu*(game:Game, header:string, player:Entity) =
    var options = @["STR: " & $player.creature.base_str, "DEX: " & $player.creature.base_dex,
               "CON: " & $player.creature.base_con, "INT: " & $player.creature.base_int,
               "WIS: " & $player.creature.base_wis, "CHA: " & $player.creature.base_cha,
               "Attack: " & $player.creature.melee, "Dodge: " & $player.creature.dodge,
               "", game.calendar.get_time_date(game.calendar.turn)]
    
    #show money
    for m in player.player.money:
        options.add(m.kind & ": " & $m.amount);
    
    menu(game, header, options, 300, game.canvas.width, game.canvas.height, 10, false)

proc dialogue_menu*(game:Game, header:string, text: string, options: seq[string]) =

    # var text = dialogue.start
    # var options : seq[string]
    # for a in dialogue.answers:
    #     options.add(a.chat)

    menu(game, header, options, 300, game.canvas.width, game.canvas.height, text=text);

proc shop_window*(game:Game, player: Entity, creature: Entity, items:seq[Entity], current=0) =

    var player_inv: seq[string]
    # player inv
    if player.inventory.items.len == 0:
        player_inv = @["Inventory is empty."]
    else:
        #options = [item.owner.name for item in inventory.items]
        for item in player.inventory.items:
            player_inv.add(item.owner.display_name & " (" & $item.price & ")");

    # shop
    var shop_inv: seq[string]
    if items.len == 0:
        shop_inv = @["Shop is empty"]
    else:
        for item in items:
            shop_inv.add(item.display_name & " (" & $item.item.price & ")");

    var columns = @[player_inv, shop_inv];

    multicolumn_menu(game, "SHOP", columns, 300, game.canvas.width, 1, current);


proc message_log*(game: Game) =

    # options
    var options: seq[GameMessage];
    for i in game.message_log_index[0]..game.message_log_index[1]:
        if i < game.game_messages.len:
            options.add(game.game_messages[i]);

    menu_colored(game, "MESSAGE LOG", options, 300, game.canvas.width, game.canvas.height);