' Daleks clone by MuffinTrap
' Original Daleks game for Macintosh by xxx 

#include "fbgfx.bi"
USING FB


' Type declarations
ENUM MAP_RESULT
    player_win
    robots_win
    no_win
    new_game
    game_quit
END ENUM

ENUM GAME_LOOP_STATE
    wait_input
    animate_player
    animate_robots
    collision_check
    exit_loop
END ENUM

ENUM ROBOT_STATE
    operational
    broken
    vaporized
END ENUM

ENUM PLAYER_ACTION
    no_action
    move_action
    teleport_action
    sonic_bomb
    last_stand
    action_new_game
    action_quit_game
END ENUM

TYPE VECTOR2
    x AS SINGLE
    y AS SINGLE
    DECLARE OPERATOR LET (BYREF rhs AS VECTOR2)
END TYPE

OPERATOR VECTOR2.LET (BYREF rhs AS VECTOR2)
    x = rhs.x
    y = rhs.y
END OPERATOR

TYPE TILE
    x AS INTEGER
    y AS INTEGER
    DECLARE OPERATOR LET (BYREF rhs AS TILE)
END TYPE

OPERATOR TILE.LET (BYREF rhs AS TILE)
    x = rhs.x
    y = rhs.y
END OPERATOR

OPERATOR = (BYREF lhs AS TILE, BYREF rhs AS TILE) AS INTEGER
    IF lhs.x = rhs.x AND lhs.y = rhs.y THEN
        RETURN TRUE
    ELSE
        RETURN FALSE
    END IF
END OPERATOR

OPERATOR <> (BYREF lhs AS TILE, BYREF rhs AS TILE) AS INTEGER
    IF lhs.x = rhs.x AND lhs.y = rhs.y THEN
        RETURN FALSE
    ELSE
        RETURN TRUE
    END IF
END OPERATOR

TYPE ROBOT
    current_tile AS TILE
    target_tile AS TILE
    state AS ROBOT_STATE
END TYPE

TYPE PLAYER
    robo AS ROBOT
    sonic_bomb AS INTEGER
    last_stand AS INTEGER
    score AS INTEGER
    action AS PLAYER_ACTION
END TYPE

TYPE BUTTON
    position AS VECTOR2 
    size AS VECTOR2
    text AS STRING
    pressed AS INTEGER
    
    DECLARE SUB create_button(x AS INTEGER, y AS INTEGER, w AS INTEGER, h AS INTEGER _
        ,s AS STRING)
END TYPE

SUB BUTTON.create_button (x AS INTEGER, y AS INTEGER, w AS INTEGER, h AS INTEGER _
        ,s AS STRING)
    WITH THIS
        .position.x = x
        .position.y = y
        .size.x = w
        .size.y = h
        .text = s
        .pressed = FALSE
    END WITH
END SUB



' Function declarations
' Game state
DECLARE SUB test_functions
DECLARE SUB load_graphics
DECLARE SUB init_game
DECLARE SUB init_map (map_number AS INTEGER)
DECLARE SUB run_game
DECLARE FUNCTION game_loop AS MAP_RESULT
DECLARE FUNCTION get_map_result AS MAP_RESULT
DECLARE SUB check_collisions
DECLARE SUB move_robots
DECLARE SUB calculate_robot_targets

' Timing
DECLARE SUB start_frame_timing
DECLARE SUB end_frame_timing

' Drawing
DECLARE SUB draw_menu
DECLARE SUB draw_button (button_to_draw AS BUTTON, enabled AS INTEGER)
DECLARE SUB draw_tiles
DECLARE SUB draw_robots_and_player (state AS GAME_LOOP_STATE)
DECLARE SUB draw_mouse (x AS INTEGER, y AS INTEGER)

' Tiles
DECLARE FUNCTION get_random_tile AS TILE
DECLARE FUNCTION get_center_tile AS TILE
DECLARE FUNCTION get_tile_pixel_coordinates (tile_coords AS TILE) AS VECTOR2
DECLARE SUB print_tile (name_string AS STRING, tile_coords AS TILE)
DECLARE FUNCTION is_pixel_inside_tile (pixel_pos AS VECTOR2, tile AS TILE) AS INTEGER

' Robots
DECLARE FUNCTION find_free_tile (max_robo_inced AS INTEGER) AS TILE
DECLARE FUNCTION is_tile_occupied (tile AS TILE) AS INTEGER
DECLARE FUNCTION robot_collision (robo_a AS ROBOT, robo_b AS ROBOT) AS INTEGER
'   Return true when robots have moved
DECLARE FUNCTION run_robot_action ( ) AS INTEGER

' Player
DECLARE FUNCTION get_player_action AS PLAYER_ACTION
'   return the action run or no_action when done
DECLARE FUNCTION run_player_action (action AS PLAYER_ACTION ) AS PLAYER_ACTION
DECLARE SUB give_player_score (robots_loop_begin AS INTEGER)
DECLARE FUNCTION is_tile_valid_for_move (test_tile AS TILE) AS INTEGER

' Menu
DECLARE FUNCTION get_menu_action AS PLAYER_ACTION
DECLARE FUNCTION is_mouse_on_button (test_button AS BUTTON) AS INTEGER

' Globals

CONST map_width = 32
CONST map_height = 18

CONST tile_width = 26
CONST tile_height = 26

CONST game_area_width = map_width * tile_width
CONST game_area_height = map_height * tile_height

CONST screen_width = 960
CONST screen_height = 540

CONST margin_x = (screen_width - game_area_width) / 2 , margin_y = (screen_height - game_area_height) /2


CONST robots_per_map = 5
CONST AS INTEGER score_per_robot = 10

DIM SHARED AS INTEGER work_page = 1, show_page = 0
DIM SHARED AS DOUBLE frame_time, extra_time
DIM SHARED AS STRING key_pressed
DIM SHARED AS INTEGER mouse_x, mouse_y, mouse_button
DIM SHARED AS INTEGER mouse_down = FALSE, mouse_click = FALSE
' How fast in tiles player and robots move per frame
' One tile in second. Frame is 0.033 seconds. One tile in 30 frames
' One second is 30 frames
CONST AS SINGLE move_speed = 1.0 / 20.0

DIM SHARED AS SINGLE animation_progress = 0.0

' Player 
CONST AS SINGLE teleport_speed = 1.0 / 20.0
DIM SHARED AS SINGLE teleport_out = TRUE

' Robot
DIM SHARED AS SINGLE robot_animation_progress = 0.0, robot_animation_speed = 1.0/14.0

' Tiles 
DIM SHARED AS SINGLE color_start_number = 0.0, color_skip_number = 0.0, tile_colors = 8.0

DIM SHARED AS INTEGER current_map = 0


' robot sprite sheet, player image, arrows
' mouse cursor
DIM SHARED AS ANY PTR robot_sprite, player_sprite _
, arrow_sprite, cursor_sprite

' How many robots are active in current map
DIM SHARED AS INTEGER active_robots = 0
' How many robots are functional
DIM SHARED AS INTEGER operational_robots = 0
DIM SHARED AS ROBOT robots_array((map_width * map_height) -1)

DIM SHARED AS PLAYER active_player

' Menu
DIM SHARED AS INTEGER menu_margin_top = 2, menu_margin_left = 2, letter_width = 8, letter_height = 16, button_padding = 2
DIM SHARED AS BUTTON teleport, bomb, stand, new_game, exit_game, game_menu, ability_menu

DIM SHARED AS INTEGER color_black = RGB(0,0,0), color_white = RGB(255,255,255) _
, color_metal = RGB(100,100,100), color_red = RGB(255,80,100), color_blue = RGB(80, 100, 255) _
, color_light_grey = RGB(200, 200, 200), color_dark_grey = RGB(80, 80, 80)

' Main module start ------

init_game
'test_functions

SCREENRES screen_width, screen_height, 16, 2, (GFX_WINDOWED OR GFX_NO_SWITCH)
SETMOUSE 0,0,0
SCREENSET work_page, show_page

WIDTH screen_width\letter_width, screen_height\letter_height

load_graphics
run_game
' Main module end --------

' Function implementations

SUB test_functions
    DIM AS TILE c_tile = get_center_tile
    print_tile("Center tile", c_tile)
    
    print_tile("Player", active_player.robo.current_tile)
    
    DIM AS STRING robot_name
    
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        robot_name = "Robot " & robot_index
        print_tile(robot_name, robots_array(robot_index).current_tile)
    NEXT robot_index
    
    DIM AS TILE tile_pos
    FOR tile_y AS INTEGER = 0 TO map_height - 1
        FOR tile_x AS INTEGER = 0 TO map_width - 1
            tile_pos.x = tile_x
            tile_pos.y = tile_y
        print_tile("Tile ", tile_pos)
        NEXT tile_x
    NEXT tile_y
    
   ' FOR random_index AS INTEGER = 0 TO 100
    '    print_tile("Random tile", get_random_tile(max_tile_number))
    'NEXT random_index
    
END SUB

SUB print_tile (name_string AS STRING, tile_coords AS TILE)
   PRINT name_string; " is tile  at "; tile_coords.x ; "," ; tile_coords.y
END SUB

SUB init_game
    ' Load options
    ' Load high scores
    ' Set title
    RANDOMIZE TIMER
    init_map(0)
END SUB

SUB load_graphics
    '
    
    ' Create buttons
    DIM AS STRING ability_string = "ABILITY", teleport_string = "TELEPORT" _
    , bomb_string = "SONIC BOMB", stand_string = "LAST STAND", game_string = "GAME" _
    , new_string = "NEW GAME", quit_string = "QUIT GAME"
    
    ' GAME       ABILITY
    ' .NEW GAME  .TELEPORT 
    ' .QUIT GAME .SONIC BOMB
    '            .LAST STAND
    
    game_menu.create_button (menu_margin_left, menu_margin_top _
    , LEN(game_string) * letter_width, letter_height, game_string)
    
    new_game.create_button (game_menu.position.x, game_menu.position.y + game_menu.size.y _
    , LEN(new_string) * letter_width, letter_height, new_string)
    
    exit_game.create_button (game_menu.position.x, new_game.position.y + new_game.size.y _
    , LEN(quit_string) * letter_width, letter_height, quit_string)
    
    ' 
    ability_menu.create_button (game_menu.position.x + game_menu.size.x + letter_width * 2, menu_margin_top _
    , LEN(ability_string) * letter_width, letter_height, ability_string)
    
    teleport.create_button ( ability_menu.position.x, menu_margin_top + ability_menu.size.y _
    , LEN(teleport_string) * letter_width, letter_height, teleport_string)
    
    bomb.create_button ( ability_menu.position.x, teleport.position.y + teleport.size.y _
    , LEN(bomb_string) * letter_width, letter_height, bomb_string)
    
    stand.create_button (ability_menu.position.x, bomb.position.y + bomb.size.y _
    , LEN(stand_string) * letter_width, letter_height, stand_string)
    
    
END SUB

SUB run_game
    DIM AS MAP_RESULT map_run_result = no_win
    DO 
   
    ' run game loop until
    ' all robots inactive
    ' OR player inactive
    
    map_run_result = game_loop
    
    IF map_run_result = player_win THEN
        current_map += 1
    ELSEIF map_run_result = robots_win THEN
        current_map = 0
        ' High score
        active_player.score = 0
    END IF
    
     ' init map
    init_map(current_map)
    
    LOOP UNTIL map_run_result = game_quit
END SUB

FUNCTION game_loop AS MAP_RESULT
    DIM AS GAME_LOOP_STATE loop_state = wait_input
    DIM AS MAP_RESULT loop_result = no_win
    DIM AS INTEGER robots_loop_begin = 0
    
    DO 
        start_frame_timing
        
        ' listen to mouse
        DIM AS INTEGER mouse_in_x, mouse_in_y
        GETMOUSE mouse_in_x, mouse_in_y, , mouse_button
        IF mouse_button = 1 THEN
            mouse_down = TRUE
        ELSEIF mouse_button = 0 AND mouse_down THEN
            mouse_down = FALSE
            mouse_click = TRUE
            mouse_x = mouse_in_x
            mouse_y = mouse_in_y
        END IF
        
        SCREENLOCK
        SCREENSET work_page, show_page
        CLS
        
        
        
        draw_tiles
        draw_robots_and_player (loop_state)
        
        draw_menu
        ' draw mouse
        draw_mouse (mouse_in_x, mouse_in_y)
        
        
        SELECT CASE loop_state
        CASE wait_input
            
            ' wait until user selects an arrow or ability
            DIM AS PLAYER_ACTION action = get_player_action
            IF action <> no_action THEN
                active_player.action = action
                robots_loop_begin = operational_robots
                
                loop_state = animate_player
            END IF
        CASE animate_player
            active_player.action = run_player_action(active_player.action)
            IF active_player.action = no_action _
            OR active_player.action = last_stand THEN
                calculate_robot_targets ()
                loop_state = animate_robots
            END IF
            ' move player or do action
            ' teleport 
            ' sonic bomb
            ' last stand
        CASE animate_robots
            ' move robots towards player
            DIM AS INTEGER robots_done = run_robot_action()
            IF robots_done THEN
                loop_state = collision_check
            END IF
        CASE collision_check
            
            check_collisions ()
            give_player_score (robots_loop_begin)
            loop_result = get_map_result ()
            color_start_number = (RND * tile_colors)+1
            color_skip_number = (RND * tile_colors)+1
            
            loop_state = wait_input
        END SELECT
        
        work_page = work_page xor 1
        show_page = show_page xor 1
        SCREENUNLOCK
        
        mouse_click = FALSE
        
        ' sleep for extra time
        end_frame_timing
        
        IF loop_result <> no_win THEN
            RETURN loop_result
        END IF
        
    LOOP UNTIL MULTIKEY(SC_Q) OR MULTIKEY(SC_ESCAPE)OR key_pressed = Chr(255, 107)
    ' Clear Inkey buffer
    ' Inkey buffer gets all the button presses 
    WHILE INKEY<> "": WEND
    RETURN game_quit
END FUNCTION

SUB start_frame_timing
   frame_time = TIMER& 
END SUB

SUB end_frame_timing
    ' Sleep for the extra time
    ' & in the end gets double precision.
    ' TIMER returns milliseconds after midnight
    extra_time = TIMER& ' If player plays over midnigth...
    IF extra_time > frame_time THEN
        frame_time = extra_time - frame_time
        IF frame_time < 33 THEN
            extra_time = 33 - frame_time
            SLEEP extra_time,1
        END IF
    ELSE
        SLEEP 33,1
    END IF
END SUB

FUNCTION get_player_action AS PLAYER_ACTION
    IF mouse_click THEN
        ' Is mouse cursor inside a tile next to player?
        ' Which tile?
        ' Is tile valid, not outside grid?
        ' Is tile occupied by a robot?
        ' return move action
        DIM AS TILE move_tile
        FOR tile_x AS INTEGER = -1 TO 1
            FOR tile_y AS INTEGER = -1 TO 1
                ' Skip player
                IF tile_x = 0 AND tile_y = 0 THEN
                    CONTINUE FOR
                END IF
                
                move_tile.x = active_player.robo.current_tile.x + tile_x
                move_tile.y = active_player.robo.current_tile.y + tile_y
                
                DIM AS VECTOR2 mouse_pos
                mouse_pos.x = mouse_x
                mouse_pos.y = mouse_y
                IF is_pixel_inside_tile(mouse_pos, move_tile) _
                AND is_tile_valid_for_move( move_tile) THEN
                    active_player.robo.target_tile = move_tile
                    RETURN move_action
                END IF
            NEXT tile_y
        NEXT tile_x
    END IF 
    
    DIM AS PLAYER_ACTION action_from_menu = get_menu_action ()
    RETURN action_from_menu
END FUNCTION

FUNCTION is_tile_valid_for_move (test_tile AS TILE) AS INTEGER
    IF test_tile.x >= 0 AND test_tile.x < map_width _
    AND test_tile.y >= 0 AND test_tile.y < map_height THEN
        IF is_tile_occupied(test_tile) = FALSE THEN
            RETURN TRUE
        END IF
    END IF
    RETURN FALSE
END FUNCTION

FUNCTION get_menu_action () AS PLAYER_ACTION
    DIM AS PLAYER_ACTION button_action = no_action
    
    IF mouse_click THEN
        IF game_menu.pressed THEN
            IF is_mouse_on_button (new_game) THEN
                button_action = action_new_game
            ELSEIF is_mouse_on_button (exit_game) THEN
                button_action = action_quit_game
            END IF
            game_menu.pressed = FALSE
        ELSEIF is_mouse_on_button (game_menu) THEN
            game_menu.pressed = TRUE
        END IF
        
        IF ability_menu.pressed THEN
            IF is_mouse_on_button (teleport) THEN
                button_action = teleport_action
            ELSEIF is_mouse_on_button (bomb) AND active_player.sonic_bomb > 0 THEN                
                active_player.sonic_bomb =- 1
                button_action = sonic_bomb
            ELSEIF is_mouse_on_button (stand) THEN
                button_action = last_stand
            END IF
            ability_menu.pressed = FALSE
        ELSEIF is_mouse_on_button (ability_menu) THEN
            ability_menu.pressed = TRUE
        END IF
    END IF
        
    RETURN button_action
END FUNCTION

FUNCTION is_mouse_on_button( bt AS BUTTON) AS INTEGER
    IF mouse_x >= bt.position.x AND mouse_x < bt.position.x + bt.size.x _
    AND mouse_y >= bt.position.y AND mouse_y < bt.position.y + bt.size.y THEN
        RETURN TRUE
    ELSE
        RETURN FALSE
    END IF
END FUNCTION

FUNCTION run_player_action (action AS PLAYER_ACTION) AS PLAYER_ACTION
    SELECT CASE action 
    CASE move_action
        animation_progress += move_speed
        IF animation_progress >= 1.0 THEN
            active_player.robo.current_tile = active_player.robo.target_tile
            animation_progress = 0.0
            RETURN no_action
        ELSE
            RETURN move_action
        END IF
    CASE teleport_action
        ' First time
        IF animation_progress = 0.0 THEN
            DO 
                active_player.robo.target_tile = find_free_tile(active_robots-1)
            LOOP UNTIL active_player.robo.target_tile <> active_player.robo.current_tile
            teleport_out = TRUE
            animation_progress += teleport_speed
            RETURN teleport_action
        ELSEIF animation_progress < 0 THEN
            animation_progress = 0.0
            RETURN no_action
        ELSE
            IF teleport_out THEN
                animation_progress += teleport_speed
                IF animation_progress >= 1 THEN
                    active_player.robo.current_tile = active_player.robo.target_tile
                    teleport_out = FALSE
                END IF
            ELSE
                animation_progress -= teleport_speed
            END IF
            RETURN teleport_action
        END IF
    CASE sonic_bomb
        ' disable_robots next to player
        animation_progress += teleport_speed
        IF animation_progress >= 1 THEN
            DIM AS TILE disable_tile
            FOR tile_x AS INTEGER = -1 TO 1
                FOR tile_y AS INTEGER = -1 TO 1
                    ' Skip players tile
                    IF tile_x = 0 AND tile_y = 0 THEN
                        CONTINUE FOR
                    END IF
                
                    disable_tile.x = active_player.robo.current_tile.x + tile_x
                    disable_tile.y = active_player.robo.current_tile.y + tile_y
                    FOR robo_index AS INTEGER = 0 TO active_robots -1
                        IF robots_array(robo_index).current_tile = disable_tile THEN
                            robots_array(robo_index).state = vaporized
                        END IF
                    NEXT robo_index
                NEXT tile_y
            NEXT tile_x
            
            animation_progress = 0.0
            RETURN no_action
        ELSE
            RETURN sonic_bomb
        END IF
    CASE last_stand
        
    END SELECT
    
    RETURN no_action
END FUNCTION

FUNCTION run_robot_action ( ) AS INTEGER
    animation_progress += move_speed
    IF animation_progress >= 1.0 THEN
        FOR robot_index AS INTEGER = 0  TO active_robots -1
            robots_array(robot_index).current_tile = robots_array(robot_index).target_tile
        NEXT robot_index
        animation_progress = 0.0
        RETURN TRUE
    ELSE
        RETURN FALSE
    END IF
END FUNCTION

FUNCTION get_tile_dimensions AS VECTOR2
    DIM AS VECTOR2 tile_pixel_dimensions
    tile_pixel_dimensions.x = INT( (screen_width - margin_x * 2) / map_width)
    tile_pixel_dimensions.y = INT( (screen_height - margin_y * 2) / map_height)
    
    RETURN tile_pixel_dimensions
END FUNCTION

FUNCTION get_tile_pixel_coordinates (tile_coords AS TILE) AS VECTOR2
    DIM AS VECTOR2 tile_pixel_coords
    tile_pixel_coords.x = margin_x + tile_coords.x * tile_width
    tile_pixel_coords.y = margin_y + tile_coords.y * tile_height
    RETURN tile_pixel_coords
END FUNCTION

FUNCTION is_pixel_inside_tile (pixel_pos AS VECTOR2, tile_coords AS TILE) AS INTEGER
    DIM AS VECTOR2 tile_pixels = get_tile_pixel_coordinates( tile_coords )
    IF pixel_pos.x >= tile_pixels.x AND pixel_pos.x < tile_pixels.x + tile_width THEN
        IF pixel_pos.y >= tile_pixels.y AND pixel_pos.y < tile_pixels.y + tile_height THEN
            RETURN TRUE
        END IF
    END IF
    
    RETURN FALSE
END FUNCTION
    
SUB draw_menu
    ' Draw menu strip
    LINE (0,0)-STEP(screen_width, letter_height + button_padding * 2 + menu_margin_top), color_light_grey, BF    
    ' Draw buttons
    draw_button(game_menu, TRUE)
    IF game_menu.pressed THEN
        draw_button(new_game, TRUE)
        draw_button(exit_game, TRUE)
    END IF
    
    draw_button(ability_menu, TRUE)
    IF ability_menu.pressed THEN
        draw_button(teleport, TRUE)
        draw_button(bomb, active_player.sonic_bomb > 0)
        draw_button(stand, TRUE)
    END IF
    
    DRAW STRING (menu_margin_left + screen_width*0.4, menu_margin_top),"LEVEL "& current_map, color_black
    ' LEVEL ## = 8 letters
    DRAW STRING STEP (menu_margin_left + letter_width * 16, 0),"SCORE "& active_player.score, color_black
   
END SUB

SUB draw_button (bt AS BUTTON, enabled AS INTEGER)
    ' background
    LINE (bt.position.x, bt.position.y)-STEP(bt.size.x + button_padding, bt.size.y + button_padding) _
    , color_light_grey,BF
    ' border
    LINE (bt.position.x, bt.position.y)-STEP(bt.size.x + button_padding, bt.size.y + button_padding) _
    , color_dark_grey, B
    ' text
    IF enabled THEN
        DRAW STRING (bt.position.x + button_padding, bt.position.y + button_padding), bt.text, color_black
    ELSE 
        DRAW STRING (bt.position.x + button_padding, bt.position.y + button_padding), bt.text, color_dark_grey
    END IF
END SUB

SUB draw_mouse (x AS INTEGER, y AS INTEGER)
     LINE (x, y)-STEP(5,5),color_white, BF
     LINE STEP(-2, -2)-STEP(5,5),color_white, BF
     LINE STEP(-2, -2)-STEP(5,5),color_white, BF
     LINE STEP(-2, -2)-STEP(5,5),color_white, BF
     
     LINE (x+5, y)-STEP(5,2),color_white, BF
     LINE (x ,y+5)-STEP(2,5),color_white, BF
     
END SUB

SUB draw_tiles
    DIM AS TILE tile_coords
    DIM AS VECTOR2 tile_pixel_pos
    
    ' disco colors
    DIM AS INTEGER colors_array(tile_colors)
    colors_array(0) = RGB(240, 240, 80)
    colors_array(1) = RGB(240, 150, 150)
    colors_array(2) = RGB(150, 240, 150)
    colors_array(3) = RGB(150, 150, 240)
    colors_array(4) = RGB(80, 220, 240)
    colors_array(5) = RGB(240, 80, 240)
    colors_array(6) = RGB(200, 80, 200)
    colors_array(7) = RGB(80, 250, 255)
    
    DIM AS INTEGER tile_color
    
    FOR tile_y AS INTEGER = 0 TO map_height - 1
        FOR tile_x AS INTEGER = 0 TO map_width - 1
            tile_coords.x = tile_x
            tile_coords.y = tile_y
            tile_pixel_pos = get_tile_pixel_coordinates (tile_coords)
             
            tile_color = ((tile_coords.x * color_skip_number)+ (tile_coords.y * color_start_number))MOD tile_colors
            
             LINE ( tile_pixel_pos.x, tile_pixel_pos.y) - _
                STEP(tile_width, tile_height), colors_array(tile_color) ,BF
            
            LINE ( tile_pixel_pos.x, tile_pixel_pos.y) - _
                STEP(tile_width, tile_height), color_black ,B
            
           
        NEXT tile_x
    NEXT tile_y
END SUB

SUB draw_robots_and_player (state AS GAME_LOOP_STATE)
   
    DIM AS VECTOR2 start_pos, end_pos, move_vector
    
    DIM AS INTEGER robot_width = tile_width/5
    robot_animation_progress += robot_animation_speed
    IF robot_animation_progress > 1 AND robot_animation_speed > 0 THEN
        robot_animation_progress = 1.0
        robot_animation_speed *= -1.0
    ELSEIF robot_animation_progress < 0 AND robot_animation_speed < 0 THEN
        robot_animation_progress = 0.0
        robot_animation_speed *= -1.0
    END IF
    
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        start_pos = get_tile_pixel_coordinates (robots_array(robot_index).current_tile)
        IF animation_progress > 0 AND state = animate_robots THEN
            end_pos = get_tile_pixel_coordinates(robots_array(robot_index).target_tile)
            move_vector.x = end_pos.x - start_pos.x
            move_vector.y = end_pos.y - start_pos.y
        
            start_pos.x += animation_progress * move_vector.x
            start_pos.y += animation_progress * move_vector.y
            
            CIRCLE (end_pos.x + tile_width / 2, end_pos.y + tile_height /2), _
    tile_width / 5, color_red
            
        END IF 
    
        ' Operational robot
        IF robots_array(robot_index).state = operational THEN
            
            ' Head
            LINE (start_pos.x + robot_width*2, start_pos.y + robot_width *1) _
                -STEP(robot_width, robot_width), color_metal, BF
            
            LINE (start_pos.x + robot_width*2 + robot_animation_progress * (robot_width*0.6), start_pos.y + robot_width *1.5) _
                -STEP(robot_width*0.5, robot_width*0.5), color_red, BF
            
            ' Body
            LINE (start_pos.x + robot_width*1, start_pos.y + robot_width*2) _
                -STEP ( robot_width * 3, robot_width*3), color_metal, BF
                
            ' Left foot
            'LINE (start_pos.x, start_pos.y + robot_width*4) _
            '    -STEP ( robot_width*1, robot_width*1), color_metal, BF
                
            ' Right foot
            'LINE (start_pos.x + robot_width*4, start_pos.y + robot_width*4) _
             '   -STEP ( robot_width * 1, robot_width*1), color_metal, BF
                
        ELSEIF robots_array(robot_index).state = broken THEN
            ' Pile
            LINE (start_pos.x + robot_width*2, start_pos.y + robot_width*3) _
                -STEP ( robot_width*1, robot_width*1), color_metal, BF
            LINE (start_pos.x + robot_width*1, start_pos.y + robot_width*4) _
                -STEP ( robot_width*3, robot_width*1), color_metal, BF
        END IF
    NEXT robot_index
    
    'Player
    start_pos = get_tile_pixel_coordinates(active_player.robo.current_tile)
    IF animation_progress > 0 AND state = animate_player THEN
        SELECT CASE active_player.action
        CASE move_action
            end_pos = get_tile_pixel_coordinates(active_player.robo.target_tile)
            move_vector.x = end_pos.x - start_pos.x
            move_vector.y = end_pos.y - start_pos.y
        
            start_pos.x += animation_progress * move_vector.x
            start_pos.y += animation_progress * move_vector.y
        
            CIRCLE (end_pos.x + tile_width / 2, end_pos.y + tile_height /2), _
                tile_width / 5
        CASE teleport_action
            CIRCLE (start_pos.x + tile_width /2, start_pos.y + tile_height/2) _
            , animation_progress * screen_width, color_blue
        CASE sonic_bomb
            CIRCLE (start_pos.x + tile_width /2, start_pos.y + tile_height/2) _
            , animation_progress * tile_width * 1.5, color_blue
            CIRCLE (start_pos.x + tile_width /2, start_pos.y + tile_height/2) _
            , animation_progress * tile_width * 1.3, color_blue
            CIRCLE (start_pos.x + tile_width /2, start_pos.y + tile_height/2) _
            , animation_progress * tile_width * 1.0, color_blue
        END SELECT
    ELSEIF state = wait_input THEN
        ' Draw possible moves
        DIM AS VECTOR2 move_position
         DIM AS TILE move_tile
        FOR tile_x AS INTEGER = -1 TO 1
            FOR tile_y AS INTEGER = -1 TO 1
                ' Skip player
                IF tile_x = 0 AND tile_y = 0 THEN
                    CONTINUE FOR
                END IF
                
                move_tile.x = active_player.robo.current_tile.x + tile_x
                move_tile.y = active_player.robo.current_tile.y + tile_y
                IF is_tile_valid_for_move (move_tile) THEN
                    move_position = get_tile_pixel_coordinates(move_tile)
                    CIRCLE (move_position.x + tile_width/2, move_position.y + tile_height/2) _
                        ,tile_width/6, color_blue
                END IF
            NEXT tile_y
        NEXT tile_x
    END IF
    
    ' Head
    LINE (start_pos.x + robot_width*2, start_pos.y + robot_width *0) _
        -STEP(robot_width, robot_width), color_white, BF
    
    ' Body
    LINE (start_pos.x + robot_width*1.5, start_pos.y + robot_width*1) _
        -STEP ( robot_width * 2, robot_width*2), color_blue, BF
        
    ' Left foot
    LINE (start_pos.x + robot_width*1.7, start_pos.y + robot_width*3) _
        -STEP ( robot_width*0.5, robot_width*2), color_metal, BF
        
    ' Right foot
    LINE (start_pos.x + robot_width*2.7, start_pos.y + robot_width*3) _
       -STEP ( robot_width*0.5, robot_width*2), color_metal, BF
    
END SUB

SUB calculate_robot_targets
    DIM AS TILE player_position, robot_position, target_position
    player_position = active_player.robo.current_tile
    
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        IF robots_array(robot_index).state = operational THEN
            robot_position = robots_array(robot_index).current_tile
            target_position = robot_position
            IF player_position.x > robot_position.x THEN
                target_position.x += 1
            ELSEIF player_position.x < robot_position.x THEN
                target_position.x -= 1
            END IF
            
            IF player_position.y > robot_position.y THEN
                target_position.y += 1
            ELSEIF player_position.y < robot_position.y THEN
                target_position.y -= 1
            END IF 
            
            robots_array(robot_index).target_tile = target_position
            
        END IF
    NEXT robot_index
END SUB

FUNCTION get_center_tile AS TILE
    DIM AS TILE center_position
    center_position.x = INT(map_width / 2)
    center_position.y = INT(map_height / 2)
    RETURN center_position
END FUNCTION

SUB check_collisions 
    DIM AS INTEGER operational_before = operational_robots
    
    ' See if operational robots collide with player or other robots
    ' Check also agains broken robots
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        ' If two or more robots move over player, player loses
        IF robots_array(robot_index).state = operational THEN
            IF robot_collision( _
            robots_array(robot_index) _
            , active_player.robo) THEN
                active_player.robo.state = broken
                CONTINUE FOR
            END IF
        
            FOR test_index AS INTEGER = 0 TO active_robots - 1
                IF robot_index <> test_index _
                AND robots_array(test_index).state <> vaporized _
                AND robot_collision( _
                    robots_array(robot_index) _
                    , robots_array(test_index) ) THEN
                        robots_array(robot_index).state = broken
                        robots_array(test_index).state = broken
                        
                        EXIT FOR
                END IF
            NEXT test_index
        END IF
    NEXT robot_index
END SUB

SUB give_player_score (robots_loop_begin AS INTEGER)
    DIM AS INTEGER operational_after = 0
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        IF robots_array(robot_index).state = operational THEN
            operational_after += 1
        END IF
    NEXT robot_index
    
    operational_robots = operational_after
    
    active_player.score += (robots_loop_begin - operational_after) * score_per_robot
END SUB

FUNCTION get_map_result AS MAP_RESULT
    IF operational_robots = 0 THEN
        RETURN player_win
    ELSEIF active_player.robo.state <> operational THEN
        RETURN robots_win
    ELSE 
        RETURN no_win
    END IF
END FUNCTION

SUB init_map(map_number AS INTEGER)
    IF map_number = 0 THEN
        active_robots = robots_per_map
    ELSE
        active_robots = map_number * robots_per_map
    END IF
    
    IF active_robots > UBOUND(robots_array) THEN
        active_robots = UBOUND(robots_array)
    END IF
    
    operational_robots = active_robots


    ' Randomize robot positions and set them operational
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        robots_array(robot_index).current_tile = find_free_tile (robot_index)
        robots_array(robot_index).state = operational
    NEXT robot_index
    
    ' Place player in the middle
    active_player.robo.current_tile = get_center_tile
    active_player.robo.state = operational
    active_player.action = no_action
    active_player.sonic_bomb = 1
    
    ' Check that no robot occupies player's tile
    DIM player_tile AS INTEGER = FALSE
    DO
        player_tile = FALSE
        FOR robot_index AS INTEGER = 0 TO active_robots - 1
            IF (robot_collision( _
                robots_array(robot_index) _
                , active_player.robo)) _
                THEN
                player_tile = TRUE
                robots_array(robot_index).current_tile = find_free_tile (active_robots - 1)
                EXIT FOR
            END IF
        NEXT robot_index
    LOOP UNTIL player_tile = FALSE
    
    color_start_number = INT( (RND * tile_colors)+1)
    color_skip_number = INT( (RND * tile_colors)+1)
END SUB

FUNCTION get_random_tile AS TILE
    DIM AS TILE rnd_tile 
    rnd_tile.x = INT(RND * CDBL(map_width))
    rnd_tile.y = INT(RND * CDBL(map_height))
    RETURN rnd_tile
END FUNCTION

FUNCTION is_tile_occupied (tile_coord AS TILE) AS INTEGER
    FOR test_index AS INTEGER = 0 TO active_robots - 1
        IF robots_array(test_index).state <> vaporized _
        AND robots_array(test_index).current_tile = tile_coord THEN
            RETURN TRUE
        END IF
    NEXT test_index
    
    RETURN FALSE
END FUNCTION

FUNCTION find_free_tile (max_robo_index AS INTEGER) AS TILE
    DIM AS INTEGER same_tile = FALSE 
    DIM AS TILE try_tile
    DO
        same_tile = FALSE
        try_tile = get_random_tile
        FOR test_index AS INTEGER = 0 TO max_robo_index - 1
            IF robots_array(test_index).current_tile = try_tile THEN
                same_tile = TRUE
                EXIT FOR
            END IF
        NEXT test_index
    LOOP UNTIL same_tile = FALSE
    RETURN try_tile
END FUNCTION

FUNCTION robot_collision (robo_a AS ROBOT, robo_b AS ROBOT) AS INTEGER
    IF robo_a.current_tile = robo_b.current_tile THEN
        RETURN TRUE
    ELSE
        RETURN FALSE
    END IF
END FUNCTION