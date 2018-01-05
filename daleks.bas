' Daleks clone by MuffinTrap
' Original Daleks game for Macintosh by xxx 

#include "fbgfx.bi"
USING FB


' Type declarations
TYPE ROBOT
    tile AS INTEGER
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
END ENUM


' Function declarations
DECLARE SUB load_graphics
DECLARE SUB init_game
DECLARE SUB init_map (map_number AS INTEGER)
DECLARE FUNCTION get_random_tile(max_tile AS INTEGER) AS INTEGER
DECLARE FUNCTION get_center_tile (max_tile AS INTEGER) AS INTEGER
DECLARE SUB find_free_tile (BYREF robo AS ROBOT, max_tile AS INTEGER)
DECLARE FUNCTION robot_collision(robo_a AS ROBOT, robo_b AS ROBOT) AS INTEGER

DECLARE SUB draw_game
DECLARE SUB draw_robot (robo AS ROBOT)
DECLARE SUB draw_player (robo AS ROBOT)

DECLARE SUB run_game
DECLARE FUNCTION game_loop AS MAP_RESULT
' Globals

CONST map_width = 30
CONST map_height = 20
CONST max_tile_number = map_width * map_height

CONST starting_robots = 10
CONST add_robots = 5

' How fast in pixels player and robots move
CONST move_speed = 32

DIM SHARED AS INTEGER current_map


' robot sprite sheet, player image, arrows
' mouse cursor
DIM SHARED AS ANY PTR robot_sprite, player_sprite _
, arrow_sprite, cursor_sprite

' How many robots are active in current map
DIM SHARED AS INTEGER active_robots = 0
DIM SHARED AS ROBOT robots_array(max_tile_number - 1)

DIM SHARED AS PLAYER active_player

' Main module start ------
init_game
load_graphics
run_game
' Main module end --------

' Function implementations

SUB init_game
    ' Load options
    ' Load high scores
    ' Set title
    RANDOMIZE TIMER
END SUB

SUB load_graphics
    
END SUB

SUB run_game
    ' init map
    ' run game loop until
    ' all robots inactive
    ' OR player inactive
    ' 
    ' Robots inactive
    ' increase map
    ' loop again
    '
    ' Player inactive
    ' check if high score
    ' enter high score
    ' set map to 0
    ' loop again
END SUB

FUNCTION game_loop AS MAP_RESULT
    ' draw robots
    ' draw player
    ' draw animations

    ' draw buttons
    ' draw score
    
    ' listen to mouse
    
    ' move player or do action
        ' teleport 
        ' sonic bomb
        ' last stand
        ' run animation if needed
    ' move robots
    
    ' check collisions
    
    ' check victory conditions
    
    ' sleep for extra time
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

    ' Place player in the middle
    
    current_player.tile = get_center_tile

    ' Randomize robot positions
    DIM AS INTEGER same_tile

    FOR robot_index AS INTEGER = 0 TO active_robots
        find_free_tile (robots_array(robot_index), robot_index)
    NEXT robot_index
    
    ' Check that no robot occupies player's tile
    DIM player_tile AS INTEGER = FALSE
    DO
        player_tile = FALSE
        FOR robot_index AS INTEGER = 0 TO active_robots
            IF (robot_collision( _
                robots_array(robot_index) _
                , active_player.robo)) _
                THEN
                player_tile = TRUE
                find_free_tile (robots_array(robo_index), active_robots)
                GOTO PLAYER_CHECK_END
        NEXT robot_index
        PLAYER_CHECK_END:
    LOOP UNTIL player_tile = FALSE
END SUB

FUNCTION get_random_tile (max_tile AS INTEGER) AS INTEGER
    DIM AS INTEGER rnd_tile = INT(RND * CDBL(max_tile))
    RETURN rnd_tile
END FUNCTION

FUNCTION get_center_tile (max_tile AS INTEGER) AS INTEGER
    RETURN (map_height / 2) * map_width + (map_width / 2)
END FUNCTION

SUB find_free_tile (BYREF robo AS ROBOT, max_robo_index AS INTEGER)
    DIM AS INTEGER same_tile = FALSE
    DO
        robo.tile = get_random_tile(max_tile_number)
        FOR test_index AS INTEGER = 0 TO max_robo_index
            same_tile = robot_collision( _
                robots_array(test_index), _
                robots_array(robot_index))
            IF same_tile THEN
                GOTO SAME_TEST_END
            END IF
        NEXT test_index
        SAME_TEST_END:
    LOOP UNTIL same_tile = FALSE
END TILE

FUNCTION robot_collision (robo_a AS ROBOT, robo_b AS ROBOT) AS INTEGER
    IF robo_a.tile = robo_b.tile THEN
        RETURN TRUE
    ELSE
        RETURN FALSE
    END IF
END FUNCTION