select distinct
referencing_object_type = referencing_object.type_desc,
referencing_object_schema_name = OBJECT_SCHEMA_NAME(referencing_id),
referencing_object_name = OBJECT_NAME(referencing_id),
missing_object_type = referencing_object.type_desc,
missing_object_schema_name = OBJECT_SCHEMA_NAME(referenced_id),
missing_object_name = OBJECT_NAME(referenced_id),
referenced_database_name
from sys.sql_expression_dependencies
left join sys.objects missing_object on missing_object.object_id = sql_expression_dependencies.referenced_id
left join sys.objects referencing_object on referencing_object.object_id = sql_expression_dependencies.referencing_id
where
is_ambiguous = 0
and (OBJECT_ID(ISNULL(QUOTENAME(referenced_server_name) + '.', '')
    + ISNULL(QUOTENAME(referenced_database_name) + '.', '')
    + ISNULL(QUOTENAME(referenced_schema_name) + '.', '')
    + QUOTENAME(referenced_entity_name)) IS NULL)
--and referenced_database_name is not null
and referenced_database_name = 'Piculet'