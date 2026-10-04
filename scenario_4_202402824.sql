

CREATE TABLE IF NOT EXISTS medicines (
    medicine_id SERIAL PRIMARY KEY,
    medicine_name VARCHAR(150) NOT NULL UNIQUE,
    stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0)
);




CREATE TABLE IF NOT EXISTS dispensing_records (
    record_id SERIAL PRIMARY KEY,
    medicine_id INTEGER NOT NULL,
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    dispensing_status VARCHAR(20) NOT NULL DEFAULT 'DISPENSED',
    dispensing_date DATE DEFAULT CURRENT_DATE,

    CONSTRAINT fk_medicine
        FOREIGN KEY (medicine_id)
        REFERENCES medicines(medicine_id),

    CONSTRAINT chk_dispensing_status
        CHECK (dispensing_status IN ('DISPENSED', 'REVERSED'))
);




INSERT INTO medicines (
    medicine_name,
    stock_quantity
)
VALUES
    ('Paracetamol', 20),
    ('Amoxicillin', 5),
    ('Ibuprofen', 0)
ON CONFLICT DO NOTHING;




SELECT *
FROM medicines
ORDER BY medicine_id;




DO $$
DECLARE
    v_medicine RECORD;
BEGIN

    FOR v_medicine IN
        SELECT medicine_id, medicine_name, stock_quantity
        FROM medicines
        ORDER BY medicine_id
    LOOP

        IF v_medicine.stock_quantity = 0 THEN

            RAISE NOTICE
                'Medicine: % - OUT OF STOCK',
                v_medicine.medicine_name;

        ELSIF v_medicine.stock_quantity <= 5 THEN

            RAISE NOTICE
                'Medicine: % - LOW ON STOCK (% units)',
                v_medicine.medicine_name,
                v_medicine.stock_quantity;

        ELSE

            RAISE NOTICE
                'Medicine: % - SUFFICIENTLY STOCKED (% units)',
                v_medicine.medicine_name,
                v_medicine.stock_quantity;

        END IF;

    END LOOP;

END $$;



DO $$
DECLARE
    review_day INTEGER := 1;
BEGIN

    WHILE review_day <= 3
    LOOP

        RAISE NOTICE
            'Stock Review Day: %',
            review_day;

        review_day := review_day + 1;

    END LOOP;

END $$;



DO $$
DECLARE
    shelf_inspection INTEGER;
BEGIN

    FOR shelf_inspection IN 1..3
    LOOP

        RAISE NOTICE
            'Shelf Inspection Number: %',
            shelf_inspection;

    END LOOP;

END $$;



CREATE OR REPLACE PROCEDURE dispense_medicine(
    p_medicine_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock_quantity INTEGER;
BEGIN

    /* Check quantity */
    IF p_quantity <= 0 THEN

        RAISE EXCEPTION
            'Invalid dispensing quantity. Quantity must be greater than zero.';

    END IF;


    /* Check student number */
    IF p_student_number IS NULL
       OR TRIM(p_student_number) = '' THEN

        RAISE EXCEPTION
            'Invalid student number. Student number cannot be blank.';

    END IF;


    /* Get stock */
    SELECT stock_quantity
    INTO v_stock_quantity
    FROM medicines
    WHERE medicine_id = p_medicine_id;


    /* Check medicine exists */
    IF NOT FOUND THEN

        RAISE EXCEPTION
            'Medicine ID % does not exist.',
            p_medicine_id;

    END IF;


    /* Check stock */
    IF p_quantity > v_stock_quantity THEN

        RAISE EXCEPTION
            'Dispensing failed. Requested %, but only % units are available.',
            p_quantity,
            v_stock_quantity;

    END IF;


    /* Reduce stock */
    UPDATE medicines
    SET stock_quantity = stock_quantity - p_quantity
    WHERE medicine_id = p_medicine_id;


    /* Record dispensing */
    INSERT INTO dispensing_records (
        medicine_id,
        student_number,
        quantity,
        dispensing_status
    )
    VALUES (
        p_medicine_id,
        p_student_number,
        p_quantity,
        'DISPENSED'
    );


    RAISE NOTICE
        'SUCCESS: Student % received % unit(s) of medicine ID %.',
        p_student_number,
        p_quantity,
        p_medicine_id;

END;
$$;



CALL dispense_medicine(
    1,
    'STUDENT001',
    5
);




CALL dispense_medicine(
    2,
    'STUDENT002',
    2
);




SELECT *
FROM medicines
ORDER BY medicine_id;

SELECT *
FROM dispensing_records
ORDER BY record_id;




DO $$
BEGIN

    BEGIN

        CALL dispense_medicine(
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
FROM medicines
ORDER BY medicine_id;

SELECT *
FROM dispensing_records
ORDER BY record_id;




CREATE OR REPLACE PROCEDURE reverse_dispensing(
    p_record_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_medicine_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN

    /* Find dispensing record */
    SELECT medicine_id, quantity, dispensing_status
    INTO v_medicine_id, v_quantity, v_status
    FROM dispensing_records
    WHERE record_id = p_record_id;


    /* Check record exists */
    IF NOT FOUND THEN

        RAISE EXCEPTION
            'Dispensing record ID % does not exist.',
            p_record_id;

    END IF;


    /* Prevent double reversal */
    IF v_status = 'REVERSED' THEN

        RAISE NOTICE
            'Record ID % has already been reversed. Stock will NOT be restored again.',
            p_record_id;

        RETURN;

    END IF;


    /* Restore stock */
    UPDATE medicines
    SET stock_quantity = stock_quantity + v_quantity
    WHERE medicine_id = v_medicine_id;


    /* Mark record as reversed */
    UPDATE dispensing_records
    SET dispensing_status = 'REVERSED'
    WHERE record_id = p_record_id;


    RAISE NOTICE
        'SUCCESS: Record ID % reversed. % unit(s) restored.',
        p_record_id,
        v_quantity;

END;
$$;



CALL reverse_dispensing(1);




CALL reverse_dispensing(1);




SELECT *
FROM medicines
ORDER BY medicine_id;

SELECT *
FROM dispensing_records
ORDER BY record_id;




DO $$
DECLARE

    medicine_cursor CURSOR FOR
        SELECT medicine_id, medicine_name, stock_quantity
        FROM medicines
        WHERE stock_quantity < 5
        ORDER BY medicine_id;

    v_medicine_id INTEGER;
    v_medicine_name VARCHAR(150);
    v_stock_quantity INTEGER;

BEGIN

    OPEN medicine_cursor;


    LOOP

        FETCH medicine_cursor
        INTO
            v_medicine_id,
            v_medicine_name,
            v_stock_quantity;


        EXIT WHEN NOT FOUND;


        RAISE NOTICE
            'LOW STOCK - ID: %, Medicine: %, Quantity: %',
            v_medicine_id,
            v_medicine_name,
            v_stock_quantity;

    END LOOP;


    CLOSE medicine_cursor;

END $$;



DO $$
BEGIN

    BEGIN

        CALL dispense_medicine(
            1,
            'STUDENT004',
            -5
        );

    EXCEPTION
        WHEN OTHERS THEN

            RAISE NOTICE
                'EXCEPTION HANDLED: %',
                SQLERRM;

    END;

END $$;




SELECT
    medicine_id,
    medicine_name,
    stock_quantity
FROM medicines
ORDER BY medicine_id;




SELECT
    record_id,
    medicine_id,
    student_number,
    quantity,
    dispensing_status,
    dispensing_date
FROM dispensing_records
ORDER BY record_id;


