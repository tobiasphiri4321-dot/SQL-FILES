

CREATE TABLE IF NOT EXISTS books (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    author VARCHAR(150) NOT NULL,
    available_copies INTEGER NOT NULL CHECK (available_copies >= 0)
);

 

CREATE TABLE IF NOT EXISTS book_loans (
    loan_id SERIAL PRIMARY KEY,
    book_id INTEGER NOT NULL,
    student_number VARCHAR(30) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    loan_status VARCHAR(20) NOT NULL DEFAULT 'BORROWED',
    loan_date DATE DEFAULT CURRENT_DATE,

    CONSTRAINT fk_book
        FOREIGN KEY (book_id)
        REFERENCES books(book_id),

    CONSTRAINT chk_loan_status
        CHECK (loan_status IN ('BORROWED', 'RETURNED'))
);




INSERT INTO books (title, author, available_copies)
VALUES
    ('Database Systems', 'Raghu Ramakrishnan', 5),
    ('Operating System Concepts', 'Abraham Silberschatz', 2),
    ('Computer Networks', 'Andrew S. Tanenbaum', 0)
ON CONFLICT DO NOTHING;



SELECT *
FROM books
ORDER BY book_id;




DO $$
DECLARE
    v_book RECORD;
BEGIN

    FOR v_book IN
        SELECT book_id, title, available_copies
        FROM books
        ORDER BY book_id
    LOOP

        IF v_book.available_copies = 0 THEN

            RAISE NOTICE
                'Book: % - UNAVAILABLE (0 copies)',
                v_book.title;

        ELSIF v_book.available_copies <= 2 THEN

            RAISE NOTICE
                'Book: % - LOW ON COPIES (% copies)',
                v_book.title,
                v_book.available_copies;

        ELSE

            RAISE NOTICE
                'Book: % - SUFFICIENTLY STOCKED (% copies)',
                v_book.title,
                v_book.available_copies;

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
            'Overdue Reminder Number: %',
            reminder_number;

        reminder_number := reminder_number + 1;

    END LOOP;

END $$;




DO $$
DECLARE
    shelf_number INTEGER;
BEGIN

    FOR shelf_number IN 1..3
    LOOP

        RAISE NOTICE
            'Library Shelf Number: %',
            shelf_number;

    END LOOP;

END $$;



CREATE OR REPLACE PROCEDURE borrow_book(
    p_book_id INTEGER,
    p_student_number VARCHAR,
    p_quantity INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available_copies INTEGER;
BEGIN

    /* Check for invalid quantity */
    IF p_quantity <= 0 THEN

        RAISE EXCEPTION
            'Invalid quantity. A student must borrow at least 1 copy.';

    END IF;


    /* Check for blank student number */
    IF p_student_number IS NULL
       OR TRIM(p_student_number) = '' THEN

        RAISE EXCEPTION
            'Invalid student number. Student number cannot be blank.';

    END IF;


    /* Get the current number of available copies */
    SELECT available_copies
    INTO v_available_copies
    FROM books
    WHERE book_id = p_book_id;


    /* Check whether book exists */
    IF NOT FOUND THEN

        RAISE EXCEPTION
            'Book with ID % does not exist.',
            p_book_id;

    END IF;


    /* Check whether enough copies are available */
    IF p_quantity > v_available_copies THEN

        RAISE EXCEPTION
            'Borrowing failed. Requested %, but only % copies are available.',
            p_quantity,
            v_available_copies;

    END IF;


    /* Reduce available copies */
    UPDATE books
    SET available_copies = available_copies - p_quantity
    WHERE book_id = p_book_id;


    /* Record the loan */
    INSERT INTO book_loans (
        book_id,
        student_number,
        quantity,
        loan_status
    )
    VALUES (
        p_book_id,
        p_student_number,
        p_quantity,
        'BORROWED'
    );


    RAISE NOTICE
        'SUCCESS: Student % borrowed % copy/copies of book ID %.',
        p_student_number,
        p_quantity,
        p_book_id;

END;
$$;

 

CALL borrow_book(
    1,
    'STUDENT001',
    2
);




CALL borrow_book(
    2,
    'STUDENT002',
    1
);




SELECT *
FROM books
ORDER BY book_id;

SELECT *
FROM book_loans
ORDER BY loan_id;




DO $$
BEGIN

    BEGIN

        CALL borrow_book(
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
FROM books
ORDER BY book_id;

SELECT *
FROM book_loans
ORDER BY loan_id;



   

CREATE OR REPLACE PROCEDURE return_book(
    p_loan_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_book_id INTEGER;
    v_quantity INTEGER;
    v_status VARCHAR(20);
BEGIN

    /* Find the loan */
    SELECT book_id, quantity, loan_status
    INTO v_book_id, v_quantity, v_status
    FROM book_loans
    WHERE loan_id = p_loan_id;


    /* Check whether the loan exists */
    IF NOT FOUND THEN

        RAISE EXCEPTION
            'Loan ID % does not exist.',
            p_loan_id;

    END IF;


    /* Check whether it has already been returned */
    IF v_status = 'RETURNED' THEN

        RAISE NOTICE
            'Loan ID % has already been returned. Stock will NOT be restored again.',
            p_loan_id;

        RETURN;

    END IF;


    /* Restore the copies */
    UPDATE books
    SET available_copies = available_copies + v_quantity
    WHERE book_id = v_book_id;


    /* Mark loan as returned */
    UPDATE book_loans
    SET loan_status = 'RETURNED'
    WHERE loan_id = p_loan_id;


    RAISE NOTICE
        'SUCCESS: Loan ID % returned. % copy/copies restored.',
        p_loan_id,
        v_quantity;

END;
$$;




CALL return_book(1);




CALL return_book(1);



SELECT *
FROM books
ORDER BY book_id;

SELECT *
FROM book_loans
ORDER BY loan_id;



  
DO $$
DECLARE

    book_cursor CURSOR FOR
        SELECT book_id, title, available_copies
        FROM books
        WHERE available_copies <= 2
        ORDER BY book_id;

    v_book_id INTEGER;
    v_title VARCHAR(150);
    v_available_copies INTEGER;

BEGIN

    OPEN book_cursor;


    LOOP

        FETCH book_cursor
        INTO v_book_id, v_title, v_available_copies;


        EXIT WHEN NOT FOUND;


        RAISE NOTICE
            'LOW STOCK BOOK - ID: %, Title: %, Available Copies: %',
            v_book_id,
            v_title,
            v_available_copies;

    END LOOP;


    CLOSE book_cursor;

END $$;




DO $$
BEGIN

    BEGIN

        CALL borrow_book(
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
FROM book_loans
ORDER BY loan_id;




SELECT
    book_id,
    title,
    author,
    available_copies
FROM books
ORDER BY book_id;




SELECT
    loan_id,
    book_id,
    student_number,
    quantity,
    loan_status,
    loan_date
FROM book_loans
ORDER BY loan_id;



