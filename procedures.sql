
CREATE PROCEDURE dbo.send_mail( @e_mail_body varchar(1024), @e_mail_subject varchar(1024))
AS
INSERT INTO logs(msg, proc_name, step_name) 
	VALUES (@e_mail_body,'Data transfer SSIS' , 'mail')

DECLARE @my_cursor CURSOR;
DECLARE @admin_email nvarchar(100);

SET @my_cursor = CURSOR FOR
	SELECT e_mail FROM dbo.sys_usr WHERE admin = 1
OPEN @my_cursor
-- loop to send mails to every admin in database
FETCH NEXT FROM @my_cursor INTO @admin_email
WHILE @@FETCH_STATUS = 0
BEGIN
	EXEC msdb.dbo.sp_send_dbmail
	@profile_name='PW_DB_PROFILE', -- do zmiany
	@recipients = @admin_email,
	@subject = @e_mail_subject,
	@body = @e_mail_body
FETCH NEXT FROM @my_cursor INTO @admin_email
END

CLOSE @my_cursor
DEALLOCATE @my_cursor
GO

-----------------------------------------------------------------------------------------

CREATE PROCEDURE dbo.report_to_admins( @err_number int )
AS
DECLARE @err_text varchar(1024)
DECLARE @err_subject varchar(1024)

IF ( @err_number = 1 ) -- wrong file path
BEGIN

	SET @err_text = 'Last 10 attempts failed .'

	SET @err_subject = 'Fail loading file.'
END

IF ( @err_number = 0 ) -- all correct
	BEGIN

	SET @err_text = 'Import from file to database succeed.'
	SET @err_subject = 'File import succeed.'
	END
ELSE
	BEGIN
	SET @err_text = 'During the time of import file to database error was encountered '
	SET @err_subject = 'Error in File import'
	END

EXEC send_mail @e_mail_body = @err_text, @e_mail_subject = @err_subject
GO

------------------------------------------------------------------------------------------

CREATE PROCEDURE dbo.add_fail_file_load( @the_file_name nvarchar(100) )
AS

INSERT INTO file_name_errors( the_file_name ) VALUES ( @the_file_name )
-- add wrong file logs
INSERT INTO logs( msg, proc_name, step_name) 
	VALUES ('Incorect file to import transfer', 'Data transfer SSIS', 'Loading file')
DECLARE @fails_count int -- counts incorect loading files

SET @fails_count = ( SELECT COUNT (*) FROM file_name_errors )
-- if last loading file attempts incorrect, mail to admins is sending
IF ( @fails_count > 10 )
BEGIN
EXEC report_to_admins @err_number = 1
 -- table with errors is cleaned
DELETE FROM file_name_errors
END
GO

--------------------------------------------------------------------------------------------

CREATE PROCEDURE dbo.start_import
AS
DECLARE @import_id int -- foreign key with import stats
INSERT INTO logs( msg, proc_name, step_name) 
	VALUES ('Starting file transfer', 'Data transfer SSIS', 'Start transfer')
INSERT INTO imp_stats( end_dt ) VALUES ( NULL ) -- start new import stats log
SET @import_id = SCOPE_IDENTITY();	-- get last added import stats key
INSERT INTO imported_rows(imp_nr, imp_reg_nr, imp_firstname, imp_surname,imp_personal_identity, imp_auto_model, imp_brand_name, row_in_import_table)
		SELECT @import_id, auto_reg_num, firstname, surname, personal_identity, auto_model, brand_name, row_id FROM auto_transfer; -- rewrite from temporary auto_transfer to imported_rows table
INSERT INTO logs(msg, proc_name, step_name) 
		VALUES ('Rewriting data from temporary auto_ransfer to inserted_rows was succeed', 'Data transfer SSIS', 'Rewriting')
GO

----------------------------------------------------------------------------------------------

CREATE PROCEDURE dbo.process_data
AS
	DECLARE @i INT
	DECLARE @reg_nr varchar(8)
	DECLARE @firstname varchar(50)
	DECLARE @surname varchar(50)
	DECLARE @personal_identity BIGINT
	DECLARE @model varchar(256)
	DECLARE @brand varchar(256)

	DECLARE @brand_id INT
	DECLARE @model_id INT
	DECLARE @user_id INT
	
	DECLARE kur SCROLL cursor for 
		SELECT my_id, imp_reg_nr, imp_firstname, imp_surname, imp_personal_identity, imp_auto_model, imp_brand_name FROM imported_rows WHERE status = 'not processed'
	OPEN kur;
	
	FETCH NEXT FROM kur INTO @i, @reg_nr, @firstname, @surname, @personal_identity, @model, @brand;
	WHILE @@FETCH_STATUS=0
	BEGIN
		IF( SELECT count(*) FROM autos a WHERE (@reg_nr = a.reg_nr) ) = 0	-- new auto in database		
		BEGIN 
			-- add new car to database
			-- dodac transakcje
			IF(SELECT count(*) FROM users u -- check users, if personal_identity in database, save its id, else add user to database
				WHERE u.personal_identity = @personal_identity) = 0
				BEGIN
					INSERT users(firstname, surname, personal_identity) VALUES (@firstname, @surname, @personal_identity) -- add users to local table
					SET @user_id = SCOPE_IDENTITY();
				END
				ELSE
				BEGIN
					SET @user_id = (SELECT user_id FROM users u WHERE u.personal_identity = @personal_identity);
				END

			IF(SELECT count(*) FROM brands b -- check brands, if brand name is in database, save his id, else add brand to database
				WHERE b.name = @brand) = 0
				BEGIN
					INSERT brands(name) VALUES (@brand);
					SET @brand_id = SCOPE_IDENTITY()
				END
			ELSE

				SET @brand_id = (SELECT brand_id FROM brands b WHERE b.name = @brand);

			IF( SELECT count(*) from models m -- check models, if model name doesn't exist in database, add model
				WHERE m.name = @model ) = 0
				BEGIN
					INSERT models(name, model_brand_id) VALUES (@model, @brand_id);
					SET @model_id = SCOPE_IDENTITY()
				END
			
			ELSE -- if model exist in database, check his brand if brand name the same as in imported, add model to autos table, else write incorect data log 
			BEGIN
				IF(SELECT count(*) FROM models m
					WHERE m.name = @model AND m.model_brand_id = @brand_id) = 0
				BEGIN
					UPDATE imported_rows SET status = 'wrong data' where my_id = @i
					
				END
				ELSE
				BEGIN
					SET @model_id = (SELECT model_id FROM models m
										WHERE m.name = @model AND m.model_brand_id = @brand_id); -- set existing model id
				END
			END
			
			INSERT autos(reg_nr, auto_model_id, auto_user_id) values(@reg_nr, @model_id, @user_id) -- all correct, can add new auto to database
			UPDATE imported_rows SET master_id = SCOPE_IDENTITY() where my_id = @i -- add foreign master key to imported_rows record
			UPDATE imported_rows SET status = 'new car' where my_id = @i -- set up new status

		END
		ELSE
		BEGIN
			-- check local tables, if data the same as imported write log 'duplicated', else set status, 'wrong data' 
			
			IF(SELECT count(*) FROM autos a
				join users u on a.auto_user_id = u.user_id
				join models m on a.auto_model_id = m.model_id
				join brands b on m.model_brand_id = b.brand_id
				where (a.reg_nr = @reg_nr and u. firstname = @firstname and u.surname = @surname and m.name = @model and b.name = @brand)) = 0
			BEGIN
				UPDATE imported_rows SET status = 'wrong data' where my_id = @i
			END
			ELSE
			BEGIN
				UPDATE imported_rows SET status ='duplicated' where my_id = @i
				UPDATE imported_rows SET master_id = (SELECT  autos_id from autos where (autos.reg_nr = @reg_nr)) where(my_id = @i)
			END	
		END

			
	FETCH NEXT FROM kur INTO @i, @reg_nr, @firstname, @surname, @personal_identity, @model, @brand
	END

	CLOSE kur   	
	DEALLOCATE kur

	INSERT INTO logs(msg, proc_name, step_name) VALUES ('Finalizing data processing', 'Data transfer SSIS', 'Processing')
	UPDATE imp_stats SET  err_no = 0 WHERE (end_dt IS NULL) -- set import status as 'done'
	UPDATE imp_stats SET end_dt = GETDATE() WHERE (end_dt IS NULL) -- add finished tune
GO
