select
object_definition = object_definition(d.object_id),
referencing_schema_name = object_schema_name(d.object_id),
referencing_object_name = object_name(d.object_id),
referencing_object_type = o.type_desc,
table_schema_name = object_schema_name(d.referenced_major_id),
table_name = object_name(d.referenced_major_id),
column_name = c.name,
is_selected = case when d.is_selected = 1 or d.is_select_all = 1 then 1 else 0 end,
is_updated_or_inserted = d.is_updated,
d.is_select_all,
is_potentially_deleted = IIF(m.definition like '%delete%' COLLATE Latin1_General_100_CI_AI, 1, 0),
refresh_module_statement = 'exec sp_refreshsqlmodule ' + '''' + OBJECT_SCHEMA_NAME(d.object_id) + '.' + OBJECT_NAME(d.object_id) + ''''
from sys.sql_dependencies d
inner join sys.columns c on c.object_id = d.referenced_major_id and c.column_id = d.referenced_minor_id
left join sys.sql_modules m on m.object_id = d.object_id
left join sys.objects o on o.object_id = m.object_id