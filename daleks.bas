' Daleks clone by MuffinTrap
' Original Daleks game for Macintosh by xxx 

#include "fbgfx.bi"
USING FB


' Type declarations
TYPE POSITION
    x AS INTEGER
    y AS INTEGER
    DECLARE OPERATOR LET (BYREF rhs AS POSITION)
END TYPE

OPERATOR POSITION.LET (BYREF rhs AS POSITION)
    x = rhs.x
    y = rhs.y
END OPERATOR

TYPE ROBOT
    tile AS INTEGER
    target_tile AS INTEGER
    operational AS INTEGER
END TYPE

TYPE PLAYER
    robo AS ROBOT
    sonic_bomb AS INTEGER
    last_stand AS INTEGER
    score AS INTEGER
END TYPE

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


' Function declarations
DECLARE SUB test_functions
DECLARE SUB load_graphics
DECLARE SUB init_game
DECLARE SUB init_map (map_number AS INTEGER)

DECLARE SUB find_free_tile (BYREF robo AS ROBOT, max_tile AS INTEGER)
DECLARE FUNCTION robot_collision (robo_a AS ROBOT, robo_b AS ROBOT) AS INTEGER

DECLARE SUB draw_game
DECLARE SUB draw_robot (robo AS ROBOT)
DECLARE SUB draw_player (robo AS ROBOT)

DECLARE SUB run_game
DECLARE FUNCTION game_loop AS MAP_RESULT

DECLARE SUB start_frame_timing
DECLARE SUB end_frame_timing

DECLARE SUB draw_tiles
DECLARE SUB draw_robots_and_player

DECLARE FUNCTION get_map_result AS MAP_RESULT
DECLARE SUB check_collisions
DECLARE SUB move_robots
DECLARE SUB calculate_robot_targets

DECLARE FUNCTION get_random_tile (max_tile AS INTEGER) AS INTEGER
DECLARE FUNCTION get_center_tile AS INTEGER
DECLARE FUNCTION tile_to_position (tile AS INTEGER) AS POSITION
DECLARE FUNCTION position_to_tile (tile_position AS POSITION) AS INTEGER

DECLARE FUNCTION get_tile_dimensions AS POSITION
DECLARE FUNCTION get_tile_pixel_coordinates (tile AS POSITION) AS POSITION

DECLARE SUB print_tile (name_string AS STRING, tile AS INTEGER)

' Globals

CONST map_width = 20
CONST map_height = 20
CONST max_tile_number = (map_width * map_height) - 1

CONST margin_x = 40
CONST margin_y = 20

CONST screen_width = 640
CONST screen_height = 480

CONST starting_robots = 10
CONST add_robots = 1

DIM SHARED AS INTEGER work_page = 1, show_page = 0
DIM SHARED AS DOUBLE frame_time, extra_time
DIM SHARED AS STRING key_pressed
DIM SHARED AS INTEGER mouse_x, mouse_y, mouse_button
' How fast in pixels player and robots move
CONST move_speed = 32

DIM SHARED AS INTEGER current_map = 0


' robot sprite sheet, player image, arrows
' mouse cursor
DIM SHARED AS ANY PTR robot_sprite, player_sprite _
, arrow_sprite, cursor_sprite

' How many robots are active in current map
DIM SHARED AS INTEGER active_robots = 0
' How many robots are functional
DIM SHARED AS INTEGER operational_robots = 0
DIM SHARED AS ROBOT robots_array(max_tile_number)

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
    DIM AS INTEGER c_tile = get_center_tile
    print_tile("Center tile", c_tile)
    
    print_tile("Player", active_player.robo.tile)
    
    DIM AS STRING robot_name
    
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        robot_name = "Robot " & robot_index
        print_tile(robot_name, robots_array(robot_index).tile)
    NEXT robot_index
    
    FOR tile_index AS INTEGER = 0 TO max_tile_number
        print_tile("Tile " & tile_index, tile_index)
    NEXT tile_index
    
    DIM AS POSITION tile_pos
    FOR tile_y AS INTEGER = 0 TO map_height - 1
        FOR tile_x AS INTEGER = 0 TO map_width - 1
            tile_pos.x = tile_x
            tile_pos.y = tile_y
        print_tile("Tile " & tile_x & "," & tile_y, position_to_tile(tile_pos))
        NEXT tile_x
    NEXT tile_y
    
   ' FOR random_index AS INTEGER = 0 TO 100
    '    print_tile("Random tile", get_random_tile(max_tile_number))
    'NEXT random_index
    
END SUB

SUB print_tile (name_string AS STRING, tile AS INTEGER)
    DIM AS POSITION tile_coords
    tile_coords = tile_to_position (tile)
     PRINT name_string; " is tile ";tile ; " at "; tile_coords.x ; "," ; tile_coords.y
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
        CASE animate_player
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

FUNCTION get_tile_dimensions AS POSITION
    DIM AS POSITION tile_pixel_dimensions
    tile_pixel_dimensions.x = INT( (screen_width - margin_x * 2) / map_width)
    tile_pixel_dimensions.y = INT( (screen_height - margin_y * 2) / map_height)
    
    RETURN tile_pixel_dimensions
END FUNCTION

FUNCTION get_tile_pixel_coordinates (tile AS POSITION) AS POSITION
    DIM AS POSITION tile_size = get_tile_dimensions
    DIM AS POSITION tile_pixel_coords
    tile_pixel_coords.x = margin_x + tile.x * tile_size.x
    tile_pixel_coords.y = margin_y + tile.y * tile_size.y
    RETURN tile_pixel_coords
END FUNCTION
    
SUB draw_tiles
    DIM AS POSITION tile_size = get_tile_dimensions
    DIM AS POSITION tile_position 
    
    FOR tile_y AS INTEGER = 0 TO map_height - 1
        FOR tile_x AS INTEGER = 0 TO map_width - 1
            tile_position.x = tile_x
            tile_position.y = tile_y
            tile_position = get_tile_pixel_coordinates (tile_position)
            LINE ( tile_position.x, tile_position.y) - _
                STEP(tile_size.x, tile_size.y), ,B
        NEXT tile_x
    NEXT tile_y
END SUB

SUB draw_robots_and_player
    DIM AS POSITION tile_size = get_tile_dimensions
    DIM AS INTEGER robot_width = 3, robot_height = 3
    DIM AS POSITION tile_position 
    
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        tile_position = tile_to_position (robots_array(robot_index).tile)
        tile_position = get_tile_pixel_coordinates (tile_position)
        LINE (tile_position.x + robot_width, tile_position.y + robot_height) - _
        STEP ( tile_size.x - robot_width * 2, tile_size.y - robot_height * 2), ,BF
    NEXT robot_index
    
    'Player
    tile_position = tile_to_position (active_player.robo.tile)
    tile_position = get_tile_pixel_coordinates(tile_position)
    CIRCLE (tile_position.x + tile_size.x / 2, tile_position.y + tile_size.y /2), _
    tile_size.x / 3
    
END SUB

SUB calculate_robot_targets
    DIM AS POSITION player_position, robot_position, target_position
    player_position = tile_to_position (active_player.robo.tile)
    
    FOR robot_index AS INTEGER = 0 TO active_robots - 1
        IF robots_array(robot_index).operational = TRUE THEN
            robot_position = tile_to_position (robots_array(robot_index).tile)
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
            
            robots_array(robot_index).target_tile = position_to_tile(target_position)
            
        END IF
    NEXT robot_index
END SUB

FUNCTION get_center_tile AS INTEGER
    DIM AS POSITION center_position
    center_position.x = INT(map_width / 2)
    center_position.y = INT(map_height / 2)
    RETURN position_to_tile (center_position)
END FUNCTION

FUNCTION tile_to_position (tile AS INTEGER) AS POSITION
    DIM AS POSITION result_position
    result_position.y = INT(tile / map_width)
    result_position.x = tile MOD map_width
    
    RETURN result_position
END FUNCTION

FUNCTION position_to_tile (tile_position AS POSITION) AS INTEGER
    DIM AS INTEGER result_tile
    result_tile += tile_position.y * (map_width)
    result_tile += tile_position.x
    
    RETURN result_tile
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
        find_free_tile (robots_array(robot_index), robot_index)
        robots_array(robot_index).operational = TRUE
    NEXT robot_index
    
    ' Place player in the middle
    active_player.robo.tile = get_center_tile
    
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
                find_free_tile (robots_array(robot_index), active_robots)
                EXIT FOR
            END IF
        NEXT robot_index
    LOOP UNTIL player_tile = FALSE
END SUB

FUNCTION get_random_tile (max_tile AS INTEGER) AS INTEGER
    DIM AS INTEGER rnd_tile = INT(RND * CDBL(max_tile + 1))
    RETURN rnd_tile
END FUNCTION



SUB find_free_tile (BYREF robo AS ROBOT, max_robo_index AS INTEGER)
    DIM AS INTEGER same_tile = FALSE, try_tile = 0
    DO
        same_tile = FALSE
        try_tile = get_random_tile(max_tile_number)
        FOR test_index AS INTEGER = 0 TO max_robo_index - 1
            IF robots_array(test_index).tile = try_tile THEN
                same_tile = TRUE
                EXIT FOR
            END IF
        NEXT test_index
    LOOP UNTIL same_tile = FALSE
    robo.tile = try_tile
END SUB

FUNCTION robot_collision (robo_a AS ROBOT, robo_b AS ROBOT) AS INTEGER
    IF robo_a.tile = robo_b.tile THEN
        RETURN TRUE
    ELSE
        RETURN FALSE
    END IF
END FUNCTION