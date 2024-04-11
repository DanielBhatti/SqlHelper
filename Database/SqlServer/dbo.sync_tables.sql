create procedure dbo.sync_tables @source_schema_name varchar(100), @source_table_name varchar(100), @target_schema_name varchar(100) = null, @target_table_name varchar(100) = null, @linked_server_name varchar(100) = null, @linked_database_name varchar(100) = null, @where_clause varchar(1000) = null, @with_no_lock bit = 1, @is_executing bit = 1
as
begin

--- Don't modify anything beyond this line

set @target_schema_name = isnull(@target_schema_name, @source_schema_name)
set @target_table_name = isnull(@target_table_name, @source_table_name)
set @linked_server_name = isnull(@linked_server_name, '')
set @linked_database_name = isnull(@linked_database_name, '')
set @with_no_lock = isnull(@with_no_lock, 0)


declare @source_object_id int = (select object_id from sys.objects where object_schema_name(object_id) = @source_schema_name and object_name(object_id) = @source_table_name)

declare @target_object_id int = (select object_id from sys.objects where object_schema_name(object_id) = @target_schema_name and object_name(object_id) = @target_table_name)

set @where_clause = isnull(@where_clause, '')
if left(ltrim(@where_clause), 3) != 'and'  set @where_clause = ' and ' + @where_clause



if not exists(select object_id from sys.tables where object_id = @target_object_id) throw 51000, 'No object_id found in target schema for object indicated', 1

if not exists(select object_id from sys.tables where object_id = @source_object_id) throw 51000, 'No object_id found in source schema for object indicated', 1


if not exists(select OBJECT_ID from sys.objects where OBJECT_SCHEMA_NAME(object_id) = 'dbo' and OBJECT_NAME(object_id) = 'SyncHistory')
begin
create table dbo.SyncHistory(
    sync_history_id int identity(1, 1) not null primary key,
    linked_server_name varchar(100) not null,
    linked_database_name varchar(100) not null,
    source_schema_name varchar(100) not null,
    source_table_name varchar(100) not null,
    target_schema_name varchar(100) not null,
    target_table_name varchar(100) not null,
    start_time datetime not null,
    end_time datetime not null,
    number_of_records_removed bigint not null,
    number_of_records_added bigint not null,
    sql_statement varchar(max) not null
    )
end

declare @has_identity_insert bit = (select count(*) from sys.columns where object_id = @target_object_id and is_identity = 1)



declare @sql nvarchar(max) = ''

if @with_no_lock = 1 set @sql += 'set transaction isolation level read uncommitted' + char(13) + char(10)
set @sql += 'set xact_abort on begin transaction' + char(13) + char(10)

set @sql += 'declare @start_time datetime = getdate()' + CHAR(13) + CHAR(10)

if @has_identity_insert = 1 set @sql += 'set identity_insert ' + @target_schema_name + '.' + @target_table_name + ' on'

set @sql += 
'
delete from ' + @target_schema_name + '.' + @target_table_name + ' where 1 = 1 ' + @where_clause + '
declare @number_of_records_removed bigint = select @@rowcount

insert into ' + @target_schema_name + '.' + @target_table_name + '(
'

declare @columns_csv varchar(max) = ''
select
@columns_csv += quotename(columns.column_name) + ','
from information_schema.columns
where table_schema = @target_schema_name
and table_name = @target_table_name

set @columns_csv = left(@columns_csv, len(@columns_csv) - len(','))

set @sql += @columns_csv + '
)
select
' + @columns_csv + '
from ' + @linked_server_name + '.' + @linked_database_name + '.' + @source_schema_name + '.' + @source_table_name + ' where 1 = 1 and ' + @where_clause + '
declare @number_of_records_added bigint = select @@rowcount
declare @end_time datetime = getdate()
'

if @has_identity_insert = 1 set @sql += 'set identity_insert ' + @target_schema_name + '.' + @target_table_name + ' off'

set @sql += char(13) + char(10) + 'commit'

declare @sql_statement varchar(max) = @sql
set @sql += '
insert into dbo.SyncHistory(
    linked_server_name, --1
    linked_database_name, --2
    source_schema_name, --3
    source_table_name, --4
    target_schema_name, --5
    target_table_name, --6
    start_time, --7
    end_time, --8
    number_of_records_removed, --9
    number_of_records_added, --10
    sql_statement --11
) values
(
''' + @linked_server_name + ''', --1
''' + @linked_database_name + ''', --2
''' + @source_schema_name + ''', --3
''' + @source_table_name + ''', --4
''' + @target_schema_name + ''', --5
''' + @target_table_name + ''', --6
@start_time, --7
@end_time, --8
@number_of_records_removed, --9
@number_of_records_added, --10
''' + @sql_statement + ''' --11
)'

if @is_executing = 1 exec(@sql)
else select @sql
        
end
go