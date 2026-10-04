

CREATE TABLE IF NOT EXISTS hostel_rooms (
    room_id SERIAL PRIMARY KEY,
    room_number VARCHAR(20) NOT NULL UNIQUE,
    hostel_name VARCHAR(100) NOT NULL,
    available_spaces INTEGER NOT NULL CHECK (available_spaces >= 0)
);




CREATE TABLE IF NOT EXISTS allocations (
    allocation_id SERIAL PRIMARY KEY,
    room_id INTEGER NOT NULL,
    student_number VARCHAR(30) NOT NULL,
    allocation_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    allocation_date DATE DEFAULT CURRENT_DATE,

    CONSTRAINT fk_room
        FOREIGN KEY (room_id)
        REFERENCES hostel_rooms(room_id),

    CONSTRAINT chk_allocation_status
        CHECK (allocation_status IN ('ACTIVE', 'COMPLETED'))
);




INSERT INTO hostel_rooms (
    room_number,
    hostel_name,
    available_spaces
)
VALUES
    ('A101', 'Lundazi Hostel', 3),
    ('A102', 'Lundazi Hostel', 1),
    ('B201', 'Kapiri Hostel', 0)
ON CONFLICT DO NOTHING;



SELECT *
FROM hostel_rooms
ORDER BY room_id;




DO $$
DECLARE
    v_room RECORD;
BEGIN

    FOR v_room IN
        SELECT room_id, room_number, available_spaces
        FROM hostel_rooms
        ORDER BY room_id
    LOOP

        IF v_room.available_spaces = 0 THEN

            RAISE NOTICE
                'Room % - FULL',
                v_room.room_number;

        ELSIF v_room.available_spaces = 1 THEN

            RAISE NOTICE
                'Room % - ONE SPACE LEFT',
                v_room.room_number;

        ELSE

            RAISE NOTICE
                'Room % - SEVERAL SPACES AVAILABLE (% spaces)',
                v_room.room_number,
                v_room.available_spaces;

        END IF;

    END LOOP;

END $$;



DO $$
DECLARE
    inspection_day INTEGER := 1;
BEGIN

    WHILE inspection_day <= 3
    LOOP

        RAISE NOTICE
            'Hostel Inspection Day: %',
            inspection_day;

        inspection_day := inspection_day + 1;

    END LOOP;

END $$;



DO $$
DECLARE
    room_check INTEGER;
BEGIN

    FOR room_check IN 1..3
    LOOP

        RAISE NOTICE
            'Room Check Number: %',
            room_check;

    END LOOP;

END $$;



CREATE OR REPLACE PROCEDURE allocate_room(
    p_room_id INTEGER,
    p_student_number VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available_spaces INTEGER;
BEGIN

    /* Check blank student number */
    IF p_student_number IS NULL
       OR TRIM(p_student_number) = '' THEN

        RAISE EXCEPTION
            'Invalid student number. Student number cannot be blank.';

    END IF;


    /* Find room availability */
    SELECT available_spaces
    INTO v_available_spaces
    FROM hostel_rooms
    WHERE room_id = p_room_id;


    /* Check room exists */
    IF NOT FOUND THEN

        RAISE EXCEPTION
            'Room ID % does not exist.',
            p_room_id;

    END IF;


    /* Check available space */
    IF v_available_spaces <= 0 THEN

        RAISE EXCEPTION
            'Allocation failed. Room ID % is full.',
            p_room_id;

    END IF;


    /* Reduce available space */
    UPDATE hostel_rooms
    SET available_spaces = available_spaces - 1
    WHERE room_id = p_room_id;


    /* Record allocation */
    INSERT INTO allocations (
        room_id,
        student_number,
        allocation_status
    )
    VALUES (
        p_room_id,
        p_student_number,
        'ACTIVE'
    );


    RAISE NOTICE
        'SUCCESS: Student % allocated to room ID %.',
        p_student_number,
        p_room_id;

END;
$$;



CALL allocate_room(
    1,
    'STUDENT001'
);




CALL allocate_room(
    2,
    'STUDENT002'
);



SELECT *
FROM hostel_rooms
ORDER BY room_id;

SELECT *
FROM allocations
ORDER BY allocation_id;




DO $$
BEGIN

    BEGIN

        CALL allocate_room(
            3,
            'STUDENT003'
        );

    EXCEPTION
        WHEN OTHERS THEN

            RAISE NOTICE
                'EXPECTED ERROR: %',
                SQLERRM;

    END;

END $$;




SELECT *
FROM hostel_rooms
ORDER BY room_id;

SELECT *
FROM allocations
ORDER BY allocation_id;



CREATE OR REPLACE PROCEDURE check_out(
    p_allocation_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id INTEGER;
    v_status VARCHAR(20);
BEGIN

    /* Find allocation */
    SELECT room_id, allocation_status
    INTO v_room_id, v_status
    FROM allocations
    WHERE allocation_id = p_allocation_id;


    /* Check allocation exists */
    IF NOT FOUND THEN

        RAISE EXCEPTION
            'Allocation ID % does not exist.',
            p_allocation_id;

    END IF;


    /* Check whether already completed */
    IF v_status = 'COMPLETED' THEN

        RAISE NOTICE
            'Allocation ID % has already been checked out. Space will NOT be released again.',
            p_allocation_id;

        RETURN;

    END IF;


    /* Restore one bed space */
    UPDATE hostel_rooms
    SET available_spaces = available_spaces + 1
    WHERE room_id = v_room_id;


    /* Mark allocation completed */
    UPDATE allocations
    SET allocation_status = 'COMPLETED'
    WHERE allocation_id = p_allocation_id;


    RAISE NOTICE
        'SUCCESS: Allocation ID % checked out. One bed space released.',
        p_allocation_id;

END;
$$;




CALL check_out(1);



CALL check_out(1);



SELECT *
FROM hostel_rooms
ORDER BY room_id;

SELECT *
FROM allocations
ORDER BY allocation_id;



DO $$
DECLARE

    room_cursor CURSOR FOR
        SELECT room_id, room_number, hostel_name, available_spaces
        FROM hostel_rooms
        WHERE available_spaces <= 1
        ORDER BY room_id;

    v_room_id INTEGER;
    v_room_number VARCHAR(20);
    v_hostel_name VARCHAR(100);
    v_available_spaces INTEGER;

BEGIN

    OPEN room_cursor;


    LOOP

        FETCH room_cursor
        INTO
            v_room_id,
            v_room_number,
            v_hostel_name,
            v_available_spaces;


        EXIT WHEN NOT FOUND;


        RAISE NOTICE
            'ROOM ID: %, Room: %, Hostel: %, Available Spaces: %',
            v_room_id,
            v_room_number,
            v_hostel_name,
            v_available_spaces;

    END LOOP;


    CLOSE room_cursor;

END $$;



DO $$
BEGIN

    BEGIN

        CALL allocate_room(
            1,
            ''
        );

    EXCEPTION
        WHEN OTHERS THEN

            RAISE NOTICE
                'EXCEPTION HANDLED: %',
                SQLERRM;

    END;

END $$;




SELECT
    room_id,
    room_number,
    hostel_name,
    available_spaces
FROM hostel_rooms
ORDER BY room_id;




SELECT
    allocation_id,
    room_id,
    student_number,
    allocation_status,
    allocation_date
FROM allocations
ORDER BY allocation_id;


