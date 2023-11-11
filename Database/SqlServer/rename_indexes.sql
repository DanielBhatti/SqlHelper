;with index_columns_ext as
(
select distinct
indexes.object_id,
table_object_id = tables.object_id,
indexes.index_id,
index_name = indexes.name,
index_type = indexes.type_desc,
indexes.is_unique,
indexes.is_primary_key,
indexes.fill_factor,
create_statement = 'exec sp_rename ' + schema_name(tables.schema_id) + '.' + tables.name + iif(indexes.is_primary_key = 1, ' primary key clustered ', iif(indexes.is_unique = 1, ' unique ', '') + iif(indexes.type_desc = 'CLUSTERED', 'clustered ', '') + 'index ') + ' ' + '(' +
    substring((select c.name + '_' from sys.index_columns ic inner join sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id where ic.object_id = tables.object_id and index_columns.index_id = indexes.index_id and ic.index_id = indexes.index_id and tables.object_id = tables.object_id order by index_columns.index_column_id for xml path('')),
    1,
    len((select c.name + '_' from sys.index_columns ic inner join sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id where ic.object_id = tables.object_id and index_columns.index_id = indexes.index_id and ic.index_id = indexes.index_id and tables.object_id = tables.object_id order by index_columns.index_column_id for xml path(''))) - 1) + ')',
drop_statement = case when is_primary_key = 1 then 'alter table ' + schema_name(tables.schema_id) + '.' + tables.name + ' drop constraint ' + indexes.name else 'drop index ' + schema_name(tables.schema_id) + '.' + tables.name  + '.' + indexes.name end 
from sys.tables
inner join sys.columns on columns.object_id = tables.object_id
inner join sys.index_columns on index_columns.object_id = tables.object_id and index_columns.column_id = columns.column_id
inner join sys.indexes on indexes.object_id = index_columns.object_id and indexes.index_id = index_columns.index_id
)
select
index_name = indexes.name,
index_type = indexes.type_desc,
indexes.is_unique,
indexes.is_primary_key,
indexes.fill_factor,
column_names = stuff((select ',' + columns.name + ' (' + iif(index_columns.is_descending_key = 0, 'asc', 'desc') + ')' from sys.index_columns inner join sys.columns on columns.object_id = index_columns.object_id and columns.column_id = index_columns.column_id where index_columns.object_id = indexes.object_id and index_columns.index_id = indexes.index_id and index_columns.is_included_column = 0 and columns.object_id = indexes.object_id order by index_columns.key_ordinal for xml path('')), 1, 1, '')
  + isnull(stuff((select ',' + columns.name + ' (' + iif(index_columns.is_descending_key = 0, 'asc', 'desc') + ')' from sys.index_columns inner join sys.columns on columns.object_id = index_columns.object_id and columns.column_id = index_columns.column_id where index_columns.object_id = indexes.object_id and index_columns.index_id = indexes.index_id and index_columns.is_included_column = 1 and columns.object_id = indexes.object_id and columns.object_id = table_object_id order by index_columns.key_ordinal for xml path('')), 1, 1, ''), ''),
create_statement,
drop_statement

from sys.indexes
left join index_columns_ext on index_columns_ext.object_id = indexes.object_id and index_columns_ext.index_id = indexes.index_id