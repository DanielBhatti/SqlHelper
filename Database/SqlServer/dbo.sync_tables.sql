create or alter procedure dbo.sync_tables @source_schema_name varchar(100), @source_table_name varchar(100), @target_schema_name varchar(100) = null, @target_table_name varchar(100) = null, @linked_server_name varchar(100) = null, @linked_database_name varchar(100) = null, @where_clause varchar(1000) = null, @with_no_lock bit = 1, @is_executing bit = 1, @is_transaction bit = 0
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

set @where_clause = ltrim(isnull(@where_clause, ''))
if ISNULL(@where_clause, '')  != '' and left(@where_clause, 3) != 'and' set @where_clause = ' and ' + @where_clause



if not exists(select object_id from sys.tables where object_id = @target_object_id) throw 51000, 'No object_id found in target schema for object indicated', 1

if not exists(select object_id from sys.tables where object_id = @source_object_id) throw 51000, 'No object_id found in source schema for object indicated', 1

declare @has_identity_insert bit = (select count(*) from sys.columns where object_id = @target_object_id and is_identity = 1)



declare @sql nvarchar(max) = ''

if @with_no_lock = 1 set @sql += 'set transaction isolation level read uncommitted' + char(13) + char(10)
set @sql += 'set xact_abort on' + char(13) + char(10)
if @is_transaction =1 set @sql += 'begin transaction' + CHAR(13) + CHAR(10)

if @has_identity_insert = 1 set @sql += 'set identity_insert ' + @target_schema_name + '.' + @target_table_name + ' on'

set @sql += 
'
delete from ' + @target_schema_name + '.' + @target_table_name + ' where 1 = 1 ' + @where_clause + '
insert into ' + @target_schema_name + '.' + @target_table_name + '(
'

declare @matched_columns_sql varchar(1000) = 
'

select 
COLUMN_NAME
from information_schema.columns
where table_schema = ''' + @target_schema_name + '''
and table_name = ''' + @target_table_name + '''

intersect

select 
COLUMN_NAME
from ' +  @linked_server_name + '.' + @linked_database_name + '.information_schema.columns
where table_schema = ''' + @source_schema_name + '''
and table_name = ''' + @source_table_name + '''
'

declare @matched_columns table(column_name varchar(100) not null)
insert into @matched_columns
execute(@matched_columns_sql)

declare @columns_csv varchar(max) = ''
select
@columns_csv += quotename(column_name) + ','
from @matched_columns

set @columns_csv = left(@columns_csv, len(@columns_csv) - len(','))

set @sql += @columns_csv + '
)
select
' + @columns_csv + '
from ' + @linked_server_name + '.' + @linked_database_name + '.' + @source_schema_name + '.' + @source_table_name + ' where 1 = 1 ' + @where_clause + '
'

if @has_identity_insert = 1 set @sql += 'set identity_insert ' + @target_schema_name + '.' + @target_table_name + ' off'

if @is_transaction = 1 set @sql += char(13) + char(10) + 'commit'

if @is_executing = 1 exec(@sql)
else select @sql
        
end
go