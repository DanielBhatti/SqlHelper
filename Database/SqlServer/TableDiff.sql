declare @csv_fields varchar(max) = 'annaly_loan_id, ll_servicer'
-- NOTE: when 1, this overrides @csv_fields
declare @compare_all_shared_fields bit = 0

declare @linked_server_name varchar(255) = 'PRODSQL01'
declare @linked_server_database varchar(255) = 'Piculet'
declare @table_schema varchar(255) = 'msr'
declare @table_name varchar(255) = 'MsrDetails'


--- Don't modify anything past this line

declare @column_table table(column_name varchar(255))

if @compare_all_shared_fields = 1
begin
    
    declare @insert_sql nvarchar(max) = ''

   set @insert_sql += 'select' + char(13) + char(10)
    set @insert_sql += 'source_columns.COLUMN_NAME' + char(13) + char(10)
    set @insert_sql += 'from INFORMATION_SCHEMA.COLUMNS source_columns' + char(13) + char(10)
    set @insert_sql += 'inner join ' + quotename(@linked_server_name) + '.' + quotename(@linked_server_database) + '.INFORMATION_SCHEMA.COLUMNS target_columns on target_columns.TABLE_SCHEMA = source_columns.TABLE_SCHEMA and target_columns.TABLE_NAME = source_columns.TABLE_NAME and target_columns.COLUMN_NAME = source_columns.column_name' + char(13) + char(10)
    set @insert_sql += 'where' + char(13) + char(10)
    set @insert_sql += 'source_columns.table_schema = @table_schema' + char(13) + char(10)
    set @insert_sql += 'and source_columns.table_name = @table_name' + char(13) + char(10)



   insert into @column_table (column_name)
    exec sp_executesql @insert_sql, N'@table_schema varchar(255), @table_name varchar(255)', @table_schema, @table_name
end
else
begin
    insert into @column_table (column_name)
    select
    column_name = Item
    from dbo.CsvToTable(@csv_fields, ',')
end

declare @sql varchar(max)
declare @select_source_table_sql varchar(max) = ''
declare @select_target_table_sql varchar(max) = ''

-- f1, f2, f3, ... f100 from schema.table
select
@select_source_table_sql += column_name + ',' + char(13) + char(10)
from @column_table

set @select_source_table_sql = left(@select_source_table_sql, len(@select_source_table_sql) - len(',' + char(13) + char(10))) + char(13) + char(10)
set @select_source_table_sql += 'from ' + quotename(@table_schema) + '.' + quotename(@table_name) + char(13) + char(10)

--f1, f2, f3 ... f100 from linked_server.database.schema.table
select
@select_target_table_sql += column_name + ',' + char(13) + char(10)
from @column_table

set @select_target_table_sql = left(@select_target_table_sql, len(@select_target_table_sql) - len(',' + char(13) + char(10))) + char(13) + char(10)
set @select_target_table_sql += 'from ' + quotename(@linked_server_name) + '.' + quotename(@linked_server_database) + '.' + quotename(@table_schema) + '.' + quotename(@table_name) + char(13) + char(10)


-- @sql is of the form
  --(
  --select f1, f2, f3 ... f100 from schema.table
  --except
  --select f1, f2, f3 ... f100 from linked_server.database.schema.table
  --)
  --union
  --(
  --select f1, f2, f3 ... f100 from linked_server.database.schema.table
  --except
  --select f1, f2, f3 ... f100 from schema.table
  --)
set @sql =
'(' + char(13) + char(10) + 'select is_in_source = 1,' + char(13) + char(10) +
@select_source_table_sql + char(13) + char(10) +
'except' + char(13) + char(10) + 'select is_in_source = 1,' + char(13) + char(10) +
@select_target_table_sql +
')' + char(13) + char(10) +
'union' + char(13) + char(10) +
'(' + char(13) + char(10) + 'select is_in_source = 0,' + char(13) + char(10) +
@select_target_table_sql + char(13) + char(10) +
'except' + char(13) + char(10) + 'select is_in_source = 0,' + char(13) + char(10) +
@select_source_table_sql
+ ')'

--select @select_source_table_sql
--select @select_target_table_sql
--select @sql

exec(@sql)