-- delete all procedures from database
DROP PROCEDURE dbo.send_mail, dbo.report_to_admins, dbo.add_fail_file_load, dbo.start_import, dbo.process_data;
GO

--chcek temproary table and clean it
select * from auto_transfer
truncate table auto_transfer

-- add new objects to temporary table
insert auto_transfer(firstname, surname, personal_identity, auto_reg_num, auto_model, brand_name) values('kamil', 'tartanus', 94021400374, 'bd 12d24', '206', 'seat')
insert auto_transfer(firstname, surname, personal_identity, auto_reg_num, auto_model, brand_name) values('daria', 'nowakowska', 88012100321 ,'LU k1a25', 'punto', 'fiat')

--start import (write logs and rewrite data from auto_transfer to imported_rows)
exec start_import

--process data and rewrite from imported_rows to local tables if doesn't exists and correct
exec process_data

-- show all Cars tables
select * from logs
select * from imp_stats
select * from imported_rows
select * from autos
select * from users
select * from models
select * from brands


-- is cleaning all tables, despite foreign keys, truncate in order
delete from autos
DBCC CHECKIDENT ('autos', RESEED, 0)
delete from imported_rows
DBCC CHECKIDENT ('imported_rows', RESEED, 0)
delete from imp_stats
DBCC CHECKIDENT ('imp_stats', RESEED, 0)
delete from models
DBCC CHECKIDENT ('models', RESEED, 0)
delete from brands
DBCC CHECKIDENT ('brands', RESEED, 0)
delete from users
DBCC CHECKIDENT ('users', RESEED, 0)
delete from logs
DBCC CHECKIDENT ('logs', RESEED, 0)