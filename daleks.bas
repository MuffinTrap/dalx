' Daleks clone by MuffinTrap
' Original Daleks game for Macintosh by xxx 

#include "fbgfx.bi"
USING FB


' Type declarations
ENUM MAP_RESULT
    player_win = 1
    robots_win = 2
    no_win = 3
    game_quit = 4
END ENUM

ENUM GAME_LOOP_STATE
    wait_input = 1
    animate_player = 2
    animate_robots = 3
    collision_check = 4
END ENUM

ENUM PLAYER_ACTION
    no_action = 0
    move_action = 1
    teleport = 2
    sonic = 3
    last_stand = 4
    new_game = 5
    quit_game = 6
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

TYPE ROBOT
    current_tile AS TILE
    target_tile AS TILE
    operational AS INTEGER
END TYPE

TYPE PLAYER
    robo AS ROBOT
    sonic_bomb AS INTEGER
    last_stand AS INTEGER
    score AS INTEGER
    action AS PLAYER_ACTION
END TYPE




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
DECLARE SUB draw_tiles
DECLARE SUB draw_robots_and_player

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

' Player
DECLARE FUNCTION get_player_action AS PLAYER_ACTION
'   return the action run or no_action when done
DECLARE FUNCTION run_player_action (action AS PLAYER_ACTION ) AS PLAYER_ACTION 

' Globals

CONST map_width = 11
CONST map_height = 11

CONST margin_x = 40
CONST margin_y = 20

CONST screen_width = 640
CONST screen_height = 480

CONST tile_width = INT( (screen_width - margin_x * 2) / map_width)
CONST tile_height = INT( (screen_height - margin_y * 2) / map_height)

CONST starting_robots = 10
CONST add_robots = 1

DIM SHARED AS INTEGER work_page = 1, show_page = 0
DIM SHARED AS DOUBLE frame_time, extra_time
DIM SHARED AS STRING key_pressed
DIM SHARED AS INTEGER mouse_x, mouse_y, mouse_button
' How fast in tiles player and robots move per frame
' One tile in second. Frame is 0.033 seconds. One tile in 30 frames
' One second is 30 frames
CONST AS SINGLE move_speed = 1.0 / 20.0
DIM SHARED AS SINGLE move_progress = 0.0

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

' Main module start ------

init_game
test_functions

SCREENRES screen_width, screen_height, 16, 2, (GFX_WINDOWED OR GFX_NO_SWITCH)
SETMOUSE 0,0,0
SCREENSET work_page, show_page

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
    ' Nothing here
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
    
    DO 
        start_frame_timing
        
        ' listen to mouse
        GETMOUSE mouse_x, mouse_y, , mouse_button
        
        SCREENLOCK
        SCREENSET work_page, show_page
        CLS
        
        draw_tiles
        draw_robots_and_player
        ' draw player
        
        SELECT CASE loop_state
        CASE wait_input
            ' draw mouse
            LINE (mouse_x, mouse_y)-STEP(15,15), ,BF
            ' draw player arrows
            
            ' wait until user selects an arrow or ability
            DIM AS PLAYER_ACTION action = get_player_action
            IF action <> no_action THEN
                active_player.action = action
                loop_state = animate_player
            END IF
        CASE animate_player
            active_player.action = run_player_action(active_player.action)
            IF active_player.action = no_action THEN
                loop_state = wait_input
            END IF
            ' move player or do action
            ' teleport 
            ' sonic bomb
            ' last stand
        CASE animate_robots
            ' move robots towards player
        CASE collision_check
             calculate_robot_targets
            ' check collisions
            check_collisions
            
            loop_result = get_map_result
        END SELECT
        
        ' draw buttons
        ' draw score
        
        work_page = work_page xor 1
        show_page = show_page xor 1
        SCREENUNLOCK
        
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
    IF mouse_button = 1 THEN
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
                IF is_pixel_inside_tile(mouse_pos, move_tile) THEN
                    IF move_tile.x >= 0 AND move_tile.x < map_width _
                    AND move_tile.y >= 0 AND move_tile.y < map_height THEN
                        IF is_tile_occupied(move_tile) = FALSE THEN
                            active_player.robo.target_tile = move_tile
                            RETURN move_action
                        END IF
                    END IF
                END IF
            NEXT tile_y
        NEXT tile_x
                
    ' Check ability buttons
        ' is_mouse_inside_button
    ' Player clicks ability
    END IF 
    
    RETURN no_action
END FUNCTION

FUNCTION run_player_action (action AS PLAYER_ACTION) AS PLAYER_ACTION
    SELECT CASE action 
    CASE move_action
        move_progress += move_speed
        IF move_progress >= 1.0 THEN
            active_player.robo.current_tile = active_player.robo.target_tile
            move_progress = 0.0
            RETURN no_action
        ELSE
            RETURN move_action
        END IF
    END SELECT
    
    RETURN no_action
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
    
SUB draw_tiles
    DIM AS TILE tile_coords
    DIM AS VECTOR2 tile_pixel_pos
    
    FOR tile_y AS INTEGER = 0 TO map_height - 1
        FOR tile_x AS INTEGER = 0 TO map_width - 1
            tile_coords.x = tile_x
            tile_coords.y = tile_y
            tile_pixel_pos = get_tile_pixel_coordinates (tile_coords)
            LINE ( tile_pixel_pos.x, tile_pixel_pos.y) - _
                STEP(tile_width, tile_height), ,B
        NEXT tile_x
    NEXT tile_y
END SUB

SUB draw_robots_and_player
    DIM AS INTEGER robot_width = 3, robot_height = 3
    DIM AS VECTOR2 tile_position 
    
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        tile_position = get_tile_pixel_coordinates (robots_array(robot_index).current_tile)
        LINE (tile_position.x + robot_width, tile_position.y + robot_height) - _
        STEP ( tile_width - robot_width * 2, tile_height - robot_height * 2), ,BF
    NEXT robot_index
    
    'Player
    
    DIM AS VECTOR2 start_pos, end_pos, move_vector
    start_pos = get_tile_pixel_coordinates(active_player.robo.current_tile)
    IF move_progress > 0 THEN
        end_pos = get_tile_pixel_coordinates(active_player.robo.target_tile)
        move_vector.x = end_pos.x - start_pos.x
        move_vector.y = end_pos.y - start_pos.y
        
        start_pos.x += move_progress * move_vector.x
        start_pos.y += move_progress * move_vector.y
        
        CIRCLE (end_pos.x + tile_width / 2, end_pos.y + tile_height /2), _
    tile_width / 5
        
    END IF
    
    CIRCLE (start_pos.x + tile_width / 2, start_pos.y + tile_height /2), _
    tile_width / 3
    
END SUB

SUB calculate_robot_targets
    DIM AS TILE player_position, robot_position, target_position
    player_position = active_player.robo.current_tile
    
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        IF robots_array(robot_index).operational = TRUE THEN
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
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        FOR test_index AS INTEGER = robot_index + 1 TO active_robots - 1
            IF robot_collision( _
                robots_array(robot_index) _
                , robots_array(test_index) ) THEN
                    robots_array(robot_index).operational = FALSE
                    robots_array(robot_index).operational = FALSE
            END IF
        NEXT test_index
        
        IF robot_collision( _
            robots_array(robot_index) _
            , active_player.robo) THEN
                active_player.robo.operational = FALSE
        END IF
    NEXT robot_index
END SUB

FUNCTION get_map_result AS MAP_RESULT
    IF operational_robots = 0 THEN
        RETURN player_win
    ELSEIF active_player.robo.operational = FALSE THEN
        RETURN robots_win
    ELSE 
        RETURN no_win
    END IF
END FUNCTION

SUB init_map(map_number AS INTEGER)
    IF map_number = 0 THEN
        active_robots = starting_robots
    ELSE
        active_robots = starting_robots + map_number * add_robots
    END IF
    
    IF active_robots > UBOUND(robots_array) THEN
        active_robots = UBOUND(robots_array)
    END IF
    
    operational_robots = active_robots


    ' Randomize robot positions and set them operational
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        robots_array(robot_index).current_tile = find_free_tile (robot_index)
        robots_array(robot_index).operational = TRUE
    NEXT robot_index
    
    ' Place player in the middle
    active_player.robo.current_tile = get_center_tile
    
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
                PRINT "Same tile as player"
                robots_array(robot_index).current_tile = find_free_tile (active_robots - 1)
                EXIT FOR
            END IF
        NEXT robot_index
    LOOP UNTIL player_tile = FALSE
END SUB

FUNCTION get_random_tile AS TILE
    DIM AS TILE rnd_tile 
    rnd_tile.x = INT(RND * CDBL(map_width))
    rnd_tile.y = INT(RND * CDBL(map_height))
    RETURN rnd_tile
END FUNCTION

FUNCTION is_tile_occupied (tile_coord AS TILE) AS INTEGER
    FOR test_index AS INTEGER = 0 TO active_robots - 1
        IF robots_array(test_index).current_tile = tile_coord THEN
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