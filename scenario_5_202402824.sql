 

CREATE TABLE IF NOT EXISTS tools (
    tool_id SERIAL PRIMARY KEY,
    tool_name VARCHAR(150) NOT NULL UNIQUE,
    available_quantity INTEGER NOT NULL CHECK (available_quantity >= 0)
);




CREATE TABLE IF NOT EXISTS tool_loans (
    loan_id SERIAL PRIMARY KEY,
    tool_id INTEGER NOT NULL,
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    loan_status VARCHAR(20) NOT NULL DEFAULT 'BORROWED',
    loan_date DATE DEFAULT CURRENT_DATE,

    CONSTRAINT fk_tool
        FOREIGN KEY (tool_id)
        REFERENCES tools(tool_id),

    CONSTRAINT chk_tool_loan_status
        CHECK (loan_status IN ('BORROWED', 'RETURNED'))
);




INSERT INTO tools (
    tool_name,
    available_quantity
)
VALUES
    ('Hammer', 5),
    ('Screwdriver Set', 2),
    ('Electric Drill', 0)
ON CONFLICT DO NOTHING;



SELECT *
FROM tools
ORDER BY tool_id;




DO $$
DECLARE
    v_tool RECORD;
BEGIN

    FOR v_tool IN
        SELECT tool_id, tool_name, available_quantity
        FROM tools
        ORDER BY tool_id
    LOOP

        IF v_tool.available_quantity = 0 THEN

            RAISE NOTICE
                'Tool: % - UNAVAILABLE',
                v_tool.tool_name;

        ELSIF v_tool.available_quantity <= 2 THEN

            RAISE NOTICE
                'Tool: % - LOW ON STOCK (% available)',
                v_tool.tool_name,
                v_tool.available_quantity;

        ELSE

            RAISE NOTICE
                'Tool: % - READILY AVAILABLE (% available)',
                v_tool.tool_name,
                v_tool.available_quantity;

        END IF;

    END LOOP;

END $$;




DO $$
DECLARE
    reminder_number INTEGER := 1;
BEGIN

    WHILE reminder_number <= 3
    LOOP

        RAISE NOTICE
            'Workshop Safety Reminder %: Wear appropriate PPE.',
            reminder_number;

        reminder_number := reminder_number + 1;

    END LOOP;

END $$;




DO $$
DECLARE
    inspection_number INTEGER;
BEGIN

    FOR inspection_number IN 1..3
    LOOP

        RAISE NOTICE
            'Tool Inspection Number: %',
            inspection_number;

    END LOOP;

END $$;



 

CREATE OR REPLACE PROCEDURE issue_tool(
    p_tool_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available_quantity INTEGER;
BEGIN

    /* Check quantity */
    IF p_quantity <= 0 THEN

        RAISE EXCEPTION
            'Invalid quantity. Number of tools must be greater than zero.';

    END IF;


    /* Check student number */
    IF p_student_number IS NULL
       OR TRIM(p_student_number) = '' THEN

        RAISE EXCEPTION
            'Invalid student number. Student number cannot be blank.';

    END IF;


    /* Get tool availability */
    SELECT available_quantity
    INTO v_available_quantity
    FROM tools
    WHERE tool_id = p_tool_id;


    /* Check tool exists */
    IF NOT FOUND THEN

        RAISE EXCEPTION
            'Tool ID % does not exist.',
            p_tool_id;

    END IF;


    /* Check available stock */
    IF p_quantity > v_available_quantity THEN

        RAISE EXCEPTION
            'Tool issue failed. Requested %, but only % tool(s) are available.',
            p_quantity,
            v_available_quantity;

    END IF;


    /* Reduce available quantity */
    UPDATE tools
    SET available_quantity = available_quantity - p_quantity
    WHERE tool_id = p_tool_id;


    /* Record tool loan */
    INSERT INTO tool_loans (
        tool_id,
        student_number,
        quantity,
        loan_status
    )
    VALUES (
        p_tool_id,
        p_student_number,
        p_quantity,
        'BORROWED'
    );


    RAISE NOTICE
        'SUCCESS: Student % received % tool(s) of tool ID %.',
        p_student_number,
        p_quantity,
        p_tool_id;

END;
$$;




CALL issue_tool(
    1,
    'STUDENT001',
    2
);



  
CALL issue_tool(
    2,
    'STUDENT002',
    1
);




SELECT *
FROM tools
ORDER BY tool_id;

SELECT *
FROM tool_loans
ORDER BY loan_id;



DO $$
BEGIN

    BEGIN

        CALL issue_tool(
            2,
            'STUDENT003',
            10
        );

    EXCEPTION
        WHEN OTHERS THEN

            RAISE NOTICE
                'EXPECTED ERROR: %',
                SQLERRM;

    END;

END $$;



SELECT *
FROM tools
ORDER BY tool_id;

SELECT *
FROM tool_loans
ORDER BY loan_id;



CREATE OR REPLACE PROCEDURE return_tool(
    p_loan_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tool_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN

    /* Find loan */
    SELECT tool_id, quantity, loan_status
    INTO v_tool_id, v_quantity, v_status
    FROM tool_loans
    WHERE loan_id = p_loan_id;


    /* Check loan exists */
    IF NOT FOUND THEN

        RAISE EXCEPTION
            'Tool loan ID % does not exist.',
            p_loan_id;

    END IF;


    /* Prevent double return */
    IF v_status = 'RETURNED' THEN

        RAISE NOTICE
            'Loan ID % has already been returned. Tools will NOT be restored again.',
            p_loan_id;

        RETURN;

    END IF;


    /* Restore tools */
    UPDATE tools
    SET available_quantity = available_quantity + v_quantity
    WHERE tool_id = v_tool_id;


    /* Mark loan returned */
    UPDATE tool_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;


    RAISE NOTICE
        'SUCCESS: Loan ID % returned. % tool(s) restored.',
        p_loan_id,
        v_quantity;

END;
$$;




CALL return_tool(1);



CALL return_tool(1);




SELECT *
FROM tools
ORDER BY tool_id;

SELECT *
FROM tool_loans
ORDER BY loan_id;




DO $$
DECLARE

    tool_cursor CURSOR FOR
        SELECT tool_id, tool_name, available_quantity
        FROM tools
        WHERE available_quantity <= 2
        ORDER BY tool_id;

    v_tool_id INTEGER;
    v_tool_name VARCHAR(150);
    v_available_quantity INTEGER;

BEGIN

    OPEN tool_cursor;


    LOOP

        FETCH tool_cursor
        INTO
            v_tool_id,
            v_tool_name,
            v_available_quantity;


        EXIT WHEN NOT FOUND;


        RAISE NOTICE
            'LOW AVAILABILITY - Tool ID: %, Tool: %, Available: %',
            v_tool_id,
            v_tool_name,
            v_available_quantity;

    END LOOP;


    CLOSE tool_cursor;

END $$;



DO $$
BEGIN

    BEGIN

        CALL issue_tool(
            1,
            'STUDENT004',
            0
        );

    EXCEPTION
        WHEN OTHERS THEN

            RAISE NOTICE
                'EXCEPTION HANDLED: %',
                SQLERRM;

    END;

END $$;



SELECT *
FROM tool_loans
ORDER BY loan_id;




SELECT
    tool_id,
    tool_name,
    available_quantity
FROM tools
ORDER BY tool_id;



SELECT
    loan_id,
    tool_id,
    student_number,
    quantity,
    loan_status,
    loan_date
FROM tool_loans
ORDER BY loan_id;


