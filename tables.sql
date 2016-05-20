USE master
IF EXISTS(select * from sys.databases where name='cars')
DROP DATABASE cars
GO

CREATE DATABASE cars
GO

USE cars

CREATE TABLE sys_usr -- users in database
(
	user_id int NOT NULL IDENTITY CONSTRAINT PK_uzytkownik PRIMARY KEY,
	firstname nvarchar(50) NOT NULL,
	surname nvarchar(50) NOT NULL,
	e_mail nvarchar(100) NULL,
	admin bit NOT NULL DEFAULT 0 -- 1 is admin | 0 normal user
)

CREATE TABLE logs -- database logs
(
	row_id int NOT NULL IDENTITY CONSTRAINT PK_LOG PRIMARY KEY,
	msg nvarchar(256) NOT NULL,
	proc_name nvarchar(100) NULL,
	step_name nvarchar(100) NULL,
	entry_dt datetime NOT NULL DEFAULT GETDATE()
)

CREATE TABLE imp_stats -- every import status table
(
	imp_id int NOT NULL IDENTITY CONSTRAINT PK_imp PRIMARY KEY,
	start_dt datetime NOT NULL DEFAULT GETDATE(),
	end_dt datetime NULL, 
	err_no int NOT NULL DEFAULT -1,  -- -1 in progres | 0 – finished
	host nvarchar(100) NOT NULL DEFAULT HOST_NAME()
)

CREATE TABLE file_name_errors -- files loading logs
(
	file_id int NOT NULL IDENTITY CONSTRAINT PK_file PRIMARY KEY,
	the_file_name nvarchar(100) NOT NULL,
	event_date datetime NOT NULL DEFAULT GETDATE(),
	user_name nvarchar(100) NOT NULL DEFAULT USER_NAME(),
	host nvarchar (100) NOT NULL DEFAULT HOST_NAME()
)

CREATE TABLE users -- local table with autos users
(	
	user_id int NOT NULL IDENTITY CONSTRAINT PK_user PRIMARY KEY,
	firstname nvarchar(50) NOT NULL,
	surname nvarchar(50) NOT NULL,
	personal_identity BIGINT NOT NULL
)

CREATE TABLE brands -- local table with models brands
(
	brand_id int NOT NULL IDENTITY CONSTRAINT PK_brand PRIMARY KEY,
	name nvarchar(50) NOT NULL
)

CREATE TABLE models -- local table with autos models
(
	model_id int NOT NULL IDENTITY CONSTRAINT PK_model PRIMARY KEY,
	model_brand_id int NOT NULL CONSTRAINT FK_model_brand FOREIGN KEY REFERENCES brands(brand_id),
	name nvarchar(50) NOT NULL
)

CREATE TABLE autos -- local table with autos
(
	autos_id int NOT NULL IDENTITY CONSTRAINT PK_autos PRIMARY KEY,
	reg_nr nvarchar(8) NOT NULL,
	auto_model_id int NOT NULL CONSTRAINT FK_auto_model FOREIGN KEY REFERENCES models(model_id),
	auto_user_id int NOT NULL CONSTRAINT FK_auto_user FOREIGN KEY REFERENCES users(user_id),
)
CREATE TABLE auto_transfer -- temporary table to transfer
(
	row_id int NOT NULL IDENTITY (1,1) PRIMARY KEY,
	firstname nvarchar(50) NULL,
	surname nvarchar(50) NULL,
	personal_identity BIGINT NULL,
	auto_reg_num nvarchar(8) NULL,
	auto_model nvarchar(50) NULL,
	brand_name nvarchar(50) NULL
)

CREATE TABLE imported_rows -- every imported row logs
(
	my_id int NOT NULL IDENTITY(1,1) PRIMARY KEY,
	master_id int NULL CONSTRAINT FK_master_id FOREIGN KEY REFERENCES autos(autos_id),
	imp_nr int NOT NULL CONSTRAINT FK_imp_nr FOREIGN KEY REFERENCES imp_stats(imp_id),
	imp_reg_nr nvarchar(8) NULL,
	imp_firstname nvarchar(50) NULL,
	imp_surname nvarchar(50) NULL,
	imp_personal_identity BIGINT NULL,
	imp_auto_model nvarchar(50) NULL, 
	imp_brand_name nvarchar(50) NULL,
	row_in_import_table int NOT NULL,-- cant add foreign key becouse import table (auto_transfer) is cleared before every import
	status nvarchar (50) NOT NULL default 'not processed' -- not processed, new record, duplicated(the same records), wrong data
)
