select 
dotnet_ef = ' --table ' + 'dbo.' + table_name,
scaffolddb = '[' + table_schema + '].[' + table_name + '],'
from 
information_schema.tables
where 
table_type = 'base table'
order by 
table_name;
