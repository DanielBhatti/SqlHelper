;with f as
(
select
schema_name = object_schema_name(tables.object_id),
table_name = tables.name,
foreign_key_name = foreign_keys.name,
is_not_trusted,
is_disabled,
enable_statement = 'alter table ' + quotename(object_schema_name(tables.object_id)) + '.' + quotename(object_name(tables.object_id)) + ' with check check constraint ' + foreign_keys.name,
enable_for_future_rows_only_statement = 'alter table ' + quotename(object_schema_name(tables.object_id)) + '.' + quotename(object_name(tables.object_id)) + ' with nocheck check constraint ' + foreign_keys.name,
disable_statement = 'alter table ' + quotename(object_schema_name(tables.object_id)) + '.' + quotename(object_name(tables.object_id)) + ' nocheck constraint ' + foreign_keys.name,
drop_statement = 'alter table ' + quotename(object_schema_name(tables.object_id)) + '.' + quotename(object_name(tables.object_id)) + ' drop constraint ' + foreign_keys.name
from sys.foreign_keys
inner join sys.tables on tables.object_id = foreign_keys.parent_object_id
)
select
*
from f
where schema_name in ('msr', 'sentinel', 'smp', 'dbo')