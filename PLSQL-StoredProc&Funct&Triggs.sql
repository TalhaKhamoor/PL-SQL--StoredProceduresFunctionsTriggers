-- Just some data entered to check step 3
update account
set account_balance = 100
where account_no = 4006;

update account
set account_balance = 500
where account_no = 3073;


-- 1
-- creating functions and declaring return value
CREATE OR REPLACE FUNCTION func_permissions_okay
Return VARCHAR2 IS
    -- variables
    v_status    PAYROLL_LOAD.status%TYPE;
    v_user      VARCHAR2(15);
    v_privilege VARCHAR2(15);
    -- constants
    k_fileName  VARCHAR2(8) := 'UTL_FILE';
    k_execute   VARCHAR2(7) := 'EXECUTE';
    k_yes       VARCHAR2(1) := 'Y';
    k_no        VARCHAR2(1) := 'N';
-- begining
BEGIN
        -- selecting current user into variable
        SELECT user
        into v_user
        FROM dual;
        -- selecting privilege of user into variable 
        SELECT privilege
        INTO v_privilege
        FROM user_tab_privs
        WHERE table_name = k_fileName AND grantee= v_user;
        -- if statement to see what privilege is set to
        IF (v_privilege = k_execute) THEN
            -- sets variable to yes to allow further functions
            v_status := k_yes;
        ELSE
            -- sets variable to no to not allow further functions
            v_status := k_no;
        END IF;
        -- returns the variabel status
        Return v_status;
-- end of block
END;
/

-- 2 
-- creating trigger for every insert into payroll_load ... before
CREATE OR REPLACE TRIGGER new_payroll_entry_bir
BEFORE
INSERT
ON PAYROLL_LOAD
FOR EACH ROW
-- begin
BEGIN
    -- insert statement to insert credited value
    -- we use :NEW to grab data from trigger
    INSERT INTO NEW_TRANSACTIONS
        (Transaction_no, Transaction_date, Description, Account_no, Transaction_type, Transaction_amount)
    VALUES
        (wkis_seq.NEXTVAL, :NEW.Payroll_date, 'Whatever description I want', 2050, 'C', :NEW.amount);
    -- insert statement to insert debited value
    INSERT INTO NEW_TRANSACTIONS
        (Transaction_no, Transaction_date, Description, Account_no, Transaction_type, Transaction_amount)
    VALUES
        (wkis_seq.CURRVAL, :NEW.Payroll_date, 'Whatever description I want', 1150, 'D', :NEW.amount);    
    
    -- setting variable to g when inserting
    :NEW.status := 'G';
EXCEPTION
    WHEN OTHERS THEN
        -- setting variable to B when exception caught
        :NEW.status := 'B';
-- end of block
END;
/

-- 3 
-- procedure to insert tranasctions that would balance out accounts
CREATE OR REPLACE PROCEDURE proc_month_end
IS
    -- creating cursor of account table
    CURSOR c_accounts IS
        SELECT *
        FROM account;
        
    -- variables
    v_account_balance           NUMBER;
    v_account_type              account.account_type_code%TYPE;
    v_account_number    account.account_no%TYPE;
    -- constants
    k_revenue_code              VARCHAR2(2) := 'RE';
    k_expense_code              VARCHAR2(2) := 'EX';
    k_description               VARCHAR2(50) := 'Month end process balancing';
    k_credit                    VARCHAR2(1) := 'C';
    k_debit                     VARCHAR2(1) := 'D';
    k_owner_account_number      NUMBER := 5555;
    
-- begining of block
BEGIN
    -- cursor for loop to loop through rec in account
    for r_account IN c_accounts LOOP
        -- assigning variables from rec
        v_account_balance := r_account.account_balance;
        v_account_type := r_account.account_type_code;
        v_account_number := r_account.account_no;
        -- if statement to see if balance is over 
        if v_account_balance > 0 THEN
            -- if statement to see what type account is
            if v_account_type = k_expense_code THEN
                -- if expense then it adds following insertions debit and credit
                INSERT INTO NEW_TRANSACTIONS
                    (Transaction_no, Transaction_date, Description, Account_no, Transaction_type, Transaction_amount)
                VALUES
                    (wkis_seq.NEXTVAL, TRUNC(SYSDATE), k_description, v_account_number, k_credit,  v_account_balance);
                    
                 INSERT INTO NEW_TRANSACTIONS
                    (Transaction_no, Transaction_date, Description, Account_no, Transaction_type, Transaction_amount)
                VALUES
                    (wkis_seq.CURRVAL, TRUNC(SYSDATE), k_description, k_owner_account_number, k_debit,  v_account_balance);
            --  else if revenue it does the following insertions 
            else
            
                INSERT INTO NEW_TRANSACTIONS
                    (Transaction_no, Transaction_date, Description, Account_no, Transaction_type, Transaction_amount)
                VALUES
                    (wkis_seq.NEXTVAL, TRUNC(SYSDATE), k_description, v_account_number, k_debit,  v_account_balance);
                    
                    INSERT INTO NEW_TRANSACTIONS
                    (Transaction_no, Transaction_date, Description, Account_no, Transaction_type, Transaction_amount)
                VALUES
                    (wkis_seq.CURRVAL, TRUNC(SYSDATE), k_description, k_owner_account_number, k_credit,  v_account_balance); 
            -- end of if statement
            end if;
        -- end of if statement
        END IF;
    -- end of loop
    END LOOP;
-- end of block
END;
/
    
-- 4
-- procedure to create a new export file
-- takes in two parameters from jar file
CREATE OR REPLACE PROCEDURE proc_export_csv
(p_directory_alias VARCHAR2, p_file_name VARCHAR2)
IS
-- creating file
F1 UTL_FILE.FILE_TYPE;
-- creating cursor of new transactions tables
CURSOR c_new_transactions IS
        SELECT *
        FROM new_transactions;
-- variables
v_transaction_no        new_transactions.transaction_no%TYPE;
v_transaction_date      new_transactions.transaction_date%TYPE;
v_description           new_transactions.description%TYPE;
v_account_no            new_transactions.account_no%TYPE;
v_transaction_type      new_transactions.transaction_type%TYPE;
v_transaction_amount    new_transactions.transaction_amount%TYPE;
v_input_line            varchar2(400);
-- being of block
BEGIN
-- opening file using params and giving permission of write
F1 := UTL_FILE.FOPEN(p_directory_alias, p_file_name, 'W');
--  cursor for loop to loop through record in new transactions
FOR r_new_transaction IN c_new_transactions LOOP
    -- writing record data into file 
    -- each data delimited by comma
    UTL_FILE.PUT(F1, r_new_transaction.transaction_no);
    UTL_FILE.PUT(F1, ',');
    UTL_FILE.PUT(F1, r_new_transaction.transaction_date);
    UTL_FILE.PUT(F1, ',');
    UTL_FILE.PUT(F1, r_new_transaction.description);
    UTL_FILE.PUT(F1, ',');
    UTL_FILE.PUT(F1, r_new_transaction.account_no);
    UTL_FILE.PUT(F1, ',');
    UTL_FILE.PUT(F1, r_new_transaction.transaction_type);
    UTL_FILE.PUT(F1, ',');
    -- new line
    UTL_FILE.PUT_LINE(F1, r_new_transaction.transaction_amount);
-- end of loop
END LOOP;
-- closing file
UTL_FILE.FCLOSE(F1);
-- end of block
END;
/
    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
