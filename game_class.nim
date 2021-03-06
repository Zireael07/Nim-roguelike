import dom, times
import html5_canvas

import strutils # for formatting floats

import math_helpers, map, tint_image, seq_tools, map_common
import factions

import camera
import alea

# type definition moved to type_defs
import type_defs

import tables

proc newGame*(canvas: Canvas) : Game =
    new result
    result.canvas = canvas
    result.context = canvas.getContext2D()
    # set up rng
    result.rng = aleaRNG();
    #result.explored = @[];
    result.game_state = PLAYER_TURN.int; # trick to use the int

proc newLevel*() : Level = 
    new result

    result.explored = @[];


proc gameMessage*(game:Game, msg:string) =
    game.game_messages.add((msg, (255,255,255)));


proc clearEffects*(game: Game) =
    #echo getTime();
    for e in game.level.effects:
        #echo ($e.start & " int: " & $e.interval);
        if getTime() >= (e.start + e.interval):
            game.rem_eff.add(e);

proc end_player_turn*(game:Game) =
    game.game_state = ENEMY_TURN.int

proc clearGame*(game: Game) =
    game.context.fillStyle = rgb(0,0,0);
    game.context.fillRect(0, 0, game.canvas.width.float, game.canvas.height.float)

# -----------
# pretty much just drawing functions from here down
proc renderGfxTile*(game: Game, img: Element, x,y: int) =
    game.context.drawImage((ImageElement)img, float(x), float(y));

# tinted version
proc renderGfxTileTinted*(game:Game, id: string, img: Element, tint:ColorRGB, x,y: int) =
    game.context.drawImage(tintImageNim((ImageElement)img, id, tint, 0.5), float(x), float(y));

proc drawText*(game:Game, text:string, x,y:int) =
    game.context.font = "12px Arial"
    game.context.fillStyle = rgb(255, 255, 255);
    fillText(game.context, text, float(x), float(y));

proc render*(game: Game, player: Entity) =
    # do nothing if dead
    if isNil(player):
        return
    let iso = isoPos(player.position.x, player.position.y, game.camera.offset);

    # marker (no need to calculate because player's always friendly to player lol)
    renderGfxTileTinted(game, "11_blue", game.images[11], (r:0, g:255, b:255), iso[0], iso[1]);

    # entities need a slight offset to be placed more or less centrally
    renderGfxTile(game, game.images[0], iso[0]+10, iso[1]+10);

# Note: currently the player is rendered separately (see above)
proc renderEntities*(game: Game, fov_map:seq[Vector2]) =
    for e in game.level.entities:
        let iso = isoPos(e.position.x, e.position.y, game.camera.offset);
        # if we can actually see the NPCs
        if (e.position.x, e.position.y) in fov_map:
            if not isNil(e.creature) and e.creature.faction != "":
                renderGfxTileTinted(game, "11_npc", game.images[11], e.creature.get_marker_color(game), iso[0], iso[1]);
            
            var off = (12,12);

            # creatures need a slight offset to be placed more or less centrally
            renderGfxTile(game, game.images[e.image], iso[0]+off[0], iso[1]+off[1]);

            # labels if any
            if game.labels:
                var txt_len = int(e.name.len()/2);
                drawText(game, e.name, iso[0]+off[0]-txt_len, iso[1]+off[1]-10);


var tile_lookup = {0: 1, 1:2, 2:8}.toTable()

proc drawMapTile(game: Game, point:Vector2, tile: int) =
    renderGfxTile(game, game.images[tile_lookup[tile]], point.x, point.y);

    # if tile == 0:
    #     renderGfxTile(game, game.images[1], point.x, point.y);
    # elif tile == 1:
    #     renderGfxTile(game, game.images[2], point.x, point.y);
    # elif tile == 2:
    #     renderGfxTile(game, game.images[8], point.x, point.y);

proc drawMapTileTint(game:Game, point:Vector2, tile:int, tint:ColorRGB) =
    renderGfxTileTinted(game, $tile_lookup[tile] & "_gray", game.images[tile_lookup[tile]], tint, point.x, point.y);
    #game.context.drawImage(tintImageNim(game.images[tile_lookup[tile]], tint, 0.5), float(point.x), float(point.y));

    # if tile == 0:
    #     game.context.drawImage(tintImageNim(game.images[1], tint, 0.5), float(point.x), float(point.y));
    # else:
    #     game.context.drawImage(tintImageNim(game.images[2], tint, 0.5), float(point.x), float(point.y));

proc renderMap*(game: Game, map: Map, fov_map: seq[Vector2], explored: var seq[Vector2], cam: Camera) =    
    # isometric camera
    var x:int;
    var y:int;

    for a in cam.startxy..cam.endxy:
        for b in cam.startxminy..cam.endxminy:
            # integer division
            x = (a+b) div 2;
            y = (a-b) div 2;

            # weirdness check
            if x < 0 or y < 0 or x > map.width or y > map.height:
                # skip
                continue
    
    # 0..x is inclusive in Nim
    #for x in 0..<map.width:
    #    for y in 0..<map.height:
            #echo map.tiles[y * map.width + x]
            var cell = (x,y)
            if cell in fov_map:
                drawMapTile(game, isoPos(x,y,cam.offset), map.tiles[y * map.width + x])
                if explored.find(cell) == -1:
                    add(explored, cell);
            elif (x,y) in explored:
                drawMapTileTint(game, isoPos(x,y,cam.offset), map.tiles[y * map.width + x], (127,127,127));

proc drawMessages*(game:Game) = 
    var drawn: seq[GameMessage];
    # what do we draw?
    if game.game_messages.len <= 5:
        drawn = game.game_messages
    else:
        # fancy slicing similar to Python's
        var view = SeqView[GameMessage](data:game.game_messages, bounds: game.game_messages.len-5..game.game_messages.len-1);
        #echo "seqView: " & $view;

        for el in view:
            drawn.add(el);

    # draw
    var y = 0;
    game.context.font = "12px Arial"
    for i in 0..drawn.len-1:
        var el = drawn[i];

        game.context.fillStyle = rgb(el[1][0], el[1][1], el[1][2])
        #game.context.fillStyle = rgb(255, 255, 255);
        fillText(game.context, el[0], 5.0, float(game.canvas.height-50+y));
        y += 10;

proc renderBar*(game:Game, x:int,y:int, total_width:int, value:int, maximum:int, bar_color:ColorRGB, bg_color:ColorRGB) =
    # draw the bg color
    game.context.beginPath();
    game.context.fillStyle = rgb(bg_color.r, bg_color.g, bg_color.b);
    game.context.rect(float(x),float(y), float(total_width), 10.0);
    game.context.fill();
        
    # calculate how big the actual bar is
    var perc = float(value)/float(maximum) * 100;
    #echo "v: " & $value & " perc: " & $perc;
    var bar_width = (perc / 100) * float(total_width);
    if bar_width > 0:
        game.context.beginPath();
        game.context.fillStyle = rgb(bar_color.r, bar_color.g, bar_color.b);
        game.context.rect(float(x), float(y), float(bar_width), 10.0);
        game.context.fill();

proc drawTargeting*(game:Game) =
    let iso = isoPos(game.targeting.x, game.targeting.y, game.camera.offset);
    renderGfxTile(game, game.images[7], iso[0], iso[1]);
    # show distance
    game.context.font = "12px Arial"
    game.context.fillStyle = rgb(255, 255, 255);
    fillText(game.context, "Dist: " & $game.player.position.distance_to(game.targeting), 10.0, 300.0); 

    # draw info on NPC if any
    var ent = get_creatures_at(game.level.entities, game.targeting.x, game.targeting.y); 
    if not isNil(ent):
        renderGfxTile(game, game.images[ent.image], 10, 250);
        var hp_perc = (float(ent.creature.hp)*100.0/float(ent.creature.max_hp));
        fillText(game.context, $ent.name, 10.0, 310.0);
        fillText(game.context, "Enemy hp: " & $ent.creature.hp & " " & $hp_perc & "%", 10.0, 320.0);
        # chance to hit
        # bit of a trouble with Nim/JS's floating point representation as opposed to Python's
        var melee = (parseFloat($(float(game.player.creature.melee)/100.0))*100.0).toInt;
        #fillText(game.context, "Chance to hit: " & $(melee) & "%", 10.0, 320.0);
        var not_dodged = (parseFloat($(float(100-ent.creature.dodge)/100.0))*100.0).toInt;
        var res = melee*not_dodged/100;
        #var res = parseFloat((melee*not_dodged).formatFloat(ffDecimal, 2))*100.0;
        fillText(game.context, "Chance to hit: " & $(melee) & "% + " & $(not_dodged) & "% = " & $res & "%", 10.0, 330.0);


proc drawDmgSplatter(game:Game, x,y:int, dmg: int) =
    let iso = isoPos(x,y, game.camera.offset);
    renderGfxTileTinted(game, "13_red", game.images[13], (255,0,0), iso[0]+12, iso[1]+16)
    # dmg
    game.context.font = "12px Arial"
    game.context.fillStyle = rgb(255, 255, 255);
    fillText(game.context, cstring($dmg), float(iso[0]+12+10), float(iso[1]+16+12));

proc drawShield(game:Game, x,y:int) =
    let iso = isoPos(x,y, game.camera.offset);
    renderGfxTile(game, game.images[14], iso[0]+12, iso[1]+12);

proc drawEffects*(game:Game) =
    for e in game.level.effects:
        var cell = (e.x,e.y);
        if cell in game.FOV_map:
            if e.id == "dmg":
                game.drawDmgSplatter(e.x,e.y,e.param);
            if e.id == "shield":
                game.drawShield(e.x,e.y);