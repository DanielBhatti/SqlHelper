-- NOTE maximum recursion depth is set to 5 (see child_level filter in where clause)
with foreign_key as
(
select
foreign_key_id = foreign_keys.object_id,
foreign_key_name = foreign_keys.name,
foreign_keys.parent_object_id,
parent_table_name = OBJECT_NAME(foreign_keys.parent_object_id),
foreign_key_columns.parent_column_id,
parent_column_name = parent_column.name,
foreign_keys.referenced_object_id,
referenced_table_name = OBJECT_NAME(foreign_keys.referenced_object_id),
foreign_key_columns.referenced_column_id,
referenced_column_name = referenced_column.name,
is_disabled,
is_not_trusted
from sys.foreign_keys
inner join sys.foreign_key_columns on foreign_key_columns.parent_object_id = foreign_keys.parent_object_id and foreign_key_columns.referenced_object_id = foreign_keys.referenced_object_id
inner join sys.columns parent_column on parent_column.object_id = foreign_key_columns.parent_object_id and parent_column.column_id = foreign_key_columns.parent_column_id
inner join sys.columns referenced_column on referenced_column.object_id = foreign_key_columns.referenced_object_id and referenced_column.column_id = foreign_key_columns.referenced_column_id
)
,foreign_key_recursion as
(
select
foreign_key_id,
foreign_key_name,
parent_object_id,
parent_table_name,
parent_column_id,
parent_column_name,
referenced_object_id,
referenced_table_name,
referenced_column_id,
referenced_column_name,
referenced_foreign_key_id = foreign_key_id,
referenced_foreign_key_name = foreign_key_name,
is_disabled,
is_not_trusted,
reference_level = 1
from foreign_key



union all



select
referencing_key.foreign_key_id,
referenced_key.foreign_key_name,
referencing_key.parent_object_id,
referencing_key.parent_table_name,
referencing_key.parent_column_id,
referencing_key.parent_column_name,
referenced_key.referenced_object_id,
referenced_key.referenced_table_name,
referenced_key.referenced_column_id,
referenced_key.referenced_column_name,
referenced_foreign_key_id = referenced_key.foreign_key_id,
referenced_foreign_key = referenced_key.foreign_key_name,
referenced_key.is_disabled,
referenced_key.is_not_trusted,
reference_level = referencing_key.reference_level + 1
from foreign_key referenced_key
inner join foreign_key_recursion referencing_key on referencing_key.referenced_object_id = referenced_key.parent_object_id
where
referencing_key.reference_level < 5
)
select distinct
fkr.foreign_key_id,
fkr.foreign_key_name,
fkr.parent_object_id,
fkr.parent_table_name,
fkr.parent_column_id,
fkr.parent_column_name,
fkr.referenced_object_id,
fkr.referenced_table_name,
fkr.referenced_column_id,
fkr.referenced_column_name,
fkr.referenced_foreign_key_id,
fkr.referenced_foreign_key_name,
fkr.is_disabled,
fkr.is_not_trusted,
is_immediate_reference = case when fk.parent_object_id is null then 0 else 1 end
from foreign_key_recursion fkr
left join foreign_key fk on fk.parent_object_id = fkr.parent_object_id and fk.referenced_object_id = fkr.referenced_object_id