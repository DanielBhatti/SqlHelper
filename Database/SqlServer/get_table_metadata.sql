--alter procedure dbo.GetTableMetadata @table_schema varchar(255), @table_name varchar(255) as /*
declare @table_schema varchar(255) = 'msr'
declare @table_name varchar(255) = 'BankActivity'


declare @use_like_expression bit = 1

--*/
--- don't modify anything beyond this line

declare @table_object_id int = (select object_id from sys.tables where schema_name(schema_id) = @table_schema and name = @table_name)
if @table_object_id is null 
	begin
	set @table_object_id = (select top 1 object_id from sys.tables where schema_name(schema_id) like '%' + isnull(@table_schema, '') + '%' and name like '%' + isnull(@table_name, '') + '%')
	set @table_schema = (select schema_name(schema_id) from sys.tables where object_id = @table_object_id)
	set @table_name = (select name from sys.tables where object_id = @table_object_id)
	end
declare @table_full_name varchar(255) = quotename(@table_schema) + '.' + quotename(@table_name)

if @table_object_id is null throw 51000, 'Table does not exist', 1

select
columns.column_id,
column_name = columns.name,
column_type = type_name(columns.system_type_id),
columns.is_nullable,
columns.max_length,
columns.precision,
columns.scale,
columns.is_identity,
columns.is_computed,
add_statement = 'alter table ' + @table_full_name + ' add ' + quotename(columns.name) + ' ' + 
case
    when computed_columns.definition is not null then ' as ' + computed_columns.definition + iif(computed_columns.is_persisted = 1, ' persisted', '')
    else
    case
        when type_name(columns.system_type_id) like '%char%' or type_name(columns.system_type_id) like '%binary%' then type_name(columns.system_type_id) + '(' + case when columns.max_length = -1 then 'max' else cast(columns.max_length  / iif(type_name(columns.system_type_id) like 'n%', 2, 1) as varchar(255)) end + ')'
        when type_name(columns.system_type_id) in ('numeric', 'decimal') then type_name(columns.system_type_id) + '(' + cast(columns.precision as varchar(255)) + ',' + cast(columns.scale as varchar(255)) + ')'
        else type_name(columns.system_type_id)
    end + iif(columns.is_nullable = 0, ' not null', ' null') + iif(columns.is_identity = 1, ' identity(1, 1)', '')
end,
alter_statement = 'alter table ' + @table_full_name + ' alter column ' + quotename(columns.name) + ' ' + 
case
    when computed_columns.definition is not null then null
    else
    case
        when type_name(columns.system_type_id) like '%char%' then type_name(columns.system_type_id) + '(' + case when columns.max_length = -1 then 'max' else cast(columns.max_length as varchar(255)) end + ')'
        when type_name(columns.system_type_id) in ('numeric', 'decimal') then type_name(columns.system_type_id) + '(' + cast(columns.precision as varchar(255)) + ',' + cast(columns.scale as varchar(255)) + ')'
        else type_name(columns.system_type_id)
    end + iif(columns.is_nullable = 0, ' not null', ' null') + iif(columns.is_identity = 1, ' identity(1, 1)', '')
end,
drop_statement = 'alter table ' + @table_full_name + ' drop column ' + quotename(columns.name),
rename_statement = 'exec sp_rename ' + quotename(@table_full_name + '.' + quotename(columns.name), '''') + ', ''new_column_name'''
from sys.tables
inner join sys.columns on columns.object_id = tables.object_id
left join sys.computed_columns on computed_columns.object_id = columns.object_id
    and computed_columns.column_id = columns.column_id
where
tables.object_id = @table_object_id
order by column_name

;with dataspace as
(
select
data_space_id,
data_space_name = filegroups.name,
data_space_type = filegroups.type_desc,
partition_function = 'N/A',
partition_table_id = -1,
partition_column_id = -1
from sys.filegroups

union

select
partition_schemes.data_space_id,
data_space_name = partition_schemes.name,
data_space_type = partition_schemes.type_desc,
partition_function = partition_functions.name,
partition_table_id = columns.object_id,
partition_column_id = columns.column_id
from sys.tables
inner join sys.indexes on indexes.object_id = tables.object_id
    and indexes.type in (0, 1)
inner join sys.partition_schemes on partition_schemes.data_space_id = indexes.data_space_id
inner join sys.partition_functions on partition_functions.function_id = partition_schemes.function_id
inner join sys.index_columns on index_columns.object_id = indexes.object_id
    and index_columns.index_id = indexes.index_id
    and index_columns.partition_ordinal >= 1
inner join sys.columns on columns.object_id = index_columns.object_id
    and columns.column_id = index_columns.column_id
)
,index_columns_ext as
(
select distinct
indexes.object_id,
indexes.index_id,
index_name = indexes.name,
index_type = indexes.type_desc,
indexes.is_unique,
indexes.is_primary_key,
indexes.fill_factor,
data_space_name = dataspace.data_space_name,
create_statement_prefix =
case when indexes.is_primary_key = 1 then 'alter table ' + @table_full_name + ' add constraint ' + quotename(indexes.name) + ' primary key clustered '
else 'create ' + iif(indexes.is_unique = 1, 'unique ', '') + iif(indexes.type_desc = 'CLUSTERED', 'clustered ', '') + 'index ' + quotename(indexes.name) + ' on ' + @table_full_name end,
drop_statement = case when is_primary_key = 1 then 'alter table ' + @table_full_name + ' drop constraint ' + quotename(indexes.name) else 'drop index ' + @table_full_name + '.' + quotename(indexes.name) end,
rename_statement = 'exec sp_rename ' + quotename(quotename(schema_name(tables.schema_id)) + '.' + quotename(tables.name) + '.' + quotename(indexes.name), '''') + ',''' + case when indexes.is_primary_key = 1 then 'PK' when indexes.is_unique = 1 and indexes.type_desc = 'CLUSTERED' then 'CX' when indexes.is_unique = 1 then 'UX' else 'IX' end + '_' + tables.name + '_' + 
substring((select replace(c.name, ' ', '_') + '_' from sys.index_columns ic inner join sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id where ic.object_id = tables.object_id and index_columns.index_id = indexes.index_id and ic.index_id = indexes.index_id and tables.object_id = tables.object_id order by index_columns.key_ordinal asc for xml path('')),
    1,
    len((select replace(c.name, ' ', '_') + '_' from sys.index_columns ic inner join sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id where ic.object_id = tables.object_id and index_columns.index_id = indexes.index_id and ic.index_id = indexes.index_id and tables.object_id = tables.object_id order by index_columns.key_ordinal asc for xml path(''))) - 1)
+ '''',
column_names = substring((select quotename(c.name) + iif(index_columns.is_descending_key = 0, ' asc', ' desc') + ',' from sys.index_columns ic inner join sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id where ic.object_id = tables.object_id and index_columns.index_id = indexes.index_id and ic.index_id = indexes.index_id and tables.object_id = @table_object_id order by index_columns.key_ordinal asc for xml path('')),
    1,
    len((select quotename(c.name) + iif(index_columns.is_descending_key = 0, ' asc', ' desc') + ',' from sys.index_columns ic inner join sys.columns c on c.object_id = ic.object_id and c.column_id = ic.column_id where ic.object_id = tables.object_id and index_columns.index_id = indexes.index_id and ic.index_id = indexes.index_id and tables.object_id = @table_object_id order by index_columns.key_ordinal asc for xml path(''))) - 1),
data_space_append = case when dataspace.partition_function != 'N/A' then ' on ' + dataspace.data_space_name + '(' + columns.name + ')' else '' end
from sys.tables
inner join sys.columns on columns.object_id = tables.object_id
inner join sys.index_columns on index_columns.object_id = tables.object_id and index_columns.column_id = columns.column_id
inner join sys.indexes on indexes.object_id = index_columns.object_id and indexes.index_id = index_columns.index_id
inner join dataspace on dataspace.data_space_id = indexes.data_space_id and (dataspace.partition_column_id = -1 or (dataspace.partition_column_id = columns.column_id and dataspace.partition_table_id = @table_object_id))
where
tables.object_id = @table_object_id
)
select
index_name = indexes.name,
index_type = indexes.type_desc,
indexes.is_unique,
indexes.is_primary_key,
indexes.fill_factor,
column_names,
data_space_name,
create_statement = create_statement_prefix + '(' + column_names + ')' + isnull(' where ' + indexes.filter_definition, '') + data_space_append,
drop_statement,
rename_statement
from sys.indexes
left join index_columns_ext on index_columns_ext.object_id = indexes.object_id and index_columns_ext.index_id = indexes.index_id
where
indexes.object_id = @table_object_id


select
foreign_key_name = foreign_keys.name,
parent_table_schema = object_schema_name(parent_column.object_id),
parent_table_name = object_name(parent_column.object_id),
parent_column_name = parent_column.name,
referenced_table_schema = object_schema_name(referenced_column.object_id),
referenced_table_name = object_name(referenced_column.object_id),
referenced_column_name = referenced_column.name,
foreign_keys.is_disabled,
create_statement = 'alter table ' + quotename(object_schema_name(parent_column.object_id)) + '.' + quotename(object_name(parent_column.object_id)) + ' add constraint ' + foreign_keys.name + ' foreign key (' + parent_column.name + ') references ' + quotename(object_schema_name(referenced_column.object_id)) + '.' + object_name(foreign_keys.referenced_object_id) + ' (' + quotename(referenced_column.name) + ')', 
drop_statement = 'alter table ' + quotename(object_schema_name(parent_column.object_id)) + '.' + quotename(object_name(parent_column.object_id)) + ' drop constraint ' + quotename(foreign_keys.name),
rename_statement = 'exec sp_rename ' + quotename(quotename(object_schema_name(parent_column.object_id)) + '.' + quotename(foreign_keys.name), '''') + ', ''FK_' + object_name(parent_column.object_id) + '_' + object_name(referenced_column.object_id) + '''',
reenable_statement = 'alter table ' + quotename(object_schema_name(parent_column.object_id)) + '.' + quotename(object_name(parent_column.object_id)) + ' with check check constraint ' + quotename(foreign_keys.name),
disable_statement = 'alter table ' + quotename(object_schema_name(parent_column.object_id)) + '.' + quotename(object_name(parent_column.object_id)) + ' nocheck constraint ' + quotename(foreign_keys.name),
is_obeying_constraint_statement = 'select ' + parent_column.name + ' from ' + QUOTENAME(object_schema_name(parent_column.object_id)) + '.' + QUOTENAME(object_name(parent_column.object_id)) + ' except ' + 'select ' + referenced_column.name + ' from ' + QUOTENAME(object_schema_name(referenced_column.object_id)) + '.' + QUOTENAME(object_name(referenced_column.object_id))
from sys.foreign_keys
inner join sys.foreign_key_columns parent_column_key on parent_column_key.parent_object_id = foreign_keys.parent_object_id and parent_column_key.constraint_object_id = foreign_keys.object_id
inner join sys.foreign_key_columns referenced_column_key on referenced_column_key.referenced_object_id = foreign_keys.referenced_object_id and referenced_column_key.constraint_object_id = foreign_keys.object_id
inner join sys.columns parent_column on parent_column.object_id = parent_column_key.parent_object_id and parent_column.column_id = parent_column_key.parent_column_id
inner join sys.columns referenced_column on referenced_column.object_id = referenced_column_key.referenced_object_id and referenced_column.column_id = referenced_column_key.referenced_column_id
where
(parent_column.object_id = @table_object_id or referenced_column.object_id = @table_object_id)


;with constraints as
(
    select
    default_constraints.name,
    parent_object_id,
    parent_column_id,
    type_desc,
    definition,
    rename_statement = 'exec sp_rename ' + quotename(quotename(object_schema_name(default_constraints.object_id)) + '.' + quotename(default_constraints.name), '''') + ', ''DF_' + @table_name + '_' + columns.name + ''''
    from sys.default_constraints
    left join sys.columns on columns.object_id = default_constraints.parent_object_id and columns.column_id = default_constraints.parent_column_id

    union all
    
    select
    name,
    parent_object_id,
    parent_column_id,
    type_desc,
    definition,
    rename_statement = 'exec sp_rename ' + quotename(@table_full_name + '.' + quotename(check_constraints.name), '''') + ', ''CK_' + @table_name + '_' + 'namehere'''
    from sys.check_constraints
)
select
constraint_name = constraints.name,
constraint_type = constraints.type_desc,
constraint_definition = constraints.definition,
column_name = columns.name,
create_statement = 'alter table ' + @table_full_name + ' add constraint ' + quotename(constraints.name) +
    case (constraints.type_desc)
    when 'DEFAULT_CONSTRAINT' then ' default' + constraints.definition + ' for ' + quotename(columns.name)
    when 'CHECK_CONSTRAINT' then ' check' + constraints.definition
    else null end,
drop_statement = 'alter table ' + @table_full_name + ' drop constraint ' + quotename(constraints.name),
rename_statement,
reenable_statement = case when constraints.type_desc = 'DEFAULT_CONSTRAINT' then null else 'alter table ' + quotename(object_schema_name(constraints.parent_object_id)) + '.' + quotename(object_name(constraints.parent_object_id)) + ' with check check constraint ' + quotename(constraints.name) end
from constraints
inner join sys.columns on columns.object_id = constraints.parent_object_id and columns.column_id = constraints.parent_column_id
where
columns.object_id = @table_object_id


select
trigger_name = triggers.name,
definition = OBJECT_DEFINITION(triggers.object_id),
triggers.is_disabled,
triggers.is_not_for_replication,
triggers.is_instead_of_trigger,
enable_statement = 'enable trigger ' + object_schema_name(triggers.object_id) + '.' + triggers.name + ' on ' + OBJECT_SCHEMA_NAME(@table_object_id) + '.' + tables.name,
disable_statement = 'disable trigger ' + object_schema_name(triggers.object_id) + '.' + triggers.name + ' on ' + OBJECT_SCHEMA_NAME(@table_object_id) + '.' + tables.name,
drop_statement = 'drop trigger ' + object_schema_name(triggers.object_id) + '.' + triggers.name
from sys.triggers
inner join sys.tables on tables.object_id = triggers.parent_id
where
tables.object_id = @table_object_id


;with filegroup_union_partition as
(
select 
filegroups.data_space_id,
data_space_name = filegroups.name,
data_space_type = data_spaces.type_desc,
partition_function_name = 'N/A',
partition_column_name = 'N/A'
from sys.filegroups
inner join sys.data_spaces on data_spaces.data_space_id = filegroups.data_space_id

union all

select
partition_schemes.data_space_id,
data_space_name = partition_schemes.name,
data_space_type = data_spaces.type_desc,
partition_function_name = partition_functions.name,
partition_column_name = columns.name
from sys.tables
inner join sys.indexes on indexes.object_id = tables.object_id
    and indexes.type in (0, 1)
inner join sys.partition_schemes on partition_schemes.data_space_id = indexes.data_space_id
inner join sys.partition_functions on partition_functions.function_id = partition_schemes.function_id
inner join sys.index_columns on index_columns.object_id = indexes.object_id
    and index_columns.index_id = indexes.index_id
    and index_columns.partition_ordinal >= 1
inner join sys.columns on columns.object_id = index_columns.object_id and columns.column_id = index_columns.column_id
inner join sys.data_spaces on data_spaces.data_space_id = partition_schemes.data_space_id
)
select 
primary_key_name = indexes.name,
table_type =
    case indexes.index_id
    when 0 then 'heap'
    when 1 then 'clustered (b-tree)'
    end,
filegroup_union_partition.data_space_name,
filegroup_union_partition.data_space_type,
filegroup_union_partition.partition_column_name,
filegroup_union_partition.partition_function_name,*
from sys.indexes
inner join filegroup_union_partition on filegroup_union_partition.data_space_id = indexes.data_space_id
where
indexes.object_id = @table_object_id
and indexes.index_id in (0, 1)
