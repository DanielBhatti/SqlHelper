-- NOTE maximum recursion depth is set to 5 (see child_level filter in where clause) 
-- Don't know why it recurses > 100 times (server recursion limit), maybe there's a circular chain of references somewhere
-- But I don't expect ever needing any more than 5 levels deep
with dependency_object as
(
select distinct
object_id = d.referencing_id,
object_schema_name = object_schema_name(d.referencing_id),
object_name = object_name(d.referencing_id),
object_type = parent.type_desc,
child_id = d.referenced_id,
child_database = isnull(d.referenced_database_name, 'Piculet'),
child_schema_name = d.referenced_schema_name,
child_name = d.referenced_entity_name,
child_type = child.type_desc
from sys.sql_expression_dependencies d
left join sys.objects parent on parent.object_id = d.referencing_id
left join sys.objects child on child.object_id = d.referenced_id
)
,dependency_object_recursion as
(
select
object_id,
object_schema_name,
object_name,
object_type,
child_id,
child_database,
child_schema_name,
child_name,
child_type,
child_level = 1
from dependency_object

union all

select
parent.object_id,
parent.object_schema_name,
parent.object_name,
parent.object_type,
child.child_id,
child.child_database,
child.child_schema_name,
child.child_name,
child.child_type,
child_level = parent.child_level + 1
from dependency_object child
inner join dependency_object_recursion parent on parent.child_id = child.object_id
where
parent.child_level < 5
)
select distinct
parent_id = dor.object_id,
parent_schema_name = dor.object_schema_name,
parent_name = dor.object_name,
parent_type = dor.object_type,
dor.child_id,
dor.child_database,
dor.child_schema_name,
dor.child_name,
dor.child_type,
is_immediate_child = case when do.child_id is null and isnull(do.child_database, 'Unknown Database') != db_name() then 0 else 1 end,
parent_definition = sql_modules.definition,
refresh_parent_module_statement = 'exec sp_refreshsqlmodule ' + '''' + OBJECT_SCHEMA_NAME(dor.object_id) + '.' + OBJECT_NAME(dor.object_id) + ''''
from dependency_object_recursion dor
left join dependency_object do on do.object_id = dor.object_id and do.child_id = dor.child_id
left join sys.sql_modules on sql_modules.object_id = do.object_id
GO
