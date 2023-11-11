declare @table_schema varchar(255) = 'servicer'
declare @table_name varchar(255) = 'PHH_M_REMIT_ESCROW_ADVANCES'

-- statement is null if no primary key, fix later

declare @table_object_id int = (select object_id from sys.tables where schema_name(schema_id) = @table_schema and name = @table_name)

if @table_object_id is null 
begin
    declare @error_message varchar(100) = 'No table ' + @table_schema + '.' + @table_name + ' was found'
    ;throw 51000, @error_message, 1
end

declare @create_table_sql varchar(max) = 'create table ' + quotename(@table_schema) + '.' + quotename(@table_name) + '(' + char(13) + char(10) + '     '

-- create table statement with columns, datatypes, nullability
select
@create_table_sql += quotename(columns.name) + ' ' + 
case
    when computed_columns.definition is not null then ' as ' + computed_columns.definition + iif(computed_columns.is_persisted = 1, ' persisted', '')
    else
    case
        when type_name(columns.system_type_id) like '%char%' or type_name(columns.system_type_id) like '%binary%' then type_name(columns.system_type_id) + '(' + case when columns.max_length = -1 then 'max' else cast(columns.max_length / iif(type_name(columns.system_type_id) like 'n%', 2, 1) as varchar(255)) end + ')'
        when type_name(columns.system_type_id) in ('numeric', 'decimal') then type_name(columns.system_type_id) + '(' + cast(columns.precision as varchar(255)) + ',' + cast(columns.scale as varchar(255)) + ')'
        else type_name(columns.system_type_id)
    end + isnull(' collate ' + columns.collation_name, '') + iif(columns.is_nullable = 0, ' not null', ' null') + iif(columns.is_identity = 1, ' identity(' + cast(identity_columns.seed_value as varchar(255)) + ', ' + cast(identity_columns.increment_value as varchar(255)) +')', '') + char(13) + char(10) 
end + '    ,'
from sys.tables
inner join sys.columns on columns.object_id = tables.object_id
left join sys.computed_columns on computed_columns.object_id = columns.object_id
    and computed_columns.column_id = columns.column_id
left join sys.identity_columns on identity_columns.object_id = columns.object_id and identity_columns.column_id = columns.column_id
where tables.object_id = @table_object_id

set @create_table_sql = LEFT(@create_table_sql, len(@create_table_sql) - len('    ,'))
set @create_table_sql += ') ' + char(13) + char(10)

-- append the filespace to the table if one exists
select 
@create_table_sql += ' on ' + quotename(filegroups.name) + char(13) + char(10) +'go' + char(13) + char(10)
from sys.indexes
inner join sys.filegroups on filegroups.data_space_id = indexes.data_space_id
where
indexes.object_id = @table_object_id
and indexes.index_id in (0, 1)


select
@create_table_sql += OBJECT_DEFINITION(triggers.object_id) + char(13) + char(10) + 'go' + char(13) + char(10)
from sys.triggers
inner join sys.tables on tables.object_id = triggers.parent_id
where
tables.object_id = @table_object_id


-- add partition key if exists
select
@create_table_sql += 
case when indexes.is_primary_key = 1 then 'alter table ' + quotename(object_schema_name(tables.object_id)) + '.' + quotename(tables.name) + ' add constraint ' + quotename(indexes.name) + ' primary key clustered '
else 'create ' + iif(indexes.is_unique = 1, 'unique ', '') + iif(indexes.type_desc = 'CLUSTERED', 'clustered ', '') + ' index ' + quotename(indexes.name) + ' on ' + quotename(object_schema_name(tables.object_id)) + '.' + quotename(tables.name) end +
'(' + substring((select quotename(c.name) + iif(index_columns.is_descending_key = 0, ' asc', ' desc') + ',' from sys.index_columns ic inner join sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id where ic.object_id = tables.object_id and ic.index_id = indexes.index_id order by ic.key_ordinal asc for xml path('')),
    1,
    len((select quotename(c.name) + iif(index_columns.is_descending_key = 0, ' asc', ' desc') + ',' from sys.index_columns ic inner join sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id where ic.object_id = tables.object_id and ic.index_id = indexes.index_id order by ic.key_ordinal asc for xml path(''))) - 1) + ')' + ' on ' + partition_schemes.name + '(' + quotename(columns.name) + ')' + char(13) + char(10) + 'go' + char(13) + char(10)
from sys.tables
inner join sys.indexes on indexes.object_id = tables.object_id
    --and indexes.type in (0, 1)
inner join sys.partition_schemes on partition_schemes.data_space_id = indexes.data_space_id
inner join sys.index_columns on index_columns.object_id = indexes.object_id
    and index_columns.index_id = indexes.index_id
    and index_columns.partition_ordinal >= 1
inner join sys.columns on columns.object_id = index_columns.object_id
    and columns.column_id = index_columns.column_id
where tables.object_id = @table_object_id

-- add indexes
select
@create_table_sql += case when indexes.is_primary_key = 1 then 'alter table ' + quotename(object_schema_name(indexes.object_id)) + '.' + quotename(object_name(indexes.object_id)) + ' add constraint ' + quotename(indexes.name) + ' primary key clustered '
else 'create ' + iif(indexes.is_unique = 1, 'unique ', '') + iif(indexes.type_desc = 'CLUSTERED', 'clustered ', '') + 'index ' + quotename(indexes.name) + ' on ' + quotename(object_schema_name(indexes.object_id)) + '.' + quotename(object_name(indexes.object_id)) end +
'(' + substring((select quotename(columns.name) + iif(index_columns.is_descending_key = 0, ' asc', ' desc') + ', ' from sys.columns inner join sys.index_columns on index_columns.object_id = columns.object_id and index_columns.column_id = columns.column_id where index_columns.object_id = indexes.object_id and index_columns.index_id = indexes.index_id order by index_columns.index_column_id for xml path('')),
    1,
    len((select quotename(columns.name) + iif(index_columns.is_descending_key = 0, ' asc', ' desc') + ', ' from sys.columns inner join sys.index_columns on index_columns.object_id = columns.object_id and index_columns.column_id = columns.column_id where index_columns.object_id = indexes.object_id and index_columns.index_id = indexes.index_id order by index_columns.index_column_id for xml path(''))) - 1) + ')' + ISNULL(' where ' + filter_definition, '') + ' on ' + quotename(filegroups.name) + char(13) + char(10) + 'go' + char(13) + char(10)
from sys.indexes
inner join sys.filegroups on filegroups.data_space_id = indexes.data_space_id
where indexes.object_id = @table_object_id
and indexes.index_id != 0 -- remove heap, which creates null concatenation

-- add foreign keys
select
@create_table_sql += 'alter table ' + quotename(object_schema_name(foreign_keys.parent_object_id)) + '.' + quotename(object_name(foreign_keys.parent_object_id)) + ' add constraint ' + quotename(foreign_keys.name) + ' foreign key (' + quotename(parent_column.name) + ') references ' + quotename(object_schema_name(foreign_keys.referenced_object_id)) + '.' + quotename(object_name(foreign_keys.referenced_object_id)) + ' (' + quotename(referenced_column.name) + ')' + char(13) + char(10) + 'go' + char(13) + char(10)
from sys.foreign_keys
inner join sys.foreign_key_columns parent_column_key on parent_column_key.parent_object_id = foreign_keys.parent_object_id and parent_column_key.constraint_object_id = foreign_keys.object_id
inner join sys.foreign_key_columns referenced_column_key on referenced_column_key.referenced_object_id = foreign_keys.referenced_object_id and referenced_column_key.constraint_object_id = foreign_keys.object_id
inner join sys.columns parent_column on parent_column.object_id = parent_column_key.parent_object_id and parent_column.column_id = parent_column_key.parent_column_id
inner join sys.columns referenced_column on referenced_column.object_id = referenced_column_key.referenced_object_id and referenced_column.column_id = referenced_column_key.referenced_column_id
where parent_column.object_id = @table_object_id

-- add constraints
;with constraints as
(
    select
    default_constraints.name,
    parent_object_id,
    parent_column_id,
    type_desc,
    definition
    from sys.default_constraints
    left join sys.columns on columns.object_id = default_constraints.parent_object_id and columns.column_id = default_constraints.parent_column_id

    union all
    
    select
    name,
    parent_object_id,
    parent_column_id,
    type_desc,
    definition
    from sys.check_constraints
)
select
@create_table_sql += 'alter table ' + quotename(object_schema_name(columns.object_id)) + '.' + quotename(object_name(columns.object_id)) + ' add constraint ' + quotename(constraints.name) +
    case (constraints.type_desc)
    when 'DEFAULT_CONSTRAINT' then ' default' + constraints.definition + ' for ' + quotename(columns.name)
    when 'CHECK_CONSTRAINT' then ' check' + constraints.definition + ' for ' + quotename(columns.name)
    else '' end + char(13) + char(10) + 'go' + char(13) + char(10)
from constraints
inner join sys.columns on columns.object_id = constraints.parent_object_id and columns.column_id = constraints.parent_column_id
where columns.object_id = @table_object_id

select definition = @create_table_sql
